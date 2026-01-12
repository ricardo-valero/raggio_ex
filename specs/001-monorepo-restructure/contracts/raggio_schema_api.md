# Raggio.Schema Public API Contract

**Version**: 0.1.0  
**Date**: 2026-01-12  
**Package**: `raggio_schema`

---

## Module: Raggio.Schema

Main entry point for schema definition and validation.

### Type Definition Function

#### `string/0`
**Signature**: `() -> schema`  
**Purpose**: Create string type schema  
**Return**: Schema representing string type  
**Example**: 
```elixir
Raggio.Schema.string()
```

#### `integer/0`
**Signature**: `() -> schema`  
**Purpose**: Create integer type schema  
**Return**: Schema representing integer type  
**Example**:
```elixir
Raggio.Schema.integer()
```

#### `float/0`
**Signature**: `() -> schema`  
**Purpose**: Create float type schema  
**Return**: Schema representing float type  
**Example**:
```elixir
Raggio.Schema.float()
```

#### `boolean/0`
**Signature**: `() -> schema`  
**Purpose**: Create boolean type schema  
**Return**: Schema representing boolean type  
**Example**:
```elixir
Raggio.Schema.boolean()
```

#### `date/0`
**Signature**: `() -> schema`  
**Purpose**: Create date type schema (without time)  
**Return**: Schema representing date type  
**Example**:
```elixir
Raggio.Schema.date()
```

#### `datetime/0`
**Signature**: `() -> schema`  
**Purpose**: Create datetime type schema (with time and timezone)  
**Return**: Schema representing datetime type  
**Example**:
```elixir
Raggio.Schema.datetime()
```

#### `decimal/0`
**Signature**: `() -> schema`  
**Purpose**: Create arbitrary precision decimal type schema  
**Return**: Schema representing decimal type  
**Example**:
```elixir
Raggio.Schema.decimal()
```

#### `atom/0`
**Signature**: `() -> schema`  
**Purpose**: Create atom type schema  
**Return**: Schema representing atom type  
**Example**:
```elixir
Raggio.Schema.atom()
```

---

### Composite Type Function

#### `array/1`
**Signature**: `(element_schema :: schema) -> schema`  
**Purpose**: Create array type schema with specified element type  
**Parameter**: `element_schema` - Schema for array element  
**Return**: Schema representing array type  
**Example**:
```elixir
Raggio.Schema.array(Raggio.Schema.string())
```

#### `struct/1`
**Signature**: `(fields :: [{atom, schema}]) -> schema`  
**Purpose**: Create struct type schema with defined field  
**Parameter**: `fields` - List of tuple `{field_name, field_schema}`  
**Return**: Schema representing struct type  
**Example**:
```elixir
Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer()}
])
```

#### `enum/1`
**Signature**: `(values :: [any]) -> schema`  
**Purpose**: Create enum type schema with allowed value  
**Parameter**: `values` - List of allowed value  
**Return**: Schema representing enum type  
**Example**:
```elixir
Raggio.Schema.enum([:active, :inactive, :pending])
```

#### `union/1`
**Signature**: `(schemas :: [schema]) -> schema`  
**Purpose**: Create union type schema (value match one of provided schema)  
**Parameter**: `schemas` - List of schema  
**Return**: Schema representing union type  
**Example**:
```elixir
Raggio.Schema.union([
  Raggio.Schema.string(),
  Raggio.Schema.integer()
])
```

---

### Constraint Function (String)

#### `min_length/2`
**Signature**: `(schema :: schema, n :: non_neg_integer) -> schema`  
**Purpose**: Add minimum length constraint to string or array schema  
**Parameter**: 
- `schema` - Schema to constrain  
- `n` - Minimum length  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not string or array  
**Example**:
```elixir
Raggio.Schema.string() |> Raggio.Schema.min_length(5)
```

#### `max_length/2`
**Signature**: `(schema :: schema, n :: non_neg_integer) -> schema`  
**Purpose**: Add maximum length constraint to string or array schema  
**Parameter**:
- `schema` - Schema to constrain  
- `n` - Maximum length  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not string or array  
**Example**:
```elixir
Raggio.Schema.string() |> Raggio.Schema.max_length(50)
```

#### `pattern/2`
**Signature**: `(schema :: schema, regex :: Regex.t()) -> schema`  
**Purpose**: Add pattern matching constraint to string schema  
**Parameter**:
- `schema` - Schema to constrain  
- `regex` - Regular expression pattern  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not string  
**Example**:
```elixir
Raggio.Schema.string() |> Raggio.Schema.pattern(~r/^[A-Z]/)
```

