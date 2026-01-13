# Raggio

Composable data schema definition, validation, and syntax manipulation for Elixir.

## Overview

Raggio provides two main submodules:

- **Raggio.Schema** - Define and validate data schemas
- **Raggio.Syntax** - Build and manipulate syntax trees (coming soon)

## Installation

Add Raggio to your `mix.exs`:

```elixir
def deps do
  [{:raggio, "~> 0.1.0"}]
end
```

## Quick Start

```elixir
alias Raggio.Schema

user_schema =
  Schema.struct([
    {:name, Schema.string(min: 1, max: 100)},
    {:age, Schema.integer(min: 0)},
    {:email, Schema.string(pattern: Schema.email())}
  ])

case Schema.validate(user_schema, %{name: "Alice", age: 30, email: "alice@example.com"}) do
  {:ok, data} -> IO.puts("Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("Invalid: #{inspect(errors)}")
end
```

## Type Constructors

### Primitives

```elixir
Schema.string(min: 3, max: 100, pattern: ~r/^[A-Z]/)
Schema.integer(min: 0, max: 150)
Schema.float(min: 0.0, max: 100.0)
Schema.boolean(default: false)
Schema.decimal(min: Decimal.new("0"))
Schema.date()
Schema.datetime()
Schema.atom()
```

### Composites

```elixir
Schema.struct([{:name, Schema.string()}, {:age, Schema.integer()}])
Schema.list(Schema.string(), min: 1, max: 10, unique: true)
Schema.tuple([Schema.string(), Schema.integer()])
Schema.union([Schema.string(), Schema.integer()])
Schema.literal(:active, :inactive, :pending)
Schema.record(Schema.string(), Schema.integer())
```

### Field Descriptors

```elixir
Schema.optional(Schema.string())
Schema.nullable(Schema.integer())
```

## Validation

```elixir
Schema.validate(schema, data)
Schema.validate(schema, data, mode: :all_errors)
Schema.validate(schema, data, partial: true)
Schema.validate!(schema, data)
```

## Examples

Working examples in `examples/schema/basic_validation/`:

```bash
mix run examples/schema/basic_validation/simple_schema.exs
mix run examples/schema/basic_validation/nested_structs.exs
mix run examples/schema/basic_validation/lists_and_records.exs
```

## Development

```bash
mix deps.get
mix compile
mix test
mix format
```

## License

MIT
