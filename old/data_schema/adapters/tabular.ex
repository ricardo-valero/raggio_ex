defmodule Manuable.DataSchema.Adapters.Tabular do
  @moduledoc """
  Adapter for parsing tabular data (Excel, CSV) with row tracking and error reporting.

  This adapter wraps the core DataSchema parser to provide:
  - Row number tracking in errors
  - Separation of valid and invalid rows
  - Header validation and column extraction
  - Batch processing of multiple rows

  ## Two-Phase Parsing

  The recommended approach is to separate header validation from data parsing:

      # 1. Define header schema (validates and extracts column positions)
      header_schema = Tabular.header([
        {2, "guia"},
        {13, "Diferencia"}
      ])

      # 2. Validate header row
      {:ok, columns} = Tabular.parse_header(header_row, header_schema)

      # 3. Define row schema (just types and transforms)
      row_schema = tuple(
        tracking: string() |> transform(:excel_string, decode: &excel_string/1, encode: &identity/1),
        amount: decimal() |> transform(:excel_decimal, decode: &excel_decimal_abs/1, encode: &to_string/1)
      )

      # 4. Extract columns and parse
      data_rows
      |> Tabular.extract_columns(columns)
      |> Tabular.parse_rows(row_schema)

  ## Options

  - `:skip_header` - Skip the first row (default: false)
  - `:start_row` - Row number offset for error reporting (default: 1)

  ## Return Value

  Returns a tuple `{valid_rows, invalid_rows}` where:
  - `valid_rows` is a list of `{row_number, parsed_data}` tuples
  - `invalid_rows` is a list of `%ParseError{}` structs with `:row` populated
  """

  alias Manuable.DataSchema.Builders.TypeDef
  alias Manuable.DataSchema.ParseError
  alias Manuable.DataSchema.Parser

  @type row :: map() | list()
  @type valid_row :: {pos_integer(), map()}
  @type column_spec :: {non_neg_integer(), String.t()}
  @type header_schema :: [column_spec()]
  @type opts :: [
          skip_header: boolean(),
          start_row: pos_integer()
        ]

  # ===========================================================================
  # Header Schema & Parsing
  # ===========================================================================

  @doc """
  Creates a header schema from column position and expected name pairs.

  ## Examples

      header_schema = Tabular.header([
        {2, "guia"},
        {13, "Diferencia"}
      ])
  """
  @spec header([column_spec()]) :: header_schema()
  def header(columns) when is_list(columns) do
    columns
  end

  @doc """
  Validates a header row against a header schema.

  Returns `{:ok, positions}` if all expected columns are found at the specified positions,
  where `positions` is the list of column positions to extract.

  Returns `{:error, errors}` if validation fails.

  ## Examples

      header_row = ["comercio", "Id_Identity", "guia", "mensajeria", ...]

      {:ok, [2, 13]} = Tabular.parse_header(header_row, [
        {2, "guia"},
        {13, "Diferencia"}
      ])
  """
  @spec parse_header(list(), header_schema()) ::
          {:ok, [non_neg_integer()]} | {:error, [ParseError.t()]}
  def parse_header(header_row, header_schema) when is_list(header_row) do
    errors =
      header_schema
      |> Enum.reduce([], fn {position, expected_name}, acc ->
        actual = Enum.at(header_row, position)

        if actual == expected_name do
          acc
        else
          error =
            ParseError.new(
              path: [position],
              code: :header_mismatch,
              message:
                "expected column '#{expected_name}' at position #{position}, got '#{actual}'",
              value: actual
            )

          [error | acc]
        end
      end)
      |> Enum.reverse()

    if errors == [] do
      positions = Enum.map(header_schema, fn {pos, _name} -> pos end)
      {:ok, positions}
    else
      {:error, errors}
    end
  end

  @doc """
  Tries to match a header row against multiple header schemas.

  Returns `{:ok, {variant_index, positions}}` for the first matching schema.
  Returns `{:error, :no_match}` if no schema matches.

  ## Examples

      variants = [
        [{2, "guia"}, {13, "Diferencia"}],
        [{2, "Guia"}, {15, "Por cobrar"}]
      ]

      {:ok, {0, [2, 13]}} = Tabular.detect_header(header_row, variants)
  """
  @spec detect_header(list(), [header_schema()]) ::
          {:ok, {non_neg_integer(), [non_neg_integer()]}} | {:error, :no_match}
  def detect_header(header_row, header_schemas) when is_list(header_schemas) do
    header_schemas
    |> Enum.with_index()
    |> Enum.find_value({:error, :no_match}, fn {schema, index} ->
      case parse_header(header_row, schema) do
        {:ok, positions} -> {:ok, {index, positions}}
        {:error, _} -> nil
      end
    end)
  end

  # ===========================================================================
  # Column Extraction
  # ===========================================================================

  @doc """
  Extracts values at specified positions from each row.

  Takes a list of rows (as lists) and column positions, returns rows with only
  the specified columns in order.

  ## Examples

      rows = [
        ["a", "b", "c", "d"],
        ["e", "f", "g", "h"]
      ]

      Tabular.extract_columns(rows, [0, 2])
      # => [["a", "c"], ["e", "g"]]
  """
  @spec extract_columns([list()], [non_neg_integer()]) :: [list()]
  def extract_columns(rows, positions) when is_list(positions) do
    Enum.map(rows, fn row ->
      Enum.map(positions, fn pos -> Enum.at(row, pos) end)
    end)
  end

  # ===========================================================================
  # Row Parsing
  # ===========================================================================

  @doc """
  Parses a list of rows against a schema.

  Rows can be either:
  - Lists (positional) - parsed against positional tuple schema
  - Maps - parsed against named tuple schema

  ## Parameters

  - `rows` - List of rows (lists or maps)
  - `schema` - A `%TypeDef{}` schema (from `tuple()`, etc.)
  - `opts` - Options:
    - `:skip_header` - Skip the first row (default: false)
    - `:start_row` - Row number offset for error reporting (default: 1)
    - `:header_mapping` - Map of source column names to schema field atoms (for map rows)

  ## Returns

  `{valid_rows, invalid_rows}` where:
  - `valid_rows` - List of `{row_number, parsed_data}` tuples
  - `invalid_rows` - List of `%ParseError{}` structs with `:row` field

  ## Examples

      # List-based rows (after extract_columns)
      rows = [["value1", "value2"], ["value3", "value4"]]
      schema = tuple(field1: string(), field2: string())
      {valid, invalid} = Tabular.parse_rows(rows, schema)

      # Map-based rows
      rows = [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}]
      schema = tuple(name: string(), age: integer())
      {valid, invalid} = Tabular.parse_rows(rows, schema)

      # Map-based rows with header mapping
      rows = [%{"Nombre" => "Alice", "Edad" => 30}]
      {valid, invalid} = Tabular.parse_rows(rows, schema, header_mapping: %{"Nombre" => :name, "Edad" => :age})
  """
  @spec parse_rows([row()], TypeDef.t(), keyword()) :: {[valid_row()], [ParseError.t()]}
  def parse_rows(rows, %TypeDef{} = schema, opts \\ []) do
    skip_header = Keyword.get(opts, :skip_header, false)
    start_row = Keyword.get(opts, :start_row, 1)
    header_mapping = Keyword.get(opts, :header_mapping, %{})

    # Skip header row if requested
    rows_to_process = if skip_header, do: Enum.drop(rows, 1), else: rows

    # Calculate row offset
    row_offset = if skip_header, do: start_row, else: start_row - 1

    rows_to_process
    |> Enum.with_index(row_offset + 1)
    |> Enum.reduce({[], []}, fn {row, row_num}, {valid_acc, invalid_acc} ->
      # Apply header mapping for map rows, then convert list rows to map
      input =
        row
        |> apply_header_mapping(header_mapping)
        |> prepare_row_for_schema(schema)

      case Parser.parse(input, schema) do
        {:ok, parsed} ->
          {[{row_num, parsed} | valid_acc], invalid_acc}

        {:error, errors} ->
          errors_with_row = Enum.map(errors, &%{&1 | row: row_num})
          {valid_acc, errors_with_row ++ invalid_acc}
      end
    end)
    |> then(fn {valid, invalid} ->
      {Enum.reverse(valid), Enum.reverse(invalid)}
    end)
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  # Apply header mapping to map rows
  defp apply_header_mapping(row, mapping) when is_map(row) and map_size(mapping) > 0 do
    Map.new(row, fn {key, value} ->
      case Map.get(mapping, key) do
        nil -> {key, value}
        mapped_key -> {mapped_key, value}
      end
    end)
  end

  defp apply_header_mapping(row, _mapping), do: row

  # Convert list row to map keyed by field names from schema
  defp prepare_row_for_schema(row, %TypeDef{kind: :tuple, fields: fields})
       when is_list(row) and is_list(fields) do
    field_names = Enum.map(fields, fn {name, _type} -> name end)

    field_names
    |> Enum.zip(row)
    |> Map.new()
  end

  # Pass through maps and other types unchanged
  defp prepare_row_for_schema(row, _schema), do: row
end
