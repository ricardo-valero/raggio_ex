alias Raggio.Schema
alias Raggio.Tabular
alias Raggio.Tabular.SheetSchema

IO.puts("=== Basic CSV Parsing Example ===\n")

schema =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:name, Schema.string(min: 1)},
    {:age, Schema.integer(min: 0), required: false}
  ])

IO.puts("Schema defined for: id (integer), name (string), age (optional integer)")
IO.puts("\nTo parse a CSV file:")

IO.puts("""
  {:ok, result} = Tabular.parse_file("users.csv", schema)

  # result.valid_rows => [%{id: 1, name: "Alice", age: 30}, ...]
  # result.invalid_rows => [%Raggio.Tabular.Error{row: 5, ...}, ...]
  # result.total_rows => count of processed rows
""")

IO.puts("With options:")

IO.puts("""
  {:ok, result} = Tabular.parse_file("users.csv", schema,
    delimiter: ",",
    header: :present
  )
""")

IO.puts("\nBasic CSV parsing example complete!")
