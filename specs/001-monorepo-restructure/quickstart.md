# Quickstart: Raggio

Get started with Raggio schema validation in 5 minutes.

## Installation

Add `raggio_schema` to your `mix.exs`:

```elixir
def deps do
  [
    {:raggio_schema, "~> 0.2.0"}
  ]
end
```

Run `mix deps.get`.

## Basic Usage

### Define a Schema

```elixir
alias Raggio.Schema

# Simple user schema
user_schema = Schema.struct([
  {:name, Schema.string(min: 1, max: 100)},
  {:age, Schema.integer(min: 0)},
  {:email, Schema.string(pattern: Schema.email())}
])
```

### Validate Data

```elixir
# Valid data
{:ok, user} = Schema.validate(user_schema, %{
  name: "Alice",
  age: 30,
  email: "alice@example.com"
})

# Invalid data
{:error, errors} = Schema.validate(user_schema, %{
  name: "",
  age: -5,
  email: "not-an-email"
})

# errors contains:
# [
#   %{path: [:name], message: "minimum length is 1", value: "", constraint: :min},
#   %{path: [:age], message: "must be at least 0", value: -5, constraint: :min},
#   %{path: [:email], message: "must match pattern ...", value: "not-an-email", constraint: :pattern}
# ]
```

## Core Constraints

Only 4 constraints - simple and powerful:

```elixir
# min/max work on numbers, strings, and lists
Schema.integer(min: 0, max: 100)           # 0 <= value <= 100
Schema.string(min: 3, max: 20)             # 3 <= length <= 20
Schema.list(Schema.string(), min: 1)       # at least 1 element

# pattern for string validation
Schema.string(pattern: ~r/^[A-Z][a-z]+$/)  # must match regex

# unique for lists
Schema.list(Schema.string(), unique: true)  # no duplicates
```

## Field Descriptors

```elixir
Schema.struct([
  # Required field (default)
  {:name, Schema.string(min: 1)},
  
  # Optional - field can be missing entirely
  {:bio, Schema.optional(Schema.string())},
  
  # Nullable - value can be nil
  {:middle_name, Schema.nullable(Schema.string())},
  
  # Default - use this value when nil/missing
  {:role, Schema.string(default: "user")}
])
```

## Composite Types

```elixir
# Lists with element schema
tags_schema = Schema.list(Schema.string(min: 1), max: 10)

# Nested structs
address_schema = Schema.struct([
  {:street, Schema.string()},
  {:city, Schema.string()},
  {:zip, Schema.string(pattern: ~r/^\d{5}$/)}
])

contact_schema = Schema.struct([
  {:name, Schema.string()},
  {:address, address_schema}
])

# Literal values (replaces enum)
status_schema = Schema.literal(:pending, :approved, :rejected)

# Union types
id_schema = Schema.union([Schema.string(), Schema.integer()])

# Record (typed map with dynamic keys)
scores_schema = Schema.record(Schema.string(), Schema.integer(min: 0))
# Validates: %{"math" => 95, "english" => 87}
```

## Validation Modes

```elixir
# Fail-fast (default) - stop at first error
{:error, [first_error]} = Schema.validate(schema, data)

# All errors - collect every validation failure
{:error, all_errors} = Schema.validate(schema, data, mode: :all_errors)

# Partial - return both successes and failures
{:ok, {valid_data, errors}} = Schema.validate(schema, data, partial: true)

# Raise on failure
user = Schema.validate!(schema, data)  # raises ValidationError
```

## Convenience Helpers

```elixir
# Pre-defined patterns
Schema.string(pattern: Schema.email())   # email format
Schema.string(pattern: Schema.url())     # URL format  
Schema.string(pattern: Schema.uuid())    # UUID format
```

## Next Steps

- See `examples/raggio_schema/` for more patterns
- Check `Raggio.Schema.Adapters.BigQuery` for DDL export
- Check `Raggio.Schema.Adapters.SheetSchema` for spreadsheet import
