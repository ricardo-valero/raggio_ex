defmodule Raggio.Schema.Validator do
  @moduledoc """
  Core validation logic for Raggio.Schema.
  """

  alias Raggio.Schema

  @doc """
  Validate data against schema.
  """
  def validate(schema = %Schema{}, data) do
    # Apply default values before validation
    data = apply_default(schema, data)

    errors = []
    errors = validate_type(schema, data, [], errors)
    errors = validate_constraints(schema, data, [], errors)

    case errors do
      [] -> {:ok, data}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp apply_default(%Schema{default: nil}, data), do: data
  defp apply_default(%Schema{default: default}, nil), do: default
  defp apply_default(_schema, data), do: data

  defp validate_type(%Schema{optional: true}, nil, _path, errors), do: errors

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
    if is_number(data) do
      errors
    else
      add_error(errors, path, "must be Decimal type", data, :type)
    end
  end

  defp validate_type(%Schema{type: :array, fields: fields}, data, path, errors)
       when is_list(data) do
    element_schema = Keyword.get(fields, :element)

    data
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {item, index}, acc ->
      case validate(element_schema, item) do
        {:ok, _} ->
          acc

        {:error, item_errors} ->
          Enum.reduce(item_errors, acc, fn err, acc2 ->
            add_error(acc2, path ++ [index] ++ err.path, err.message, err.value, err.constraint)
          end)
      end
    end)
  end

  defp validate_type(%Schema{type: :array}, data, path, errors) do
    add_error(errors, path, "must be array type", data, :type)
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
            add_error(acc2, path ++ [field_name], err.message, err.value, err.constraint)
          end)
      end
    end)
  end

  defp validate_type(%Schema{type: :struct}, data, path, errors) do
    add_error(errors, path, "must be map type", data, :type)
  end

  defp validate_type(%Schema{type: :enum, constraints: constraints}, data, path, errors) do
    values = Keyword.get(constraints, :values, [])

    if data in values do
      errors
    else
      add_error(errors, path, "must be one of #{inspect(values)}", data, :enum)
    end
  end

  defp validate_type(%Schema{type: :union, fields: fields}, data, path, errors) do
    schemas = Keyword.get(fields, :schemas, [])

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

  defp validate_type(_schema, _data, _path, errors), do: errors

  defp validate_constraints(%Schema{constraints: []}, _data, _path, errors), do: errors

  defp validate_constraints(%Schema{constraints: constraints}, data, path, errors) do
    Enum.reduce(constraints, errors, fn constraint, acc ->
      validate_constraint(constraint, data, path, acc)
    end)
  end

  defp validate_constraint({:min_length, n}, data, path, errors) when is_binary(data) do
    if String.length(data) >= n do
      errors
    else
      add_error(errors, path, "minimum length is #{n}", data, :min_length)
    end
  end

  defp validate_constraint({:min_length, n}, data, path, errors) when is_list(data) do
    if length(data) >= n do
      errors
    else
      add_error(errors, path, "minimum length is #{n}", data, :min_length)
    end
  end

  defp validate_constraint({:max_length, n}, data, path, errors) when is_binary(data) do
    if String.length(data) <= n do
      errors
    else
      add_error(errors, path, "maximum length is #{n}", data, :max_length)
    end
  end

  defp validate_constraint({:max_length, n}, data, path, errors) when is_list(data) do
    if length(data) <= n do
      errors
    else
      add_error(errors, path, "maximum length is #{n}", data, :max_length)
    end
  end

  defp validate_constraint({:pattern, regex}, data, path, errors) when is_binary(data) do
    if Regex.match?(regex, data) do
      errors
    else
      add_error(errors, path, "must match pattern #{inspect(regex)}", data, :pattern)
    end
  end

  defp validate_constraint({:email, regex}, data, path, errors) when is_binary(data) do
    if Regex.match?(regex, data) do
      errors
    else
      add_error(errors, path, "must be valid email format", data, :email)
    end
  end

  defp validate_constraint({:min, min_val}, data, path, errors) when is_number(data) do
    if data >= min_val do
      errors
    else
      add_error(errors, path, "must be at least #{min_val}", data, :min)
    end
  end

  defp validate_constraint({:max, max_val}, data, path, errors) when is_number(data) do
    if data <= max_val do
      errors
    else
      add_error(errors, path, "must be at most #{max_val}", data, :max)
    end
  end

  defp validate_constraint({:positive, true}, data, path, errors) when is_number(data) do
    if data > 0 do
      errors
    else
      add_error(errors, path, "must be positive number", data, :positive)
    end
  end

  defp validate_constraint({:range, {min_val, max_val}}, data, path, errors)
       when is_number(data) do
    if data >= min_val and data <= max_val do
      errors
    else
      add_error(errors, path, "must be between #{min_val} and #{max_val}", data, :range)
    end
  end

  defp validate_constraint({:values, _values}, _data, _path, errors), do: errors
  defp validate_constraint(_constraint, _data, _path, errors), do: errors

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
