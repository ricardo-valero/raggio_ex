defmodule Raggio.Tabular do
  @moduledoc """
  Parser-agnostic tabular file parsing with declarative schema mapping.

  Parse CSV, XLSX, and other tabular files into typed rows using a SheetSchema,
  returning valid rows and row-numbered errors separately.

  ## Parser-Agnostic Architecture

  This library does NOT bundle parsing libraries. You must:
  1. Add your preferred parsing library to your deps (e.g., `nimble_csv`, `xlsx_reader`)
  2. Implement the `Raggio.Tabular.Parser` behaviour or use example implementations
  3. Pass the parser module explicitly via the `:parser` option

  ## Example

      # Define a schema
      schema = Raggio.Tabular.SheetSchema.new([
        Raggio.Tabular.ColumnDef.new(:name, header: "Name", type: Raggio.Schema.string()),
        Raggio.Tabular.ColumnDef.new(:age, header: "Age", type: Raggio.Schema.integer())
      ])

      # Parse with explicit parser
      {:ok, result} = Raggio.Tabular.parse("users.csv", schema,
        parser: Examples.Tabular.CSVParser
      )

      # Access results
      result.valid_rows   # => [%{name: "Alice", age: 30}, ...]
      result.invalid_rows # => [%Raggio.Tabular.Error{row: 5, ...}, ...]

  ## Parser Behaviour

  See `Raggio.Tabular.Parser` for the behaviour specification.
  See `examples/tabular/` for reference implementations.
  """

  alias Raggio.Tabular.{RowParser, Result, SheetSchema, Union}

  @type source :: term()
  @type schema_or_union :: SheetSchema.t() | Union.t()
  @type parse_opts :: [
          parser: module(),
          sheet: String.t(),
          header: :auto | :present | :absent
        ]

  @doc """
  Parse a tabular source into typed rows.

  ## Required Options

  - `:parser` - Module implementing `Raggio.Tabular.Parser` behaviour

  ## Optional Options

  - `:sheet` - Sheet name for multi-sheet formats (default: first sheet)
  - `:header` - Header handling mode: `:auto`, `:present`, or `:absent`

  ## Examples

      # CSV parsing
      Raggio.Tabular.parse("data.csv", schema, parser: MyApp.CSVParser)

      # XLSX with specific sheet
      Raggio.Tabular.parse("data.xlsx", schema,
        parser: MyApp.XLSXParser,
        sheet: "Sheet2"
      )

  ## Returns

  - `{:ok, %Raggio.Tabular.Result{}}` - Parse succeeded (may have invalid rows)
  - `{:error, reason}` - Parse failed completely (file not found, format error, etc.)
  """
  @spec parse(source(), schema_or_union(), parse_opts()) :: {:ok, Result.t()} | {:error, map()}
  def parse(source, schema_or_union, opts) do
    case Keyword.fetch(opts, :parser) do
      {:ok, parser} ->
        do_parse(source, schema_or_union, parser, opts)

      :error ->
        {:error,
         %{
           type: :missing_parser,
           message:
             "The :parser option is required. Pass a module implementing Raggio.Tabular.Parser behaviour."
         }}
    end
  end

  defp do_parse(source, schema_or_union, parser, opts) do
    with {:ok, stream} <- parser.stream_rows(source, opts) do
      RowParser.parse(stream, schema_or_union, opts)
    end
  end

  @doc """
  List available sheets for a tabular source.

  ## Required Options

  - `:parser` - Module implementing `Raggio.Tabular.Parser` behaviour

  ## Examples

      {:ok, sheets} = Raggio.Tabular.list_sheets("data.xlsx", parser: MyApp.XLSXParser)
      # => {:ok, ["Sheet1", "Data", "Summary"]}

      {:ok, sheets} = Raggio.Tabular.list_sheets("data.csv", parser: MyApp.CSVParser)
      # => {:ok, ["default"]}
  """
  @spec list_sheets(source(), keyword()) :: {:ok, [String.t()]} | {:error, map()}
  def list_sheets(source, opts) do
    case Keyword.fetch(opts, :parser) do
      {:ok, parser} ->
        parser.sheet_names(source)

      :error ->
        {:error,
         %{
           type: :missing_parser,
           message:
             "The :parser option is required. Pass a module implementing Raggio.Tabular.Parser behaviour."
         }}
    end
  end
end
