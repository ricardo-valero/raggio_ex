alias Raggio.Schema
alias RaggioTabular.SheetSchema

IO.puts("=== Basic CSV Parsing Example ===\n")

schema =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:name, Schema.string(min: 1)},
    {:age, Schema.optional(Schema.integer(min: 0))}
  ])

csv_content = """
id,name,age
1,Alice,30
2,Bob,25
3,Charlie,
4,Diana,28
"""

IO.puts("Input CSV:")
IO.puts(csv_content)

{:ok, result} = RaggioTabular.parse_string(csv_content, schema)

IO.puts("\nParsing Results:")
IO.puts("Valid rows: #{length(result.valid_rows)}")
IO.puts("Invalid rows: #{length(result.invalid_rows)}")
IO.puts("Total rows: #{result.total_rows}")

IO.puts("\nValid data:")

Enum.each(result.valid_rows, fn row ->
  IO.puts("  #{row.id}: #{row.name} (age: #{row.age || "N/A"})")
end)

IO.puts("\nBasic CSV parsing complete!")
