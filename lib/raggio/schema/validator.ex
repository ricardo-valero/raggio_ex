defmodule Raggio.Schema.Validator do
  @moduledoc """
  Core validation engine for Raggio.Schema.
  """

  alias Raggio.Schema.{Type, Error}

  def validate(schema, data), do: validate(schema, data, [])

  def validate(schema, data, opts) do
    mode = Keyword.get(opts, :mode, :fail_fast)
    partial = Keyword.get(opts, :partial, false)

    case do_validate(schema, data, [], mode, partial) do
      {:ok, value} -> {:ok, value}
      {:error, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp do_validate(%Type{nullable: true}, nil, _path, _mode, _partial), do: {:ok, nil}

  defp do_validate(%Type{default: default}, nil, _path, _mode, _partial)
       when not is_nil(default) do
    {:ok, default}
  end

  defp do_validate(%Type{kind: kind} = schema, value, path, mode, partial) do
    with {:ok, value} <- validate_type(kind, value, path),
         {:ok, value} <- validate_constraints(schema, value, path, mode, partial) do
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

  defp validate_constraints(%Type{kind: :struct, fields: fields}, value, path, mode, partial) do
    validate_struct_fields(fields, value, path, mode, partial, [])
  end

  defp validate_constraints(
         %Type{kind: :list, inner: inner, constraints: constraints},
         value,
         path,
         mode,
         _partial
       ) do
    with {:ok, _} <- validate_list_constraints(constraints, value, path),
         {:ok, validated} <- validate_list_elements(inner, value, path, mode) do
      {:ok, validated}
    end
  end

  defp validate_constraints(%Type{kind: :tuple, elements: schemas}, value, path, mode, _partial) do
    validate_tuple_elements(schemas, Tuple.to_list(value), path, mode, 0, [])
  end

  defp validate_constraints(%Type{kind: :union, elements: schemas}, value, path, _mode, _partial) do
    validate_union(schemas, value, path)
  end

  defp validate_constraints(%Type{kind: :literal, values: values}, value, path, _mode, _partial) do
    if value in values do
      {:ok, value}
    else
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

  defp validate_constraints(
         %Type{kind: :record, key_type: key_schema, value_type: value_schema},
         value,
         path,
         mode,
         _partial
       ) do
    validate_record_entries(Map.to_list(value), key_schema, value_schema, path, mode, %{})
  end

  defp validate_constraints(%Type{constraints: constraints}, value, path, _mode, _partial) do
    validate_primitive_constraints(constraints, value, path)
  end

  defp validate_struct_fields([], value, _path, _mode, _partial, errors) do
    if errors == [], do: {:ok, value}, else: {:error, errors}
  end

  defp validate_struct_fields(
         [{field_name, field_schema} | rest],
         value,
         path,
         mode,
         partial,
         errors
       ) do
    field_value = Map.get(value, field_name)
    field_path = path ++ [field_name]

    cond do
      is_nil(field_value) and field_schema.optional ->
        validate_struct_fields(rest, value, path, mode, partial, errors)

      is_nil(field_value) and partial ->
        validate_struct_fields(rest, value, path, mode, partial, errors)

      is_nil(field_value) and not field_schema.nullable and is_nil(field_schema.default) ->
        error = %Error{
          path: field_path,
          message: "is required",
          value: nil,
          constraint: :required
        }

        if mode == :fail_fast do
          {:error, [error]}
        else
          validate_struct_fields(rest, value, path, mode, partial, [error | errors])
        end

      true ->
        case do_validate(field_schema, field_value, field_path, mode, partial) do
          {:ok, _validated} ->
            validate_struct_fields(rest, value, path, mode, partial, errors)

          {:error, field_errors} when mode == :fail_fast ->
            {:error, field_errors}

          {:error, field_errors} ->
            validate_struct_fields(rest, value, path, mode, partial, field_errors ++ errors)
        end
    end
  end

  defp validate_list_constraints(constraints, value, path) do
    errors =
      Enum.reduce(constraints, [], fn
        {:min, min}, acc when length(value) < min ->
          [
            %Error{
              path: path,
              message: "must have at least #{min} element(s)",
              value: value,
              constraint: :min
            }
            | acc
          ]

        {:max, max}, acc when length(value) > max ->
          [
            %Error{
              path: path,
              message: "must have at most #{max} element(s)",
              value: value,
              constraint: :max
            }
            | acc
          ]

        {:unique, true}, acc ->
          if length(value) == length(Enum.uniq(value)) do
            acc
          else
            [
              %Error{
                path: path,
                message: "must have unique elements",
                value: value,
                constraint: :unique
              }
              | acc
            ]
          end

        _, acc ->
          acc
      end)

    if errors == [], do: {:ok, value}, else: {:error, errors}
  end

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

  defp validate_primitive_constraints(constraints, value, path) do
    errors =
      Enum.reduce(constraints, [], fn
        {:min, min}, acc when is_binary(value) and byte_size(value) < min ->
          [
            %Error{
              path: path,
              message: "must be at least #{min} character(s)",
              value: value,
              constraint: :min
            }
            | acc
          ]

        {:min, min}, acc when is_number(value) and value < min ->
          [
            %Error{path: path, message: "must be at least #{min}", value: value, constraint: :min}
            | acc
          ]

        {:max, max}, acc when is_binary(value) and byte_size(value) > max ->
          [
            %Error{
              path: path,
              message: "must be at most #{max} character(s)",
              value: value,
              constraint: :max
            }
            | acc
          ]

        {:max, max}, acc when is_number(value) and value > max ->
          [
            %Error{path: path, message: "must be at most #{max}", value: value, constraint: :max}
            | acc
          ]

        {:pattern, pattern}, acc when is_binary(value) ->
          if Regex.match?(pattern, value) do
            acc
          else
            [
              %Error{
                path: path,
                message: "does not match pattern",
                value: value,
                constraint: :pattern
              }
              | acc
            ]
          end

        _, acc ->
          acc
      end)

    if errors == [], do: {:ok, value}, else: {:error, errors}
  end

  defp type_error(path, value, expected) do
    {:error,
     [%Error{path: path, message: "expected #{expected}", value: value, constraint: :type}]}
  end
end
