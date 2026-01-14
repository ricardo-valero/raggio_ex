alias Raggio.Schema
alias Raggio.Tabular.SheetSchema

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

_union_schema = SheetSchema.union([format_v1, format_v2], strategy: :first_match)

IO.puts("Union schema created with two format variants:")
IO.puts("  Format V1: id (int), name (string), value (float)")
IO.puts("  Format V2: identifier (string), description (string), amount (decimal)")
IO.puts("\nStrategy: :first_match (use first schema that matches headers)")

_exact_one_union = SheetSchema.union([format_v1, format_v2], strategy: :exact_one)

IO.puts("\nAlternatively, use :exact_one strategy to require exactly one match")
IO.puts("(returns error if multiple schemas match)")

IO.puts("\nUsage with parser-agnostic API:")

IO.puts("""
  # Union schemas work with any parser implementation
  {:ok, result} = Tabular.parse("data.csv", union_schema,
    parser: Examples.Tabular.CSVParser
  )

  # result.matched_schema indicates which format was detected
""")

IO.puts("\nRow filtering example:")

_schema_with_filters =
  SheetSchema.define([
    {:id, Schema.integer()},
    {:data, Schema.string()}
  ])
  |> SheetSchema.with_row_filters(%{skip_rows: 2, row_range: 3..10})

IO.puts("Schema configured with row filters:")
IO.puts("  - skip_rows: 2 (skip first 2 data rows)")
IO.puts("  - row_range: 3..10 (only process rows 3-10)")

IO.puts("\nUnion schemas example complete!")
