# Example Tabular Parsers

Reference implementations of `Raggio.Tabular.Parser` behaviour for CSV and XLSX formats.

## Setup

Add the parsing libraries to your `mix.exs`:

```elixir
defp deps do
  [
    {:raggio, "~> 0.1"},
    {:nimble_csv, "~> 1.2"},  # For CSV parsing
    {:xlsx_reader, "~> 0.8"}  # For XLSX parsing
  ]
end
```

## Usage

### CSV Parsing

```elixir
alias Raggio.Tabular
alias Raggio.Tabular.{SheetSchema, ColumnDef}
alias Raggio.Schema

# Define a schema
schema = SheetSchema.define([
  {:name, Schema.string()},
  {:age, Schema.integer()},
  {:email, Schema.string(), required: false}
])

# Parse with explicit parser
{:ok, result} = Tabular.parse("users.csv", schema,
  parser: Examples.Tabular.CSVParser
)

# Access results
Enum.each(result.valid_rows, fn row ->
  IO.puts("#{row.name} is #{row.age} years old")
end)

# Check for errors
if result.invalid_rows != [] do
  IO.puts("Errors found:")
  Enum.each(result.invalid_rows, fn error ->
    IO.puts("  Row #{error.row}: #{error.path} - #{error.message}")
  end)
end
```

### XLSX Parsing

```elixir
# List available sheets
{:ok, sheets} = Tabular.list_sheets("workbook.xlsx",
  parser: Examples.Tabular.XLSXParser
)
IO.inspect(sheets)  # => ["Sheet1", "Data", "Summary"]

# Parse a specific sheet
{:ok, result} = Tabular.parse("workbook.xlsx", schema,
  parser: Examples.Tabular.XLSXParser,
  sheet: "Data"
)
```

### TSV (Tab-Separated Values)

```elixir
{:ok, result} = Tabular.parse("data.tsv", schema,
  parser: Examples.Tabular.CSVParser,
  delimiter: "\t"
)
```

## Creating Your Own Parser

Implement the `Raggio.Tabular.Parser` behaviour:

```elixir
defmodule MyApp.CustomParser do
  @behaviour Raggio.Tabular.Parser

  @impl true
  def sheet_names(_source) do
    {:ok, ["default"]}
  end

  @impl true
  def stream_rows(source, opts) do
    # Return a stream of {row_number, cells} tuples
    # Row numbers should be 1-based
    stream =
      source
      |> your_parsing_logic()
      |> Stream.with_index(1)
      |> Stream.map(fn {cells, row_num} -> {row_num, cells} end)

    {:ok, stream}
  end
end
```

## Error Handling

Parser implementations should return structured errors:

```elixir
{:error, %{type: :file_not_found, message: "File not found: /path/to/file"}}
{:error, %{type: :invalid_format, message: "Not a valid CSV file"}}
{:error, %{type: :sheet_not_found, message: "Sheet 'Foo' not found", details: %{available: [...]}}}
```
