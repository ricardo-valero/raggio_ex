# Raggio

Composable data schema definition, validation, and syntax manipulation for Elixir.

## Overview

Raggio provides two main submodules:

- **Raggio.Schema** - Define and validate data schemas
- **Raggio.Syntax** - Build and manipulate syntax trees

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
    {:email, Schema.string(pattern: Schema.email())},
    {:status, Schema.string("active")},
    {:bio, Schema.string() |> Schema.optional()}
  ])

case Schema.validate(user_schema, %{name: "Alice", age: 30, email: "alice@example.com"}) do
  {:ok, data} -> IO.puts("Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("Invalid: #{inspect(errors)}")
end
```

## Type Constructors

### Primitives

```elixir
Schema.string()
Schema.string("default_value")
Schema.string(min: 3, max: 100, pattern: ~r/^[A-Z]/)
Schema.string("default", min: 3, max: 100)

Schema.integer()
Schema.integer(0)
Schema.integer(min: 0, max: 150)

Schema.float()
Schema.boolean(false)
Schema.decimal()
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

### Field Descriptors (pipe-friendly)

```elixir
Schema.string() |> Schema.optional()
Schema.integer() |> Schema.nullable()
Schema.list(Schema.integer()) |> Schema.optional()
```

## Validation

```elixir
Schema.validate(schema, data)
Schema.validate(schema, data, mode: :all_errors)
Schema.validate(schema, data, partial: true)
Schema.validate!(schema, data)
```

## Examples

Working examples in `examples/`:

```bash
mix run examples/schema/basic_validation/simple_schema.exs
mix run examples/schema/basic_validation/nested_structs.exs
mix run examples/schema/basic_validation/optional_nullable_default.exs
mix run examples/schema/adapters/bigquery_export.exs
mix run examples/syntax/node_building/basic_nodes.exs
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
