defmodule Raggio.Schema.Validator do
  @moduledoc """
  Core validation engine for `Raggio.Schema` — the interpreter over `Raggio.Schema.AST`.

  Decoding is a walk of the uniform AST: match the node's `kind`, run its `checks`, then
  recurse for composites. Optionality/nullability/defaults are read from each node's
  `context`. (The `encoding` chain — the codec — is a later step; this interpreter is the
  decode-from-unknown / validate direction.)
  """

  alias Raggio.Schema.{AST, Context, Error, Transformation}

  def validate(schema, data), do: validate(schema, data, [])

  def validate(schema, data, opts) do
    mode = Keyword.get(opts, :mode, :fail_fast)
    partial = Keyword.get(opts, :partial, false)

    case do_validate(schema, data, [], mode, partial) do
      {:ok, value} -> {:ok, value}
      {:error, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp do_validate(%AST{context: %Context{nullable?: true}}, nil, _path, _mode, _partial),
    do: {:ok, nil}

  defp do_validate(%AST{context: %Context{default: default}}, nil, _path, _mode, _partial)
       when default != :none do
    {:ok, default}
  end

  defp do_validate(%AST{kind: kind} = schema, value, path, mode, partial) do
    # Type match, then refinement checks on the container/scalar (effect's Filter order —
    # e.g. list `min_items` sees the full list), then recurse into elements/fields.
    with {:ok, value} <- validate_type(kind, value, path),
         {:ok, value} <- run_checks(schema.checks, value, path),
         {:ok, value} <- validate_node(schema, value, path, mode, partial) do
      {:ok, value}
    end
  end

  defp validate_type(:string, value, _path) when is_binary(value), do: {:ok, value}
  defp validate_type(:string, value, path), do: type_error(path, value, "string")

  defp validate_type(:integer, value, _path) when is_integer(value), do: {:ok, value}
  defp validate_type(:integer, value, path), do: type_error(path, value, "integer")

  defp validate_type(:float, value, _path) when is_float(value), do: {:ok, value}
  defp validate_type(:float, value, _path) when is_integer(value), do: {:ok, value / 1}
  defp validate_type(:float, value, path), do: type_error(path, value, "float")

  # :number preserves integers and floats as given (effect's Number)
  defp validate_type(:number, value, _path) when is_number(value), do: {:ok, value}
  defp validate_type(:number, value, path), do: type_error(path, value, "number")

  defp validate_type(:any, value, _path), do: {:ok, value}

  defp validate_type(:boolean, value, _path) when is_boolean(value), do: {:ok, value}
  defp validate_type(:boolean, value, path), do: type_error(path, value, "boolean")

  defp validate_type(:atom, value, _path) when is_atom(value), do: {:ok, value}
  defp validate_type(:atom, value, path), do: type_error(path, value, "atom")

  defp validate_type(:date, %Date{} = value, _path), do: {:ok, value}
  defp validate_type(:date, value, path), do: type_error(path, value, "date")

  defp validate_type(:datetime, %DateTime{} = value, _path), do: {:ok, value}
  defp validate_type(:datetime, %NaiveDateTime{} = value, _path), do: {:ok, value}
  defp validate_type(:datetime, value, path), do: type_error(path, value, "datetime")

  defp validate_type(:decimal, %Decimal{} = value, _path), do: {:ok, value}
  defp validate_type(:decimal, value, path), do: type_error(path, value, "decimal")

  defp validate_type(:struct, value, _path) when is_map(value), do: {:ok, value}
  defp validate_type(:struct, value, path), do: type_error(path, value, "map")

  defp validate_type(:list, value, _path) when is_list(value), do: {:ok, value}
  defp validate_type(:list, value, path), do: type_error(path, value, "list")

  defp validate_type(:tuple, value, _path) when is_tuple(value), do: {:ok, value}
  defp validate_type(:tuple, value, path), do: type_error(path, value, "tuple")

  defp validate_type(:record, value, _path) when is_map(value), do: {:ok, value}
  defp validate_type(:record, value, path), do: type_error(path, value, "map")

  defp validate_type(:union, value, _path), do: {:ok, value}
  defp validate_type(:literal, value, _path), do: {:ok, value}
  # a transform accepts whatever its encoded-side schema accepts
  defp validate_type(:transform, value, _path), do: {:ok, value}
  # a declaration delegates all type checking to its module's decode/1
  defp validate_type(:declaration, value, _path), do: {:ok, value}

  # --- per-kind node validation -------------------------------------------

  defp validate_node(
         %AST{kind: :struct, fields: fields, module: module},
         value,
         path,
         mode,
         partial
       ) do
    validate_struct_fields(fields, value, path, mode, partial, %{}, [], module)
  end

  defp validate_node(%AST{kind: :list, inner: inner}, value, path, mode, _partial) do
    validate_list_elements(inner, value, path, mode)
  end

  defp validate_node(%AST{kind: :tuple, elements: schemas}, value, path, mode, _partial) do
    validate_tuple_elements(schemas, Tuple.to_list(value), path, mode, 0, [])
  end

  # tagged union — read the discriminator, dispatch to the single matching member
  defp validate_node(
         %AST{kind: :union, discriminator: disc, elements: members},
         value,
         path,
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
           [
             %Error{
               path: path ++ [disc],
               message: "must be one of: #{inspect(tags)}",
               value: tag,
               constraint: :discriminator
             }
           ]}

        member ->
          do_validate(member, value, path, mode, partial)
      end
    else
      type_error(path, value, "map")
    end
  end

  defp validate_node(%AST{kind: :union, elements: schemas}, value, path, _mode, _partial) do
    validate_union(schemas, value, path)
  end

  # declaration — the module's decode/1 does the checking
  defp validate_node(%AST{kind: :declaration, module: module}, value, path, _mode, _partial) do
    case module.decode(value) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, message} ->
        {:error, [%Error{path: path, message: message, value: value, constraint: :declaration}]}
    end
  end

  # A literal matches its exact values; an atom member also matches its string wire
  # form and decodes to the canonical atom (JSON has no atoms).
  defp validate_node(%AST{kind: :literal, values: values}, value, path, _mode, _partial) do
    case literal_match(values, value) do
      {:ok, canonical} ->
        {:ok, canonical}

      :error ->
        {:error,
         [
           %Error{
             path: path,
             message: "must be one of: #{inspect(values)}",
             value: value,
             constraint: :literal
           }
         ]}
    end
  end

  defp validate_node(
         %AST{kind: :record, key_type: key_schema, value_type: value_schema},
         value,
         path,
         mode,
         _partial
       ) do
    validate_record_entries(Map.to_list(value), key_schema, value_schema, path, mode, %{})
  end

  # transform — decode the encoded side, then apply the transformation's decode getter
  defp validate_node(
         %AST{kind: :transform, inner: inner, encoding: [%Transformation{decode: decode}]},
         value,
         path,
         mode,
         partial
       ) do
    with {:ok, encoded} <- do_validate(inner, value, path, mode, partial),
         {:ok, typed} <- run_decode(decode, encoded, path) do
      {:ok, typed}
    end
  end

  # primitives — structural validation only; refinement checks run in do_validate/5
  defp validate_node(%AST{}, value, _path, _mode, _partial) do
    {:ok, value}
  end

  defp tagged_member_matches?(%AST{kind: :struct, fields: fields}, disc, tag) do
    case List.keyfind(fields, disc, 0) do
      {^disc, %AST{kind: :literal, values: values}} -> literal_match(values, tag) != :error
      _ -> false
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

  defp tagged_member_values(%AST{kind: :struct, fields: fields}, disc) do
    case List.keyfind(fields, disc, 0) do
      {^disc, %AST{kind: :literal, values: values}} -> values
      _ -> []
    end
  end

  defp run_decode(decode, encoded, path) do
    case decode.(encoded) do
      {:ok, typed} ->
        {:ok, typed}

      {:error, message} ->
        {:error, [%Error{path: path, message: message, value: encoded, constraint: :transform}]}
    end
  end

  # --- checks --------------------------------------------------------------

  defp run_checks(checks, value, path) do
    errors =
      Enum.reduce(checks, [], fn check, acc ->
        case check.run.(value) do
          :ok ->
            acc

          {:error, message} ->
            [
              %Error{path: path, message: message, value: value, constraint: check.constraint}
              | acc
            ]
        end
      end)

    if errors == [], do: {:ok, value}, else: {:error, errors}
  end

  # --- structs -------------------------------------------------------------

  # Decoding rebuilds the value from the declared fields (effect's Type projection):
  # decoded/transformed values and applied defaults land in the output, undeclared keys
  # are dropped, absent optional fields stay absent. A bound `module` yields its struct.
  defp validate_struct_fields([], _value, _path, _mode, _partial, acc, errors, module) do
    if errors == [], do: {:ok, finalize_struct(acc, module)}, else: {:error, errors}
  end

  defp validate_struct_fields(
         [{field_name, field_schema} | rest],
         value,
         path,
         mode,
         partial,
         acc,
         errors,
         module
       ) do
    field_value = fetch_wire(value, field_name)
    field_path = path ++ [field_name]
    %Context{} = ctx = field_schema.context

    cond do
      is_nil(field_value) and ctx.optional? ->
        validate_struct_fields(rest, value, path, mode, partial, acc, errors, module)

      is_nil(field_value) and partial ->
        validate_struct_fields(rest, value, path, mode, partial, acc, errors, module)

      is_nil(field_value) and not ctx.nullable? and ctx.default == :none ->
        error = %Error{
          path: field_path,
          message: "is required",
          value: nil,
          constraint: :required
        }

        if mode == :fail_fast do
          {:error, [error]}
        else
          validate_struct_fields(rest, value, path, mode, partial, acc, [error | errors], module)
        end

      true ->
        case do_validate(field_schema, field_value, field_path, mode, partial) do
          {:ok, validated} ->
            acc = Map.put(acc, field_name, validated)
            validate_struct_fields(rest, value, path, mode, partial, acc, errors, module)

          {:error, field_errors} when mode == :fail_fast ->
            {:error, field_errors}

          {:error, field_errors} ->
            validate_struct_fields(
              rest,
              value,
              path,
              mode,
              partial,
              acc,
              field_errors ++ errors,
              module
            )
        end
    end
  end

  defp finalize_struct(acc, nil), do: acc
  # struct!/2 so a schema field the target struct lacks raises loudly instead of
  # silently dropping decoded data (Kernel.struct/2 ignores unknown keys).
  defp finalize_struct(acc, module), do: Kernel.struct!(module, acc)

  # Wire input may be atom- or string-keyed (JSON); atom keys win on conflict.
  defp fetch_wire(map, key) do
    case Map.fetch(map, key) do
      {:ok, v} -> v
      :error -> Map.get(map, to_string(key))
    end
  end

  # --- lists ---------------------------------------------------------------

  defp validate_list_elements(inner_schema, value, path, mode) do
    validate_list_elements_loop(inner_schema, value, path, mode, 0, [])
  end

  defp validate_list_elements_loop(_inner, [], _path, _mode, _idx, acc),
    do: {:ok, Enum.reverse(acc)}

  defp validate_list_elements_loop(inner, [elem | rest], path, mode, idx, acc) do
    case do_validate(inner, elem, path ++ [idx], mode, false) do
      {:ok, validated} ->
        validate_list_elements_loop(inner, rest, path, mode, idx + 1, [validated | acc])

      {:error, errors} when mode == :fail_fast ->
        {:error, errors}

      {:error, _errors} ->
        validate_list_elements_loop(inner, rest, path, mode, idx + 1, acc)
    end
  end

  # --- tuples --------------------------------------------------------------

  defp validate_tuple_elements([], [], _path, _mode, _idx, acc),
    do: {:ok, List.to_tuple(Enum.reverse(acc))}

  defp validate_tuple_elements([schema | schemas], [elem | elems], path, mode, idx, acc) do
    case do_validate(schema, elem, path ++ [idx], mode, false) do
      {:ok, validated} ->
        validate_tuple_elements(schemas, elems, path, mode, idx + 1, [validated | acc])

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp validate_tuple_elements(schemas, elems, path, _mode, _idx, _acc) do
    {:error,
     [
       %Error{
         path: path,
         message: "tuple size mismatch: expected #{length(schemas)}, got #{length(elems)}",
         value: elems,
         constraint: :type
       }
     ]}
  end

  # --- unions --------------------------------------------------------------

  defp validate_union([], value, path) do
    {:error,
     [
       %Error{
         path: path,
         message: "does not match any union variant",
         value: value,
         constraint: :union
       }
     ]}
  end

  defp validate_union([schema | rest], value, path) do
    case do_validate(schema, value, path, :fail_fast, false) do
      {:ok, validated} -> {:ok, validated}
      {:error, _} -> validate_union(rest, value, path)
    end
  end

  # --- records -------------------------------------------------------------

  defp validate_record_entries([], _key_schema, _value_schema, _path, _mode, acc), do: {:ok, acc}

  defp validate_record_entries([{k, v} | rest], key_schema, value_schema, path, mode, acc) do
    with {:ok, validated_k} <- do_validate(key_schema, k, path ++ [:key], mode, false),
         {:ok, validated_v} <- do_validate(value_schema, v, path ++ [k], mode, false) do
      validate_record_entries(
        rest,
        key_schema,
        value_schema,
        path,
        mode,
        Map.put(acc, validated_k, validated_v)
      )
    end
  end

  defp type_error(path, value, expected) do
    {:error,
     [%Error{path: path, message: "expected #{expected}", value: value, constraint: :type}]}
  end
end
