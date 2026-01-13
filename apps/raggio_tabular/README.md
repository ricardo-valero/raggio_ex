# Raggio.Tabular

CSV/Excel parsing and validation library built on Raggio.Schema.

## Purpose

Raggio.Tabular provides tools for parsing tabular data from CSV/TSV files and validating rows against schema definitions. It handles Excel-specific data quirks and supports batch processing with progress tracking.

## Installation

Add `raggio_tabular` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raggio_tabular, "~> 0.1.0"}
  ]
end
```

## Quick Example

```elixir
alias Raggio.Schema
alias RaggioTabular.SheetSchema

schema = SheetSchema.define([
  {:id, Schema.integer()},
  {:name, Schema.string(min: 1)},
  {:email, Schema.string(pattern: Schema.email())}
])

{:ok, result} = RaggioTabular.parse("users.csv", schema)

IO.puts("Valid rows: #{length(result.valid_rows)}")
IO.puts("Invalid rows: #{length(result.invalid_rows)}")
```

## More Examples

See the `examples/raggio_tabular/` directory for working examples.