#### `email/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Add email format constraint to string schema  
**Parameter**: `schema` - Schema to constrain  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not string  
**Example**:
```elixir
Raggio.Schema.string() |> Raggio.Schema.email()
```

#### `url/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Add URL format constraint to string schema  
**Parameter**: `schema` - Schema to constrain  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not string  
**Example**:
```elixir
Raggio.Schema.string() |> Raggio.Schema.url()
```

---

### Constraint Function (Numeric)

#### `min/2`
**Signature**: `(schema :: schema, value :: number) -> schema`  
**Purpose**: Add minimum value constraint to numeric schema  
**Parameter**:
- `schema` - Schema to constrain  
- `value` - Minimum value (inclusive)  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not numeric  
**Example**:
```elixir
Raggio.Schema.integer() |> Raggio.Schema.min(0)
```

#### `max/2`
**Signature**: `(schema :: schema, value :: number) -> schema`  
**Purpose**: Add maximum value constraint to numeric schema  
**Parameter**:
- `schema` - Schema to constrain  
- `value` - Maximum value (inclusive)  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not numeric  
**Example**:
```elixir
Raggio.Schema.integer() |> Raggio.Schema.max(100)
```

#### `positive/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Add positive number constraint to numeric schema  
**Parameter**: `schema` - Schema to constrain  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not numeric  
**Example**:
```elixir
Raggio.Schema.integer() |> Raggio.Schema.positive()
```

#### `negative/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Add negative number constraint to numeric schema  
**Parameter**: `schema` - Schema to constrain  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not numeric  
**Example**:
```elixir
Raggio.Schema.integer() |> Raggio.Schema.negative()
```

#### `range/3`
**Signature**: `(schema :: schema, min :: number, max :: number) -> schema`  
**Purpose**: Add range constraint to numeric schema  
**Parameter**:
- `schema` - Schema to constrain  
- `min` - Minimum value (inclusive)  
- `max` - Maximum value (inclusive)  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not numeric  
**Example**:
```elixir
Raggio.Schema.integer() |> Raggio.Schema.range(1, 100)
```

---

### Constraint Function (Array)

#### `min_items/2`
**Signature**: `(schema :: schema, n :: non_neg_integer) -> schema`  
**Purpose**: Add minimum item count constraint to array schema  
**Parameter**:
- `schema` - Schema to constrain  
- `n` - Minimum item count  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not array  
**Example**:
```elixir
Raggio.Schema.array(Raggio.Schema.string()) |> Raggio.Schema.min_items(1)
```

#### `max_items/2`
**Signature**: `(schema :: schema, n :: non_neg_integer) -> schema`  
**Purpose**: Add maximum item count constraint to array schema  
**Parameter**:
- `schema` - Schema to constrain  
- `n` - Maximum item count  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not array  
**Example**:
```elixir
Raggio.Schema.array(Raggio.Schema.string()) |> Raggio.Schema.max_items(10)
```

#### `unique/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Add uniqueness constraint to array schema (no duplicate)  
**Parameter**: `schema` - Schema to constrain  
**Return**: Schema with constraint added  
**Error**: CompositionError if schema type not array  
**Example**:
```elixir
Raggio.Schema.array(Raggio.Schema.integer()) |> Raggio.Schema.unique()
```

---

### Validation Function

#### `validate/2`
**Signature**: `(schema :: schema, data :: any) -> {:ok, any} | {:error, [validation_error]}`  
**Purpose**: Validate data against schema  
**Parameter**:
- `schema` - Schema to validate against  
- `data` - Data to validate  
**Return**: 
- `{:ok, validated_data}` on success  
- `{:error, error_list}` on failure with accumulated error  
**Example**:
```elixir
schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer() |> Raggio.Schema.positive()}
])

case Raggio.Schema.validate(schema, %{name: "Alice", age: 30}) do
  {:ok, data} -> IO.puts("Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("Invalid: #{inspect(errors)}")
end
```

#### `validate!/2`
**Signature**: `(schema :: schema, data :: any) -> any`  
**Purpose**: Validate data against schema, raise on error  
**Parameter**:
- `schema` - Schema to validate against  
- `data` - Data to validate  
**Return**: Validated data  
**Raise**: `Raggio.Schema.ValidationError` on validation failure  
**Example**:
```elixir
validated = Raggio.Schema.validate!(schema, data)
```

---

### Composition Function

