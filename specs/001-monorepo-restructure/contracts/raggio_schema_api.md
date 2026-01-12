# Raggio.Schema API Contract

**Package**: `raggio_schema`  
**Module**: `Raggio.Schema`  
**Version**: 1.0.0

## Overview

Composable schema definition and validation library using pipe-based function composition.

---

## Core Type Constructors

### `string/0`

Creates a string type schema.

**Signature**: `string() :: Schema.t()`

**Returns**: Schema struct for string type

**Example**:
```elixir
Schema.string()
# => %Schema{type: :string, encoded: :string, filters: [], annotations: %{}}
```

---

### `integer/0`

Creates an integer type schema.

**Signature**: `integer() :: Schema.t()`

**Returns**: Schema struct for integer type

**Example**:
```elixir
Schema.integer()
# => %Schema{type: :integer, encoded: :integer, filters: [], annotations: %{}}
```

---

### `float/0`

Creates a float type schema.

**Signature**: `float() :: Schema.t()`

---

### `boolean/0`

Creates a boolean type schema.

**Signature**: `boolean() :: Schema.t()`

---

### `date/0`

Creates a date type schema.

**Signature**: `date() :: Schema.t()`

---

### `datetime/0`

Creates a datetime type schema.

**Signature**: `datetime() :: Schema.t()`

---

### `decimal/0`

Creates a decimal type schema.

**Signature**: `decimal() :: Schema.t()`

---

### `atom/0`

Creates an atom type schema.

**Signature**: `atom() :: Schema.t()`

---

## Composite Type Constructors

### `struct/1`

Creates a struct type schema with named fields.

**Signature**: `struct(fields :: keyword(Schema.t())) :: Schema.t()`

**Parameters**:
- `fields` - Keyword list of field_name => schema pairs

**Returns**: Schema struct for struct type

**Example**:
```elixir
Schema.struct([
  name: Schema.string() |> Schema.min_length(1),
  age: Schema.integer() |> Schema.min(0)
])
```

---

### `list/1`

Creates a list type schema.

**Signature**: `list(inner_schema :: Schema.t()) :: Schema.t()`

**Parameters**:
- `inner_schema` - Schema for list elements

**Example**:
```elixir
Schema.list(Schema.string())
# List of strings

Schema.list(Schema.integer() |> Schema.positive())
# List of positive integers
```

---

### `map/0`

Creates a map type schema (unstructured key-value pairs).

**Signature**: `map() :: Schema.t()`

---

### `union/1`

Creates a union type schema (one of multiple types).

**Signature**: `union(schemas :: [Schema.t()]) :: Schema.t()`

**Parameters**:
- `schemas` - List of alternative schemas (minimum 2)

**Example**:
```elixir
Schema.union([
  Schema.string(),
  Schema.integer()
])
# Accepts string OR integer
```

---

### `enum/1`

Creates an enum type schema (one of specific values).

**Signature**: `enum(values :: [term()]) :: Schema.t()`

**Parameters**:
- `values` - List of allowed values

**Example**:
```elixir
Schema.enum(["active", "inactive", "suspended"])
```

---

## String Constraints

### `min_length/1`

Adds minimum length constraint to string schema.

**Signature**: `min_length(Schema.t(), integer()) :: Schema.t()`

**Parameters**:
- `schema` - String schema to constrain
- `length` - Minimum length (inclusive)

**Returns**: Schema with min_length filter added

**Example**:
```elixir
Schema.string() |> Schema.min_length(3)
```

**Pipe-friendly**: Yes (takes schema as first argument)

---

### `max_length/1`

Adds maximum length constraint to string schema.

**Signature**: `max_length(Schema.t(), integer()) :: Schema.t()`

**Example**:
```elixir
Schema.string() |> Schema.max_length(50)
```

---

### `pattern/1`

Adds regex pattern constraint to string schema.

**Signature**: `pattern(Schema.t(), Regex.t()) :: Schema.t()`

**Parameters**:
- `schema` - String schema
- `pattern` - Regex pattern to match

**Example**:
```elixir
Schema.string() |> Schema.pattern(~r/^[a-z0-9_]+$/)
```

---

### `email/0`

Adds email format constraint.

**Signature**: `email(Schema.t()) :: Schema.t()`

**Example**:
```elixir
Schema.string() |> Schema.email()
```

---

### `url/0`

Adds URL format constraint.

**Signature**: `url(Schema.t()) :: Schema.t()`

---

### `uuid/0`

Adds UUID format constraint.

**Signature**: `uuid(Schema.t()) :: Schema.t()`

---

## Number Constraints

### `min/1`

Adds minimum value constraint.

**Signature**: `min(Schema.t(), number()) :: Schema.t()`

**Parameters**:
- `schema` - Numeric schema
- `value` - Minimum value (inclusive)

**Example**:
```elixir
Schema.integer() |> Schema.min(0)
Schema.float() |> Schema.min(0.0)
```

---

### `max/1`

Adds maximum value constraint.

**Signature**: `max(Schema.t(), number()) :: Schema.t()`

---

### `positive/0`

Adds constraint that value must be > 0.

**Signature**: `positive(Schema.t()) :: Schema.t()`

**Example**:
```elixir
Schema.integer() |> Schema.positive()
```

---

### `negative/0`

Adds constraint that value must be < 0.

**Signature**: `negative(Schema.t()) :: Schema.t()`

---

### `range/2`

Adds range constraint (min and max).

