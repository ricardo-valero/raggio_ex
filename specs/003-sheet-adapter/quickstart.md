# Quickstart: Sheet Adapter (Parser-Agnostic)

This quickstart shows the intended usage of the Sheet Adapter feature. **You provide the parser implementation** for your preferred tabular format library.

## Prerequisites

Add your preferred parsing library to `mix.exs`:

```elixir
# For CSV parsing
{:nimble_csv, "~> 1.2"}

# For XLSX parsing  
{:xlsx_reader, "~> 0.8"}
```

## 1) Implement a Parser

Create a module implementing the `Raggio.Tabular.Parser` behaviour:

```elixir
# lib/my_app/csv_parser.ex
defmodule MyApp.CSVParser do
  @behaviour Raggio.Tabular.Parser

  @impl true
  def sheet_names(_source), do: {:ok, ["default"]}

  @impl true
  def stream_rows(path, _opts) do
    stream =
      path
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream()
      |> Stream.with_index(1)
      |> Stream.map(fn {cells, row_num} -> {row_num, cells} end)
    
    {:ok, stream}
  end
end
```

## 2) Define a Schema

Map columns to typed fields:

```elixir
alias Raggio.Schema
alias Raggio.Tabular.SheetSchema

schema = SheetSchema.define([
  {:id, Schema.integer(min: 1)},
  {:name, Schema.string(min: 1)},
  {:email, Schema.string(), required: false}
])
```

## 3) Parse a CSV file

Pass the parser module explicitly:

```elixir
alias Raggio.Tabular

{:ok, result} = Tabular.parse("users.csv", schema, parser: MyApp.CSVParser)

# Valid rows
Enum.each(result.valid_rows, fn row ->
  IO.puts("User: #{row.name} (#{row.email})")
end)

# Invalid rows with errors
Enum.each(result.invalid_rows, fn error ->
  IO.puts("Row #{error.row}: #{error.path} - #{error.message}")
end)
```

## 4) Parse an XLSX file

Implement an XLSX parser and specify the sheet:

```elixir
# List available sheets first
{:ok, sheets} = Tabular.list_sheets("workbook.xlsx", parser: MyApp.XLSXParser)
# => {:ok, ["Sheet1", "Data", "Summary"]}

# Parse a specific sheet
{:ok, result} = Tabular.parse("workbook.xlsx", schema,
  parser: MyApp.XLSXParser,
  sheet: "Data"
)
```

## 5) Handle errors

**Format errors** (cannot read file at all):
```elixir
case Tabular.parse("missing.csv", schema, parser: MyApp.CSVParser) do
  {:ok, result} -> process(result)
  {:error, %{type: :file_not_found, message: msg}} -> IO.puts("Error: #{msg}")
end
```

**Row errors** (some rows invalid):
```elixir
{:ok, result} = Tabular.parse("data.csv", schema, parser: MyApp.CSVParser)

if result.invalid_rows != [] do
  IO.puts("#{length(result.invalid_rows)} rows had errors:")
  for error <- result.invalid_rows do
    IO.puts("  Row #{error.row}, #{error.path}: #{error.message} (value: #{inspect(error.value)})")
  end
end
```

## 6) Header Variants

Handle spreadsheets with varying column names:

```elixir
schema =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:name, Schema.string()}
  ])
  |> SheetSchema.with_header_variants(%{
    "User ID" => :id,
    "user_id" => :id,
    "Full Name" => :name
  })
```

## 7) Union Schemas

Handle multiple file format versions:

```elixir
alias Raggio.Tabular.Union

union = Union.new([schema_v1, schema_v2], strategy: :first_match)

{:ok, result} = Tabular.parse("data.csv", union, parser: MyApp.CSVParser)
IO.puts("Matched schema: #{result.matched_schema}")
```

## Next steps

- See `specs/003-sheet-adapter/contracts/adapter_contract.md` for the full Parser behaviour spec
- See `examples/tabular/` for complete CSV and XLSX parser implementations
- See `specs/003-sheet-adapter/contracts/tabular_api.md` for the full public API
