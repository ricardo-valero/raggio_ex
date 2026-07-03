defmodule Raggio.Schema.Encoder do
  @moduledoc """
  The encode direction of the codec — a second Issue-producing interpreter over
  `Raggio.Schema.AST`, mirroring the Validator (D14: effect treats encode exactly like
  decode; the throwing form is sugar).

  Walk a decoded (typed) value back to its wire representation, reversing every
  transform in the tree. Failures are values, not crashes:

    * transform/declaration encode getters may return `{:error, msg}` → an `Encoding`
      issue (effect's `transformOrFail`); bare return values stay trusted
    * wrong-shaped input at struct/list/tuple/union/scalar nodes → `InvalidType`
      instead of a raise or silent pass-through
    * a union value matching no member → the union issue (previously passed through)

  Symmetry rule: decode runs checks → getter; encode runs getter → checks (a node's
  checks describe its encoded side, so they re-validate the getter's output).
  """

  alias Raggio.Schema.{AST, Context, Issue, Transformation}

  @spec encode(AST.t(), any(), keyword()) ::
          {:ok, any()} | {:error, [Raggio.Schema.Error.t()] | Issue.t()}
  def encode(schema, value, opts \\ [])

  def encode(%AST{} = schema, value, opts) do
    mode = Keyword.get(opts, :mode, :fail_fast)

    case do_encode(schema, value, mode) do
      {:ok, encoded} ->
        {:ok, encoded}

      {:error, issue} ->
        case Keyword.get(opts, :errors, :flat) do
          :tree -> {:error, issue}
          :flat -> {:error, Issue.to_errors(issue)}
        end
    end
  end

  @doc "Like `encode/3` but raises `Raggio.Schema.ValidationError` on failure (effect's `encodeSync`)."
  def encode!(%AST{} = schema, value) do
    case encode(schema, value) do
      {:ok, encoded} -> encoded
      {:error, errors} -> raise Raggio.Schema.ValidationError, errors: errors
    end
  end

  # nil is its own wire form for nullable/defaulted slots
  defp do_encode(%AST{context: %Context{nullable?: true}}, nil, _mode), do: {:ok, nil}
  defp do_encode(%AST{context: %Context{default: d}}, nil, _mode) when d != :none, do: {:ok, nil}

  defp do_encode(%AST{} = schema, value, mode) do
    # getter → checks: node checks re-validate the encoded output (see moduledoc)
    with {:ok, encoded} <- encode_node(schema, value, mode) do
      run_checks(schema.checks, encoded)
    end
  end

  # --- transforms (incl. decode_to with a typed-side target) -----------------

  defp encode_node(
         %AST{
           kind: :transform,
           inner: inner,
           value_type: target,
           encoding: [%Transformation{encode: enc}]
         },
         value,
         mode
       ) do
    with {:ok, typed} <- encode_target(target, value, mode),
         {:ok, mid} <- run_getter(enc, typed),
         {:ok, encoded} <- do_encode(inner, mid, mode) do
      {:ok, encoded}
    end
  end

  # --- declarations -----------------------------------------------------------

  defp encode_node(%AST{kind: :declaration, module: module}, value, _mode) do
    run_getter(&module.encode/1, value)
  end

  # --- composites --------------------------------------------------------------

  defp encode_node(%AST{kind: :struct, fields: fields}, value, mode) when is_map(value) do
    {encoded, issues} =
      Enum.reduce_while(fields, {%{}, []}, fn {name, field_schema}, {acc, issues} ->
        case fetch_field(value, name) do
          {:ok, nil} ->
            {:cont, {acc, issues}}

          {:ok, field_value} ->
            case do_encode(field_schema, field_value, mode) do
              {:ok, v} ->
                {:cont, {Map.put(acc, name, v), issues}}

              {:error, issue} ->
                issue = Issue.pointer(name, issue)

                if mode == :fail_fast,
                  do: {:halt, {acc, [issue]}},
                  else: {:cont, {acc, [issue | issues]}}
            end

          :error ->
            {:cont, {acc, issues}}
        end
      end)

    case issues do
      [] -> {:ok, encoded}
      _ -> {:error, Issue.composite(Enum.reverse(issues))}
    end
  end

  defp encode_node(%AST{kind: :struct}, value, _mode), do: invalid_type("map", value)

  defp encode_node(%AST{kind: :list, inner: inner}, value, mode) when is_list(value) do
    {encoded, issues} =
      value
      |> Enum.with_index()
      |> Enum.reduce_while({[], []}, fn {elem, idx}, {acc, issues} ->
        case do_encode(inner, elem, mode) do
          {:ok, v} ->
            {:cont, {[v | acc], issues}}

          {:error, issue} ->
            issue = Issue.pointer(idx, issue)

            if mode == :fail_fast,
              do: {:halt, {acc, [issue]}},
              else: {:cont, {acc, [issue | issues]}}
        end
      end)

    case issues do
      [] -> {:ok, Enum.reverse(encoded)}
      _ -> {:error, Issue.composite(Enum.reverse(issues))}
    end
  end

  defp encode_node(%AST{kind: :list}, value, _mode), do: invalid_type("list", value)

  defp encode_node(%AST{kind: :tuple, elements: schemas}, value, mode)
       when is_tuple(value) and tuple_size(value) == length(schemas) do
    schemas
    |> Enum.zip(Tuple.to_list(value))
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {{schema, elem}, idx}, {:ok, acc} ->
      case do_encode(schema, elem, mode) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        {:error, issue} -> {:halt, {:error, Issue.pointer(idx, issue)}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, acc |> Enum.reverse() |> List.to_tuple()}
      {:error, _} = err -> err
    end
  end

  defp encode_node(%AST{kind: :tuple}, value, _mode), do: invalid_type("tuple", value)

  defp encode_node(%AST{kind: :record, key_type: kt, value_type: vt}, value, mode)
       when is_map(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, ek} <- pointered(:key, do_encode(kt, k, mode)),
           {:ok, ev} <- pointered(k, do_encode(vt, v, mode)) do
        {:cont, {:ok, Map.put(acc, ek, ev)}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp encode_node(%AST{kind: :record}, value, _mode), do: invalid_type("map", value)

  # union of bound-struct members — fast path by the value's struct module
  defp encode_node(%AST{kind: :union, elements: members}, %mod{} = value, mode) do
    case Enum.find(members, &match?(%AST{kind: :struct, module: ^mod}, &1)) do
      nil -> try_members(members, value, mode)
      member -> do_encode(member, Map.from_struct(value), mode)
    end
  end

  defp encode_node(%AST{kind: :union, elements: members}, value, mode) do
    try_members(members, value, mode)
  end

  defp encode_node(%AST{kind: :literal, values: values}, value, _mode) do
    if value in values do
      {:ok, value}
    else
      {:error, Issue.invalid_value("must be one of: #{inspect(values)}", value, :literal)}
    end
  end

  # --- scalars: type-check instead of silent pass-through ----------------------

  defp encode_node(%AST{kind: :string}, v, _) when is_binary(v), do: {:ok, v}
  defp encode_node(%AST{kind: :string}, v, _), do: invalid_type("string", v)
  defp encode_node(%AST{kind: :integer}, v, _) when is_integer(v), do: {:ok, v}
  defp encode_node(%AST{kind: :integer}, v, _), do: invalid_type("integer", v)
  defp encode_node(%AST{kind: :float}, v, _) when is_float(v), do: {:ok, v}
  defp encode_node(%AST{kind: :float}, v, _), do: invalid_type("float", v)
  defp encode_node(%AST{kind: :number}, v, _) when is_number(v), do: {:ok, v}
  defp encode_node(%AST{kind: :number}, v, _), do: invalid_type("number", v)
  defp encode_node(%AST{kind: :boolean}, v, _) when is_boolean(v), do: {:ok, v}
  defp encode_node(%AST{kind: :boolean}, v, _), do: invalid_type("boolean", v)
  defp encode_node(%AST{kind: :atom}, v, _) when is_atom(v), do: {:ok, v}
  defp encode_node(%AST{kind: :atom}, v, _), do: invalid_type("atom", v)
  defp encode_node(%AST{kind: :date}, %Date{} = v, _), do: {:ok, v}
  defp encode_node(%AST{kind: :date}, v, _), do: invalid_type("date", v)
  defp encode_node(%AST{kind: :datetime}, %DateTime{} = v, _), do: {:ok, v}
  defp encode_node(%AST{kind: :datetime}, %NaiveDateTime{} = v, _), do: {:ok, v}
  defp encode_node(%AST{kind: :datetime}, v, _), do: invalid_type("datetime", v)
  defp encode_node(%AST{kind: :decimal}, %Decimal{} = v, _), do: {:ok, v}
  defp encode_node(%AST{kind: :decimal}, v, _), do: invalid_type("decimal", v)
  defp encode_node(%AST{kind: :any}, v, _), do: {:ok, v}

  # --- helpers ------------------------------------------------------------------

  defp encode_target(nil, value, _mode), do: {:ok, value}
  defp encode_target(%AST{} = target, value, mode), do: do_encode(target, value, mode)

  # Getter protocol: bare value (trusted, effect's `transform`) or
  # {:ok, v} / {:error, msg} (fallible, effect's `transformOrFail`).
  defp run_getter(enc, value) do
    case enc.(value) do
      {:ok, out} -> {:ok, out}
      {:error, msg} when is_binary(msg) -> {:error, Issue.encoding(msg, value)}
      out -> {:ok, out}
    end
  end

  defp try_members([], value, _mode) do
    {:error, Issue.any_of([], value)}
  end

  defp try_members(members, value, mode) do
    members
    |> Enum.reduce_while({:error, []}, fn member, {:error, issues} ->
      case do_encode(member, value, mode) do
        {:ok, encoded} -> {:halt, {:ok, encoded}}
        {:error, issue} -> {:cont, {:error, [issue | issues]}}
      end
    end)
    |> case do
      {:ok, _} = ok -> ok
      {:error, issues} -> {:error, Issue.any_of(Enum.reverse(issues), value)}
    end
  end

  defp run_checks(checks, value) do
    issues =
      Enum.flat_map(checks, fn check ->
        case check.run.(value) do
          :ok -> []
          {:error, message} -> [Issue.invalid_value(message, value, check.constraint)]
        end
      end)

    if issues == [], do: {:ok, value}, else: {:error, Issue.composite(issues)}
  end

  defp pointered(_key, {:ok, v}), do: {:ok, v}
  defp pointered(key, {:error, issue}), do: {:error, Issue.pointer(key, issue)}

  defp invalid_type(expected, value), do: {:error, Issue.invalid_type(expected, value)}

  defp fetch_field(map, name) do
    cond do
      Map.has_key?(map, name) -> {:ok, Map.get(map, name)}
      Map.has_key?(map, to_string(name)) -> {:ok, Map.get(map, to_string(name))}
      true -> :error
    end
  end
end
