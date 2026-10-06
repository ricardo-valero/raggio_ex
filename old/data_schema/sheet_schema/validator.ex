defmodule Manuable.DataSchema.SheetSchema.Validator do
  @moduledoc """
  Validates sheet schema definitions at build time.

  ## Validation Rules

  1. **Position or Header Required**: Each column must declare at least one of
     `:at` (column index) or `:header` (header text).

  2. **No Position Collisions**: No two columns can have the same `:at` value
     within a single sheet schema.

  3. **Header Disambiguation**: If multiple columns have the same `:header`,
     they must be disambiguated by different `:at` values.

  4. **Valid Ranges**: Row ranges must be valid Elixir `Range` structs.

  ## Error Types

  - `{:missing_position_or_header, [atom()]}` - Columns without :at or :header
  - `{:at_collision, [{position, [atom()]}]}` - Multiple columns at same position
  - `{:ambiguous_headers, [{header, [atom()]}]}` - Same header without position disambiguation
  - `{:invalid_range, term()}` - Invalid range specification
  """

  alias Manuable.DataSchema.SheetSchema.{ColumnDef, SheetDef}

  @type error ::
          {:missing_position_or_header, [atom()]}
          | {:at_collision, [{non_neg_integer(), [atom()]}]}
          | {:ambiguous_headers, [{String.t(), [atom()]}]}
          | {:invalid_range, term()}

  @doc """
  Validates a sheet schema definition.

  Returns `:ok` if valid, or `{:error, [error()]}` with all validation errors.

  ## Examples

      iex> Validator.validate(valid_schema)
      :ok

      iex> Validator.validate(invalid_schema)
      {:error, [{:missing_position_or_header, [:bad_column]}]}
  """
  @spec validate(SheetDef.t()) :: :ok | {:error, [error()]}
  def validate(%SheetDef{columns: columns, range: range}) do
    errors =
      []
      |> validate_position_or_header(columns)
      |> validate_no_at_collisions(columns)
      |> validate_header_disambiguation(columns)
      |> validate_range(range)

    case errors do
      [] -> :ok
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Validates and raises on error.
  """
  @spec validate!(SheetDef.t()) :: :ok
  def validate!(%SheetDef{} = schema) do
    case validate(schema) do
      :ok -> :ok
      {:error, errors} -> raise ArgumentError, format_errors(errors)
    end
  end

  @doc """
  Formats validation errors as a human-readable string.
  """
  @spec format_errors([error()]) :: String.t()
  def format_errors(errors) do
    Enum.map_join(errors, "\n", &format_error/1)
  end

  # Rule 1: Each column must have :at or :header (or both)
  defp validate_position_or_header(errors, columns) do
    invalid =
      columns
      |> Enum.filter(fn {_name, col} ->
        not ColumnDef.valid?(col)
      end)
      |> Enum.map(&elem(&1, 0))

    case invalid do
      [] -> errors
      names -> [{:missing_position_or_header, names} | errors]
    end
  end

  # Rule 2: No two columns can have the same :at value
  defp validate_no_at_collisions(errors, columns) do
    duplicates =
      columns
      |> Enum.map(fn {name, col} -> {name, col.at} end)
      |> Enum.reject(fn {_, at} -> is_nil(at) end)
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
      |> Enum.filter(fn {_, names} -> length(names) > 1 end)

    case duplicates do
      [] -> errors
      dups -> [{:at_collision, dups} | errors]
    end
  end

  # Rule 3: Same header allowed only if disambiguated by different :at
  defp validate_header_disambiguation(errors, columns) do
    ambiguous =
      columns
      |> Enum.map(fn {name, col} -> {name, col.header, col.at} end)
      |> Enum.reject(fn {_, h, _} -> is_nil(h) end)
      |> Enum.group_by(&elem(&1, 1))
      |> Enum.filter(fn {_header, cols} ->
        # Ambiguous if: multiple columns with same header AND any lacks :at
        length(cols) > 1 and Enum.any?(cols, fn {_, _, at} -> is_nil(at) end)
      end)
      |> Enum.map(fn {header, cols} ->
        {header, Enum.map(cols, &elem(&1, 0))}
      end)

    case ambiguous do
      [] -> errors
      amb -> [{:ambiguous_headers, amb} | errors]
    end
  end

  # Rule 4: Ranges must be valid
  defp validate_range(errors, nil), do: errors

  defp validate_range(errors, ranges) when is_list(ranges) do
    invalid = Enum.reject(ranges, &valid_range?/1)

    case invalid do
      [] -> errors
      _ -> [{:invalid_range, invalid} | errors]
    end
  end

  defp validate_range(errors, range), do: [{:invalid_range, range} | errors]

  defp valid_range?(%Range{}), do: true
  defp valid_range?(_), do: false

  # Error formatting
  defp format_error({:missing_position_or_header, names}) do
    "Columns #{inspect(names)} must specify :at or :header (or both)"
  end

  defp format_error({:at_collision, collisions}) do
    details =
      Enum.map_join(collisions, ", ", fn {pos, names} ->
        "position #{pos}: #{inspect(names)}"
      end)

    "Multiple columns at same position: #{details}"
  end

  defp format_error({:ambiguous_headers, ambiguous}) do
    details =
      Enum.map_join(ambiguous, ", ", fn {header, names} ->
        "header #{inspect(header)}: #{inspect(names)}"
      end)

    "Ambiguous headers (need :at to disambiguate): #{details}"
  end

  defp format_error({:invalid_range, ranges}) do
    "Invalid range specification: #{inspect(ranges)}"
  end
end
