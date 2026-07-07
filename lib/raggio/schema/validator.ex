defmodule Raggio.Schema.Validator do
  @moduledoc """
  Core validation engine for `Raggio.Schema` — the interpreter over `Raggio.Schema.AST`.

  Decoding is a walk of the uniform AST: match the node's `kind`, run its `checks`,
  then recurse for composites. Optionality/nullability/defaults are read from each
  node's `context`.

  Errors are built natively as a `Raggio.Schema.Issue` **tree** (effect's `SchemaIssue`):
  leaves for failures, `Pointer`s for location, `Composite` for siblings, `AnyOf` for
  union branches. The public flat list (`[%Raggio.Schema.Error{}]`) is a fold of that
  tree; pass `errors: :tree` to get the tree itself.
  """

  alias Raggio.Schema.{AST, Context, Issue, Transformation}

  def validate(schema, data), do: validate(schema, data, [])

  def validate(schema, data, opts) do
    mode = Keyword.get(opts, :mode, :fail_fast)
    partial = Keyword.get(opts, :partial, false)

    case do_validate(schema, data, mode, partial) do
      {:ok, value} ->
        {:ok, value}

      {:error, issue} ->
        case Keyword.get(opts, :errors, :flat) do
          :tree -> {:error, issue}
          :flat -> {:error, Issue.to_errors(issue)}
        end
    end
  end

  defp do_validate(%AST{context: %Context{nullable?: true}}, nil, _mode, _partial),
    do: {:ok, nil}

  # a 0-arity function default is a lazy thunk, evaluated per decode
  # (effect's withDecodingDefault)
  defp do_validate(%AST{context: %Context{default: default}}, nil, _mode, _partial)
       when default != :none do
    if is_function(default, 0), do: {:ok, default.()}, else: {:ok, default}
  end

  defp do_validate(%AST{kind: kind} = schema, value, mode, partial) do
    # Type match, then refinement checks on the container/scalar (effect's Filter order —
    # e.g. list `min_items` sees the full list), then recurse into elements/fields.
    with {:ok, value} <- validate_type(kind, value),
         {:ok, value} <- run_checks(schema.checks, value),
         {:ok, value} <- validate_node(schema, value, mode, partial) do
      {:ok, value}
    end
  end

  defp validate_type(:string, value) when is_binary(value), do: {:ok, value}
  defp validate_type(:string, value), do: type_error(value, "string")

  defp validate_type(:integer, value) when is_integer(value), do: {:ok, value}
  defp validate_type(:integer, value), do: type_error(value, "integer")

  defp validate_type(:float, value) when is_float(value), do: {:ok, value}
  defp validate_type(:float, value) when is_integer(value), do: {:ok, value / 1}
  defp validate_type(:float, value), do: type_error(value, "float")

  # :number preserves integers and floats as given (effect's Number)
  defp validate_type(:number, value) when is_number(value), do: {:ok, value}
  defp validate_type(:number, value), do: type_error(value, "number")

  defp validate_type(:any, value), do: {:ok, value}

  defp validate_type(:boolean, value) when is_boolean(value), do: {:ok, value}
  defp validate_type(:boolean, value), do: type_error(value, "boolean")

  defp validate_type(:atom, value) when is_atom(value), do: {:ok, value}
  defp validate_type(:atom, value), do: type_error(value, "atom")

  defp validate_type(:date, %Date{} = value), do: {:ok, value}
  defp validate_type(:date, value), do: type_error(value, "date")

  defp validate_type(:datetime, %DateTime{} = value), do: {:ok, value}
  defp validate_type(:datetime, %NaiveDateTime{} = value), do: {:ok, value}
  defp validate_type(:datetime, value), do: type_error(value, "datetime")

  # :decimal casts like Ecto's :decimal — Decimal as-is; a fully-numeric string,
  # an integer, or a float (shortest representation) become Decimals
  defp validate_type(:decimal, %Decimal{} = value), do: {:ok, value}

  defp validate_type(:decimal, value) when is_binary(value) do
    case Decimal.parse(value) do
      {%Decimal{} = decimal, ""} -> {:ok, decimal}
      _ -> type_error(value, "decimal")
    end
  end

  defp validate_type(:decimal, value) when is_integer(value), do: {:ok, Decimal.new(value)}
  defp validate_type(:decimal, value) when is_float(value), do: {:ok, Decimal.from_float(value)}
  defp validate_type(:decimal, value), do: type_error(value, "decimal")

  defp validate_type(:struct, value) when is_map(value), do: {:ok, value}
  defp validate_type(:struct, value), do: type_error(value, "map")

  defp validate_type(:list, value) when is_list(value), do: {:ok, value}
  defp validate_type(:list, value), do: type_error(value, "list")

  defp validate_type(:tuple, value) when is_tuple(value), do: {:ok, value}
  defp validate_type(:tuple, value), do: type_error(value, "tuple")

  defp validate_type(:record, value) when is_map(value), do: {:ok, value}
  defp validate_type(:record, value), do: type_error(value, "map")

  defp validate_type(:union, value), do: {:ok, value}
  defp validate_type(:literal, value), do: {:ok, value}
  # a transform accepts whatever its encoded-side schema accepts
  defp validate_type(:transform, value), do: {:ok, value}
  # a declaration delegates all type checking to its module's decode/1
  defp validate_type(:declaration, value), do: {:ok, value}

  # --- per-kind node validation -------------------------------------------

  defp validate_node(%AST{kind: :struct, fields: fields, module: module}, value, mode, partial) do
    validate_struct_fields(fields, value, mode, partial, %{}, [], module)
  end

  defp validate_node(%AST{kind: :list, inner: inner}, value, mode, _partial) do
    validate_list_elements(inner, value, mode)
  end

  defp validate_node(%AST{kind: :tuple, elements: schemas}, value, mode, _partial) do
    validate_tuple_elements(schemas, Tuple.to_list(value), mode, 0, [])
  end

  # tagged union — read the discriminator, dispatch to the single matching member
  defp validate_node(
         %AST{kind: :union, discriminator: disc, elements: members},
         value,
         mode,
         partial
       )
       when not is_nil(disc) do
    if is_map(value) do
      tag = fetch_wire(value, disc)

      case Enum.find(members, &tagged_member_matches?(&1, disc, tag)) do
        nil ->
          tags = Enum.flat_map(members, &tagged_member_values(&1, disc))

          {:error,
           Issue.pointer(
             disc,
             Issue.invalid_value("must be one of: #{inspect(tags)}", tag, :discriminator)
           )}

        member ->
          do_validate(member, value, mode, partial)
      end
    else
      type_error(value, "map")
    end
  end

  # untagged union — try each member; on total failure keep EVERY branch's issue
  defp validate_node(%AST{kind: :union, elements: schemas}, value, _mode, _partial) do
    validate_union(schemas, value, [])
  end

  # declaration — the module's decode/1 does the checking
  defp validate_node(%AST{kind: :declaration, module: module}, value, _mode, _partial) do
    case module.decode(value) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, message} -> {:error, Issue.invalid_value(message, value, :declaration)}
    end
  end

  # A literal matches its exact values; an atom member also matches its string wire
  # form and decodes to the canonical atom (JSON has no atoms).
  defp validate_node(%AST{kind: :literal, values: values}, value, _mode, _partial) do
    case literal_match(values, value) do
      {:ok, canonical} ->
        {:ok, canonical}

      :error ->
        {:error, Issue.invalid_value("must be one of: #{inspect(values)}", value, :literal)}
    end
  end

  defp validate_node(
         %AST{kind: :record, key_type: key_schema, value_type: value_schema},
         value,
         mode,
         _partial
       ) do
    validate_record_entries(Map.to_list(value), key_schema, value_schema, mode, %{})
  end

  # transform — decode the encoded side, apply the transformation's decode getter,
  # then (decode_to) validate the result against the target schema if one is set
  defp validate_node(
         %AST{
           kind: :transform,
           inner: inner,
           value_type: target,
           encoding: [%Transformation{decode: decode}]
         },
         value,
         mode,
         partial
       ) do
    with {:ok, encoded} <- do_validate(inner, value, mode, partial),
         {:ok, typed} <- run_decode(decode, encoded) do
      if target, do: do_validate(target, typed, mode, partial), else: {:ok, typed}
    end
  end

  # primitives — structural validation only; refinement checks run in do_validate/4
  defp validate_node(%AST{}, value, _mode, _partial) do
    {:ok, value}
  end

  defp run_decode(decode, encoded) do
    case decode.(encoded) do
      {:ok, typed} -> {:ok, typed}
      {:error, message} -> {:error, Issue.encoding(message, encoded)}
    end
  end

  # --- checks --------------------------------------------------------------

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

  # --- structs -------------------------------------------------------------

  # Decoding rebuilds the value from the declared fields (effect's Type projection):
  # decoded/transformed values and applied defaults land in the output, undeclared keys
  # are dropped, absent optional fields stay absent. A bound `module` yields its struct.
  defp validate_struct_fields([], _value, _mode, partial, acc, issues, module) do
    case issues do
      [] -> acc |> finalize_struct(module, partial) |> run_module_validate(module, partial)
      _ -> {:error, Issue.composite(Enum.reverse(issues))}
    end
  end

  defp validate_struct_fields(
         [{field_name, field_schema} | rest],
         value,
         mode,
         partial,
         acc,
         issues,
         module
       ) do
    field_value = fetch_wire(value, field_name)
    %Context{} = ctx = field_schema.context

    cond do
      is_nil(field_value) and ctx.optional? ->
        validate_struct_fields(rest, value, mode, partial, acc, issues, module)

      is_nil(field_value) and partial ->
        validate_struct_fields(rest, value, mode, partial, acc, issues, module)

      is_nil(field_value) and not ctx.nullable? and ctx.default == :none ->
        issue = Issue.pointer(field_name, Issue.missing_key())

        if mode == :fail_fast do
          {:error, issue}
        else
          validate_struct_fields(rest, value, mode, partial, acc, [issue | issues], module)
        end

      true ->
        case do_validate(field_schema, field_value, mode, partial) do
          {:ok, validated} ->
            acc = Map.put(acc, field_name, validated)
            validate_struct_fields(rest, value, mode, partial, acc, issues, module)

          {:error, field_issue} when mode == :fail_fast ->
            {:error, Issue.pointer(field_name, field_issue)}

          {:error, field_issue} ->
            issue = Issue.pointer(field_name, field_issue)
            validate_struct_fields(rest, value, mode, partial, acc, [issue | issues], module)
        end
    end
  end

  defp finalize_struct(acc, nil, _partial), do: acc

  # struct!/2 so a schema field the target struct lacks raises loudly instead of
  # silently dropping decoded data (Kernel.struct/2 ignores unknown keys).
  defp finalize_struct(acc, module, false), do: Kernel.struct!(module, acc)

  # Partial decode may legitimately omit fields the target struct lists in
  # @enforce_keys (schema modules enforce their required fields), so build
  # without enforcement — Map.replace!/3 keeps the loud raise on unknown keys.
  defp finalize_struct(acc, module, true) do
    Enum.reduce(acc, Kernel.struct(module), fn {key, value}, struct ->
      Map.replace!(struct, key, value)
    end)
  end

  # Interpreter-native cross-field refinement (effect's Class filter/transformOrFail):
  # a bound module's optional `validate/1` runs on ITS decoded value as soon as its own
  # fields are clean — so a sibling's failure elsewhere never hides this struct's
  # cross-field error. It may transform ({:ok, updated}) and may target a field
  # ({:error, field, msg}). Skipped in partial mode (the struct may be incomplete).
  defp run_module_validate(value, nil, _partial), do: {:ok, value}
  defp run_module_validate(value, _module, true), do: {:ok, value}

  defp run_module_validate(value, module, _partial) do
    if Code.ensure_loaded?(module) and function_exported?(module, :validate, 1) do
      case module.validate(value) do
        :ok ->
          {:ok, value}

        {:ok, %{__struct__: ^module} = updated} ->
          {:ok, updated}

        {:error, message} when is_binary(message) ->
          {:error, Issue.invalid_value(message, value, :validate)}

        {:error, field, message} when is_atom(field) and is_binary(message) ->
          {:error, Issue.pointer(field, Issue.invalid_value(message, nil, :validate))}
      end
    else
      {:ok, value}
    end
  end

  # Wire input may be atom- or string-keyed (JSON); atom keys win on conflict.
  defp fetch_wire(map, key) do
    case Map.fetch(map, key) do
      {:ok, v} -> v
      :error -> Map.get(map, to_string(key))
    end
  end

  # --- lists ---------------------------------------------------------------

  defp validate_list_elements(inner_schema, value, mode) do
    validate_list_elements_loop(inner_schema, value, mode, 0, [], [])
  end

  defp validate_list_elements_loop(_inner, [], _mode, _idx, acc, issues) do
    case issues do
      [] -> {:ok, Enum.reverse(acc)}
      _ -> {:error, Issue.composite(Enum.reverse(issues))}
    end
  end

  defp validate_list_elements_loop(inner, [elem | rest], mode, idx, acc, issues) do
    case do_validate(inner, elem, mode, false) do
      {:ok, validated} ->
        validate_list_elements_loop(inner, rest, mode, idx + 1, [validated | acc], issues)

      {:error, issue} when mode == :fail_fast ->
        {:error, Issue.pointer(idx, issue)}

      {:error, issue} ->
        issues = [Issue.pointer(idx, issue) | issues]
        validate_list_elements_loop(inner, rest, mode, idx + 1, acc, issues)
    end
  end

  # --- tuples --------------------------------------------------------------

  defp validate_tuple_elements([], [], _mode, _idx, acc),
    do: {:ok, List.to_tuple(Enum.reverse(acc))}

  defp validate_tuple_elements([schema | schemas], [elem | elems], mode, idx, acc) do
    case do_validate(schema, elem, mode, false) do
      {:ok, validated} ->
        validate_tuple_elements(schemas, elems, mode, idx + 1, [validated | acc])

      {:error, issue} ->
        {:error, Issue.pointer(idx, issue)}
    end
  end

  defp validate_tuple_elements(schemas, elems, _mode, _idx, _acc) do
    {:error,
     Issue.invalid_value(
       "tuple size mismatch: expected #{length(schemas)}, got #{length(elems)}",
       elems,
       :type
     )}
  end

  # --- unions ----------------------------------------------------------------

  defp validate_union([], value, branch_issues) do
    {:error, Issue.any_of(Enum.reverse(branch_issues), value)}
  end

  defp validate_union([schema | rest], value, branch_issues) do
    case do_validate(schema, value, :fail_fast, false) do
      {:ok, validated} -> {:ok, validated}
      {:error, issue} -> validate_union(rest, value, [issue | branch_issues])
    end
  end

  # --- records -------------------------------------------------------------

  defp validate_record_entries([], _key_schema, _value_schema, _mode, acc), do: {:ok, acc}

  defp validate_record_entries([{k, v} | rest], key_schema, value_schema, mode, acc) do
    with {:ok, validated_k} <- pointered(:key, do_validate(key_schema, k, mode, false)),
         {:ok, validated_v} <- pointered(k, do_validate(value_schema, v, mode, false)) do
      validate_record_entries(
        rest,
        key_schema,
        value_schema,
        mode,
        Map.put(acc, validated_k, validated_v)
      )
    end
  end

  defp pointered(_key, {:ok, v}), do: {:ok, v}
  defp pointered(key, {:error, issue}), do: {:error, Issue.pointer(key, issue)}

  # --- helpers ---------------------------------------------------------------

  defp tagged_member_matches?(%AST{kind: :struct, fields: fields}, disc, tag) do
    case List.keyfind(fields, disc, 0) do
      {^disc, %AST{kind: :literal, values: values}} -> literal_match(values, tag) != :error
      _ -> false
    end
  end

  defp tagged_member_values(%AST{kind: :struct, fields: fields}, disc) do
    case List.keyfind(fields, disc, 0) do
      {^disc, %AST{kind: :literal, values: values}} -> values
      _ -> []
    end
  end

  defp literal_match(values, value) do
    cond do
      value in values ->
        {:ok, value}

      is_binary(value) ->
        case Enum.find(values, &(is_atom(&1) and Atom.to_string(&1) == value)) do
          nil -> :error
          atom -> {:ok, atom}
        end

      true ->
        :error
    end
  end

  defp type_error(value, expected), do: {:error, Issue.invalid_type(expected, value)}
end