**Signature**: `range(Schema.t(), number(), number()) :: Schema.t()`

**Parameters**:
- `min_value` - Minimum (inclusive)
- `max_value` - Maximum (inclusive)

**Example**:
```elixir
Schema.integer() |> Schema.range(1, 100)
```

---

## Collection Constraints

### `min_items/1`

Adds minimum items constraint to list.

**Signature**: `min_items(Schema.t(), non_neg_integer()) :: Schema.t()`

**Example**:
```elixir
Schema.list(Schema.string()) |> Schema.min_items(1)
```

---

### `max_items/1`

Adds maximum items constraint to list.

**Signature**: `max_items(Schema.t(), non_neg_integer()) :: Schema.t()`

---

### `unique/0`

Adds uniqueness constraint to list items.

**Signature**: `unique(Schema.t()) :: Schema.t()`

---

## Modifier Functions

### `optional/0`

Marks a field as optional (can be missing).

**Signature**: `optional(Schema.t()) :: Schema.t()`

**Example**:
```elixir
Schema.struct([
  required_field: Schema.string(),
  optional_field: Schema.string() |> Schema.optional()
])
```

---

### `nullable/0`

Allows nil value for the schema.

**Signature**: `nullable(Schema.t()) :: Schema.t()`

**Note**: Different from `optional/0` - nullable allows nil value, optional allows missing field

**Example**:
```elixir
Schema.string() |> Schema.nullable()
# Accepts string or nil
```

---

### `default/1`

Sets default value for optional field.

**Signature**: `default(Schema.t(), term()) :: Schema.t()`

**Parameters**:
- `value` - Default value to use when field is missing

**Example**:
```elixir
Schema.string() |> Schema.optional() |> Schema.default("anonymous")
```

---

## Validation Functions

### `validate/2`

Validates data against a schema.

**Signature**: `validate(Schema.t(), data :: term()) :: ValidationResult.t()`

**Parameters**:
- `schema` - Schema to validate against
- `data` - Data to validate

**Returns**:
- `{:ok, parsed_data}` - Validation succeeded
- `{:error, [ValidationError.t()]}` - Validation failed

**Example**:
```elixir
schema = Schema.struct([
  email: Schema.string() |> Schema.email()
])

Schema.validate(schema, %{email: "alice@example.com"})
# => {:ok, %{email: "alice@example.com"}}

Schema.validate(schema, %{email: "not-an-email"})
# => {:error, [%ValidationError{path: [:email], message: "Invalid email format", value: "not-an-email"}]}
```

---

### `validate!/2`

Validates data, raising on error.

**Signature**: `validate!(Schema.t(), data :: term()) :: term() | no_return()`

**Returns**: Parsed data on success

**Raises**: `Raggio.Schema.ValidationError` on failure

---

## Metadata Functions

### `annotate/2`

Adds metadata to schema.

**Signature**: `annotate(Schema.t(), annotations :: map()) :: Schema.t()`

**Parameters**:
- `annotations` - Map of metadata (description, custom message, etc.)

**Example**:
```elixir
Schema.string()
|> Schema.min_length(3)
|> Schema.annotate(%{
  description: "Username",
  message: "Username must be at least 3 characters"
})
```

---

## Custom Constraints

### `constraint/2`

Adds custom validation function.

**Signature**: `constraint(Schema.t(), validator :: (term() -> boolean() | {:error, String.t()})) :: Schema.t()`

**Parameters**:
- `validator` - Custom validation function

**Example**:
```elixir
Schema.string()
|> Schema.constraint(fn value ->
  if String.starts_with?(value, "admin_"), do: true, else: {:error, "Must start with admin_"}
end)
```

---

## Protocol: Raggio.Schema.Constraint

Allows custom constraint types.

### Functions

#### `validate/2`

**Signature**: `validate(constraint :: t(), value :: term()) :: :ok | :error`

#### `error_message/1`

**Signature**: `error_message(constraint :: t()) :: String.t()`

### Example Implementation

```elixir
defmodule DomainConstraint do
  defstruct [:domain]
end

defimpl Raggio.Schema.Constraint, for: DomainConstraint do
  def validate(%{domain: domain}, value) do
    if String.ends_with?(value, "@#{domain}"), do: :ok, else: :error
  end
  
  def error_message(%{domain: d}) do
    "Email must be from domain #{d}"
  end
end

# Usage
Schema.string()
|> Schema.constraint(%DomainConstraint{domain: "example.com"})
```

---

## Validation Options

Options can be passed to `validate/2` as third argument:

```elixir
Schema.validate(schema, data, mode: :all_errors)
```

### Available Options

- `mode: :fail_fast` (default) - Stop at first error
- `mode: :all_errors` - Collect all errors
- `partial: true` - Return `{:ok, {successes, failures}}` for structs

---

## Type Specifications

```elixir
@type t() :: %Raggio.Schema{
  type: atom(),
  encoded: atom(),
  filters: [filter()],
  annotations: map(),
  fields: %{atom() => t()} | nil,
  inner_type: t() | nil,
  types: [t()] | nil
}

@type filter() :: {atom(), term()} | Filter.t()

@type validation_result() :: {:ok, term()} | {:error, [validation_error()]}

@type validation_error() :: %ValidationError{
  path: [atom() | integer()],
  message: String.t(),
  value: term(),
  constraint: atom() | nil
}
```

---

*API contract for Raggio.Schema complete.*
