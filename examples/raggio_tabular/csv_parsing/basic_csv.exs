alias Raggio.Schema
alias Raggio.Tabular.SheetSchema

IO.puts("=== Basic CSV Parsing Example ===\n")

_schema =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:name, Schema.string(min: 1)},
    {:age, Schema.integer(min: 0), required: false}
  ])

IO.puts("Schema defined for: id (integer), name (string), age (optional integer)")
IO.puts("\nParser-Agnostic Architecture:")
IO.puts("This library requires you to provide your own parser implementation.")
IO.puts("See examples/tabular/ for reference implementations.\n")

IO.puts("To parse a CSV file:")

IO.puts("""
  # First, implement Raggio.Tabular.Parser behaviour (or use example)
  # Then parse with explicit parser:

  {:ok, result} = Tabular.parse("users.csv", schema,
    parser: Examples.Tabular.CSVParser
  )

  # result.valid_rows => [%{id: 1, name: "Alice", age: 30}, ...]
  # result.invalid_rows => [%Raggio.Tabular.Error{row: 5, ...}, ...]
  # result.row_count => count of processed rows
""")

IO.puts("With options:")

IO.puts("""
  {:ok, result} = Tabular.parse("users.csv", schema,
    parser: Examples.Tabular.CSVParser,
    delimiter: ",",
    header: :present
  )
""")

IO.puts("To list sheets (CSV always returns [\"default\"]):")

IO.puts("""
  {:ok, sheets} = Tabular.list_sheets("data.csv",
    parser: Examples.Tabular.CSVParser
  )
  # => {:ok, ["default"]}
""")

IO.puts("\nBasic CSV parsing example complete!")
