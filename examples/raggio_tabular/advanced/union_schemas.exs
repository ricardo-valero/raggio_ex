alias Raggio.Schema
alias RaggioTabular.SheetSchema

IO.puts("=== Union Schemas Example ===\n")

format_v1 =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:name, Schema.string()},
    {:value, Schema.float()}
  ])

format_v2 =
  SheetSchema.define([
    {:identifier, Schema.string()},
    {:description, Schema.string()},
    {:amount, Schema.decimal()}
  ])

union_schema = SheetSchema.union([format_v1, format_v2])

IO.puts("Union schema supports multiple formats:")
IO.puts("  Format V1: id (int), name (string), value (float)")
IO.puts("  Format V2: identifier (string), description (string), amount (decimal)")

IO.puts("\nRow range filtering example:")

schema_with_range =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:data, Schema.string()}
  ])
  |> SheetSchema.with_row_range(3, 5)

IO.puts("  Schema configured to parse rows 3-5 only")

skip_schema =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:data, Schema.string()}
  ])
  |> SheetSchema.skip_rows(2)

IO.puts("  Schema configured to skip first 2 data rows")

IO.puts("\nUnion schemas example complete!")