#### `compose/2`
**Signature**: `(schema1 :: schema, schema2 :: schema) -> {:ok, schema} | {:error, composition_error}`  
**Purpose**: Compose two schema (merge constraint and validator)  
**Parameter**:
- `schema1` - First schema  
- `schema2` - Second schema  
**Return**: 
- `{:ok, composed_schema}` if type compatible  
- `{:error, composition_error}` if type incompatible  
**Example**:
```elixir
base = Raggio.Schema.string()
constrained = Raggio.Schema.string() |> Raggio.Schema.min_length(5)

case Raggio.Schema.compose(base, constrained) do
  {:ok, schema} -> schema
  {:error, error} -> raise error
end
```

#### `optional/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Mark schema as optional (allow nil value)  
**Parameter**: `schema` - Schema to mark optional  
**Return**: Schema allowing nil  
**Example**:
```elixir
Raggio.Schema.optional(Raggio.Schema.string())
```

#### `default/2`
**Signature**: `(schema :: schema, value :: any) -> schema`  
**Purpose**: Add default value to schema  
**Parameter**:
- `schema` - Schema to add default  
- `value` - Default value (must match schema type)  
**Return**: Schema with default value  
**Example**:
```elixir
Raggio.Schema.string() |> Raggio.Schema.default("N/A")
```

---

### Transformation Function

#### `transform/2`
**Signature**: `(schema :: schema, transformer :: (any -> {:ok, any} | {:error, any})) -> schema`  
**Purpose**: Add data transformation to schema  
**Parameter**:
- `schema` - Schema to transform  
- `transformer` - Transformation function  
**Return**: Schema with transformation  
**Example**:
```elixir
Raggio.Schema.string() 
|> Raggio.Schema.transform(fn s -> {:ok, String.trim(s)} end)
```

#### `coerce/1`
**Signature**: `(schema :: schema) -> schema`  
**Purpose**: Enable type coercion (e.g., "123" → 123 for integer)  
**Parameter**: `schema` - Schema to enable coercion  
**Return**: Schema with coercion enabled  
**Example**:
```elixir
Raggio.Schema.integer() |> Raggio.Schema.coerce()
```

---

## Module: Raggio.Schema.ValidationError

Error structure for validation failure.

### Structure

```elixir
%Raggio.Schema.ValidationError{
  path: [atom | integer],        # Path to error field [:user, :email] or [:items, 0]
  message: String.t(),            # Human-readable error message
  value: any(),                   # Invalid value (optional)
  constraint: atom()              # Constraint that failed
}
```

### Example

```elixir
%Raggio.Schema.ValidationError{
  path: [:user, :email],
  message: "must be valid email format",
  value: "not-an-email",
  constraint: :email
}
```

---

## Module: Raggio.Schema.CompositionError

Error raised when composing incompatible schema.

### Structure

```elixir
%Raggio.Schema.CompositionError{
  message: String.t(),            # Error description
  left_type: atom(),              # Type of first schema
  right_type: atom()              # Type of second schema
}
```

### Example

```elixir
%Raggio.Schema.CompositionError{
  message: "Cannot compose incompatible type",
  left_type: :string,
  right_type: :integer
}
```

---

## Usage Pattern

### Basic Schema Definition

```elixir
# Simple type
user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer()}
])

# With constraint
email_schema = Raggio.Schema.string() 
|> Raggio.Schema.email()

# Nested structure
address_schema = Raggio.Schema.struct([
  {:street, Raggio.Schema.string()},
  {:city, Raggio.Schema.string()},
  {:zip, Raggio.Schema.string() |> Raggio.Schema.pattern(~r/^\d{5}$/)}
])

full_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:email, email_schema},
  {:address, address_schema}
])
```

### Composition Pattern

```elixir
# Composing constraint
constrained = Raggio.Schema.string()
|> Raggio.Schema.min_length(5)
|> Raggio.Schema.max_length(50)
|> Raggio.Schema.pattern(~r/^[A-Za-z\s]+$/)

# Optional with default
optional_field = Raggio.Schema.string()
|> Raggio.Schema.default("N/A")
|> Raggio.Schema.optional()
```

### Validation Pattern

```elixir
# Validate and handle error
case Raggio.Schema.validate(schema, data) do
  {:ok, validated} ->
    # Proceed with validated data
    process(validated)
    
  {:error, errors} ->
    # Handle validation error
    errors
    |> Enum.map(fn err -> "#{Enum.join(err.path, ".")}: #{err.message}" end)
    |> Enum.join("\n")
    |> IO.puts()
end
```

---

## Breaking Change Policy

Per specification, this is a clean break from old_code. No backward compatibility guarantee.

**Version**: All function follow semantic versioning. Breaking change increment major version.
