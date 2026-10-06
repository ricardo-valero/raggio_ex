defmodule Manuable.DataSchema.SheetSchema.Parser do
  @moduledoc """
  Parses tabular data using SheetSchema definitions.

  This module handles the full parsing pipeline:
  1. Header detection (if enabled)
  2. Column position resolution
  3. Row range filtering
  4. Type parsing and validation

  ## Usage

      {:ok, {valid, invalid}} = Parser.parse(rows, schema)

  ## Return Value

  On success, returns `{:ok, {valid_rows, invalid_rows}}` where:
  - `valid_rows` - List of `{row_number, parsed_map}` tuples
  - `invalid_rows` - List of `%ParseError{}` structs

  On failure (e.g., no header match), returns `{:error, reason}`.
  """

  alias Manuable.DataSchema.Adapters.Tabular
  alias Manuable.DataSchema.Builders
  alias Manuable.DataSchema.ParseError
  alias Manuable.DataSchema.SheetSchema.{ColumnDef, SheetDef, Union}

  @type valid_row :: {pos_integer(), map()}
  @type parse_result :: {:ok, {[valid_row()], [ParseError.t()]}}
  @type parse_error ::
          {:error, :no_match}
          | {:error, :empty_input}
          | {:error, {:ambiguous_match, [atom()]}}
          | {:error, {:header_mismatch, non_neg_integer(), String.t(), any()}}
          | {:error, {:header_not_found, String.t()}}

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Parses rows using a sheet schema or union.

  ## Examples

      # Single schema
      {:ok, {valid, invalid}} = Parser.parse(rows, sheet_schema)

      # Union of schemas
      {:ok, {valid, invalid}} = Parser.parse(rows, union_schema)
  """
  @spec parse([list()], SheetDef.t() | Union.t()) :: parse_result() | parse_error()
  def parse(rows, %Union{} = union) do
    parse_union(rows, union)
  end

  def parse(rows, %SheetDef{} = schema) do
    parse_sheet(rows, schema)
  end

  @doc """
  Parses rows and raises on error.
  """
  @spec parse!([list()], SheetDef.t() | Union.t()) :: {[valid_row()], [ParseError.t()]}
  def parse!(rows, schema) do
    case parse(rows, schema) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, "Parse failed: #{inspect(reason)}"
    end
  end

  # =============================================================================
  # Union Parsing
  # =============================================================================

  defp parse_union(rows, %Union{schemas: schemas, strategy: strategy}) do
    results =
      Enum.map(schemas, fn schema ->
        {schema, parse_sheet(rows, schema)}
      end)

    case strategy do
      :first_match -> first_match(results)
      :exact_one -> exact_one_match(results)
    end
  end

  defp first_match(results) do
    case Enum.find(results, fn {_, result} -> match?({:ok, _}, result) end) do
      {_schema, {:ok, _} = result} -> result
      nil -> {:error, :no_match}
    end
  end

  defp exact_one_match(results) do
    successes = Enum.filter(results, fn {_, result} -> match?({:ok, _}, result) end)

    case successes do
      [{_schema, {:ok, _} = result}] ->
        result

      [] ->
        {:error, :no_match}

      multiple ->
        names = Enum.map(multiple, fn {schema, _} -> schema.name end)
        {:error, {:ambiguous_match, names}}
    end
  end

  # =============================================================================
  # Sheet Parsing
  # =============================================================================

  defp parse_sheet([], _schema), do: {:error, :empty_input}

  defp parse_sheet(rows, %SheetDef{header_mode: :enabled} = schema) do
    parse_with_header(rows, schema)
  end

  defp parse_sheet(rows, %SheetDef{header_mode: :disabled} = schema) do
    parse_without_header(rows, schema)
  end

  # Header-enabled parsing
  defp parse_with_header([header_row | data_rows], schema) do
    with {:ok, column_mapping} <- detect_and_resolve_columns(header_row, schema),
         {:ok, filtered_rows} <- apply_range(data_rows, schema.range) do
      result = parse_rows(filtered_rows, column_mapping, start_row: 2)
      {:ok, result}
    end
  end

  # Header-disabled parsing (position-only)
  defp parse_without_header(rows, schema) do
    column_mapping = build_position_mapping(schema)

    with {:ok, filtered_rows} <- apply_range(rows, schema.range) do
      result = parse_rows(filtered_rows, column_mapping, start_row: 1)
      {:ok, result}
    end
  end

  # =============================================================================
  # Column Resolution
  # =============================================================================

  defp detect_and_resolve_columns(header_row, schema) do
    schema.columns
    |> Enum.reduce_while({:ok, %{}}, fn {name, col}, {:ok, acc} ->
      case resolve_column_index(col, header_row) do
        {:ok, idx} ->
          {:cont, {:ok, Map.put(acc, name, {idx, col.type})}}

        {:error, _} when col.optional ->
          # Skip optional columns that don't match
          {:cont, {:ok, acc}}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  defp resolve_column_index(%ColumnDef{at: at, header: nil}, _row) when not is_nil(at) do
    {:ok, at}
  end

  defp resolve_column_index(%ColumnDef{at: at, header: header}, row) when not is_nil(at) do
    actual = Enum.at(row, at)

    if actual == header do
      {:ok, at}
    else
      {:error, {:header_mismatch, at, header, actual}}
    end
  end

  defp resolve_column_index(%ColumnDef{at: nil, header: header}, row) do
    case Enum.find_index(row, &(&1 == header)) do
      nil -> {:error, {:header_not_found, header}}
      idx -> {:ok, idx}
    end
  end

  defp build_position_mapping(schema) do
    Map.new(schema.columns, fn {name, col} ->
      {name, {col.at, col.type}}
    end)
  end

  # =============================================================================
  # Range Filtering
  # =============================================================================

  defp apply_range(rows, nil), do: {:ok, rows}

  defp apply_range(rows, ranges) when is_list(ranges) do
    indexed = Enum.with_index(rows, 1)

    filtered =
      indexed
      |> Enum.filter(fn {_row, idx} -> in_ranges?(idx, ranges) end)
      |> Enum.map(&elem(&1, 0))

    {:ok, filtered}
  end

  defp in_ranges?(idx, ranges) do
    Enum.any?(ranges, fn range -> idx in range end)
  end

  # =============================================================================
  # Row Parsing
  # =============================================================================

  defp parse_rows(rows, column_mapping, opts) do
    start_row = Keyword.get(opts, :start_row, 1)

    # Get field names in consistent order
    field_names = column_mapping |> Map.keys() |> Enum.sort()

    # Build positions list in same order as field_names
    positions =
      Enum.map(field_names, fn name ->
        {idx, _type} = column_mapping[name]
        idx
      end)

    # Build TypeDef for the row parser (fields in same order)
    type_fields =
      Enum.map(field_names, fn name ->
        {_idx, type} = column_mapping[name]
        {name, type}
      end)

    row_type = Builders.tuple(type_fields)

    # Extract columns and parse using Tabular adapter
    rows
    |> Enum.map(fn row ->
      Enum.map(positions, &Enum.at(row, &1))
    end)
    |> Tabular.parse_rows(row_type, start_row: start_row)
  end
end
