defmodule Raggio.Schema.Validator do
  @moduledoc """
  Core validation logic for Raggio.Schema.
  """

  alias Raggio.Schema

  def validate(schema = %Schema{}, data), do: validate(schema, data, [])

  def validate(schema = %Schema{}, data, opts) do
    mode = Keyword.get(opts, :mode, :fail_fast)
    partial = Keyword.get(opts, :partial, false)

    data = apply_default(schema, data)

    errors = []
    errors = validate_nullable(schema, data, [], errors)

    if errors != [] do
      {:error, Enum.reverse(errors)}
    else
      errors = validate_type(schema, data, [], errors)
      errors = validate_constraints(schema, data, [], errors, mode)

      case {errors, partial} do
        {[], _} -> {:ok, data}
        {_, false} -> {:error, Enum.reverse(errors)}
        {_, true} -> {:ok, {data, Enum.reverse(errors)}}
      end
    end
  end

  defp apply_default(%Schema{default: nil}, data), do: data
  defp apply_default(%Schema{default: default}, nil), do: default
  defp apply_default(_schema, data), do: data

  defp validate_nullable(%Schema{optional: true}, nil, _path, errors), do: errors
  defp validate_nullable(%Schema{nullable: true}, nil, _path, errors), do: errors

  defp validate_nullable(%Schema{optional: false, nullable: false}, nil, path, errors) do
    add_error(errors, path, "is required", nil, :required)
  end

  defp validate_nullable(_schema, _data, _path, errors), do: errors

  defp validate_type(%Schema{optional: true}, nil, _path, errors), do: errors
  defp validate_type(%Schema{nullable: true}, nil, _path, errors), do: errors

  defp validate_type(%Schema{type: :string}, data, _path, errors) when is_binary(data),
    do: errors

  defp validate_type(%Schema{type: :string}, data, path, errors) do
    add_error(errors, path, "must be string type", data, :type)
  end

  defp validate_type(%Schema{type: :integer}, data, _path, errors) when is_integer(data),
    do: errors

  defp validate_type(%Schema{type: :integer}, data, path, errors) do
    add_error(errors, path, "must be integer type", data, :type)
  end

  defp validate_type(%Schema{type: :float}, data, _path, errors) when is_float(data), do: errors

  defp validate_type(%Schema{type: :float}, data, path, errors) do
    add_error(errors, path, "must be float type", data, :type)
  end

  defp validate_type(%Schema{type: :boolean}, data, _path, errors) when is_boolean(data),
    do: errors

  defp validate_type(%Schema{type: :boolean}, data, path, errors) do
    add_error(errors, path, "must be boolean type", data, :type)
  end

  defp validate_type(%Schema{type: :atom}, data, _path, errors) when is_atom(data), do: errors

  defp validate_type(%Schema{type: :atom}, data, path, errors) do
    add_error(errors, path, "must be atom type", data, :type)
  end

  defp validate_type(%Schema{type: :date}, data, path, errors) do
    if match?(%Date{}, data) do
      errors
    else
      add_error(errors, path, "must be Date type", data, :type)
    end
  end

  defp validate_type(%Schema{type: :datetime}, data, path, errors) do
    if match?(%DateTime{}, data) or match?(%NaiveDateTime{}, data) do
      errors
    else
      add_error(errors, path, "must be DateTime type", data, :type)
    end
  end

  defp validate_type(%Schema{type: :decimal}, data, path, errors) do
    if is_number(data) or match?(%Decimal{}, data) do
      errors
    else
      add_error(errors, path, "must be Decimal type", data, :type)
    end
  end

  defp validate_type(%Schema{type: :map}, data, _path, errors) when is_map(data), do: errors

  defp validate_type(%Schema{type: :map}, data, path, errors) do
    add_error(errors, path, "must be map type", data, :type)
  end

  defp validate_type(%Schema{type: :list, inner_type: inner_schema}, data, path, errors)
       when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {item, index}, acc ->
      case validate(inner_schema, item) do
        {:ok, _} ->
          acc

        {:error, item_errors} ->
          Enum.reduce(item_errors, acc, fn err, acc2 ->
            add_error(acc2, path ++ [index] ++ err.path, err.message, err.value, err.constraint)
          end)
      end
    end)
  end

  defp validate_type(%Schema{type: :list}, data, path, errors) do
    add_error(errors, path, "must be list type", data, :type)
  end

  defp validate_type(%Schema{type: :struct, fields: fields}, data, path, errors)
       when is_map(data) do
    Enum.reduce(fields, errors, fn {field_name, field_schema}, acc ->
      field_data = Map.get(data, field_name)

      validate(field_schema, field_data)
      |> case do
        {:ok, _} ->
          acc

        {:error, field_errors} ->
          Enum.reduce(field_errors, acc, fn err, acc2 ->
            new_path =
              if err.path == [], do: path ++ [field_name], else: path ++ [field_name] ++ err.path

            add_error(acc2, new_path, err.message, err.value, err.constraint)
          end)
      end
    end)
  end

  defp validate_type(%Schema{type: :struct}, data, path, errors) do
    add_error(errors, path, "must be map type", data, :type)
  end

  defp validate_type(%Schema{type: :literal, values: values}, data, path, errors) do
    if data in values do
      errors
    else
      add_error(errors, path, "must be one of #{inspect(values)}", data, :literal)
    end
  end

  defp validate_type(%Schema{type: :union, types: schemas}, data, path, errors) do
    valid? =
      Enum.any?(schemas, fn schema ->
        case validate(schema, data) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)

    if valid? do
      errors
    else
      add_error(errors, path, "must match one of the union types", data, :union)
    end
  end

  defp validate_type(%Schema{type: :tuple, types: schemas}, data, path, errors)
       when is_tuple(data) do
    data_list = Tuple.to_list(data)

    if length(data_list) != length(schemas) do
      add_error(errors, path, "tuple must have #{length(schemas)} elements", data, :type)
    else
      data_list
      |> Enum.with_index()
      |> Enum.zip(schemas)
      |> Enum.reduce(errors, fn {{item, index}, schema}, acc ->
        case validate(schema, item) do
          {:ok, _} ->
            acc

          {:error, item_errors} ->
            Enum.reduce(item_errors, acc, fn err, acc2 ->
              add_error(acc2, path ++ [index] ++ err.path, err.message, err.value, err.constraint)
            end)
        end
      end)
    end
  end

  defp validate_type(%Schema{type: :tuple}, data, path, errors) do
    add_error(errors, path, "must be tuple type", data, :type)
  end

  defp validate_type(%Schema{type: :record, fields: fields}, data, path, errors)
       when is_map(data) do
    key_schema = Keyword.get(fields, :key)
    value_schema = Keyword.get(fields, :value)

    Enum.reduce(data, errors, fn {k, v}, acc ->
      acc =
        case validate(key_schema, k) do
          {:ok, _} ->
            acc

          {:error, key_errors} ->
            Enum.reduce(key_errors, acc, fn err, acc2 ->
              add_error(acc2, path ++ [:key], err.message, k, err.constraint)
            end)
        end

      case validate(value_schema, v) do
        {:ok, _} ->
          acc

        {:error, val_errors} ->
          Enum.reduce(val_errors, acc, fn err, acc2 ->
            add_error(acc2, path ++ [k] ++ err.path, err.message, err.value, err.constraint)
          end)
      end
    end)
  end

  defp validate_type(%Schema{type: :record}, data, path, errors) do
    add_error(errors, path, "must be map type", data, :type)
  end

  defp validate_type(_schema, _data, _path, errors), do: errors

  defp validate_constraints(%Schema{constraints: []}, _data, _path, errors, _mode), do: errors
  defp validate_constraints(%Schema{optional: true}, nil, _path, errors, _mode), do: errors
  defp validate_constraints(%Schema{nullable: true}, nil, _path, errors, _mode), do: errors

  defp validate_constraints(
         %Schema{constraints: constraints, type: type},
         data,
         path,
         errors,
         mode
       ) do
    Enum.reduce_while(constraints, errors, fn constraint, acc ->
      result = validate_constraint(constraint, data, path, acc, type)

      if mode == :fail_fast and result != acc do
        {:halt, result}
      else
        {:cont, result}
      end
    end)
  end

  defp validate_constraint({:min, n}, data, path, errors, :string) when is_binary(data) do
    if String.length(data) >= n do
      errors
    else
      add_error(errors, path, "minimum length is #{n}", data, :min)
    end
  end

  defp validate_constraint({:min, n}, data, path, errors, :list) when is_list(data) do
    if length(data) >= n do
      errors
    else
      add_error(errors, path, "minimum length is #{n}", data, :min)
    end
  end

  defp validate_constraint({:min, min_val}, data, path, errors, type)
       when type in [:integer, :float, :decimal] and is_number(data) do
    if data >= min_val do
      errors
    else
      add_error(errors, path, "must be at least #{min_val}", data, :min)
    end
  end

  defp validate_constraint({:max, n}, data, path, errors, :string) when is_binary(data) do
    if String.length(data) <= n do
      errors
    else
      add_error(errors, path, "maximum length is #{n}", data, :max)
    end
  end

  defp validate_constraint({:max, n}, data, path, errors, :list) when is_list(data) do
    if length(data) <= n do
      errors
    else
      add_error(errors, path, "maximum length is #{n}", data, :max)
    end
  end

  defp validate_constraint({:max, max_val}, data, path, errors, type)
       when type in [:integer, :float, :decimal] and is_number(data) do
    if data <= max_val do
      errors
    else
      add_error(errors, path, "must be at most #{max_val}", data, :max)
    end
  end

  defp validate_constraint({:pattern, regex}, data, path, errors, :string) when is_binary(data) do
    if Regex.match?(regex, data) do
      errors
    else
      add_error(errors, path, "must match pattern #{inspect(regex)}", data, :pattern)
    end
  end

  defp validate_constraint({:unique, true}, data, path, errors, :list) when is_list(data) do
    if length(data) == length(Enum.uniq(data)) do
      errors
    else
      add_error(errors, path, "must have unique items", data, :unique)
    end
  end

  defp validate_constraint(_constraint, _data, _path, errors, _type), do: errors

  defp add_error(errors, path, message, value, constraint) do
    [
      %{
        path: path,
        message: message,
        value: value,
        constraint: constraint
      }
      | errors
    ]
  end
end
