# Raggio.Schema

Composable schema definition and validation library for Elixir.

## Purpose

Raggio.Schema provides a composable, function-based API for defining data schemas and validating data without complex macro syntax. Build type-safe schemas using the pipe operator and pure functions.

## Installation

Add `raggio_schema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raggio_schema, "~> 0.1.0"}
  ]
end
```

## Quick Example

```elixir
# Define schema
user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer() |> Raggio.Schema.positive()}
])

# Validate data
case Raggio.Schema.validate(user_schema, %{name: "Alice", age: 30}) do
  {:ok, data} -> {:ok, data}
  {:error, errors} -> {:error, errors}
end
```

## More Examples

See the `examples/raggio_schema/` directory for working, compilable examples demonstrating various patterns and use cases.
