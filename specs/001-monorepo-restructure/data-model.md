# Data Model: Multi-Package Monorepo Restructure

**Date**: 2026-01-13  
**Feature**: 001-monorepo-restructure

## Core Entities

### Schema Struct (Raggio.Schema)

The central data structure representing a schema definition.

```elixir
defstruct [
  :type,           # atom - :string, :integer, :float, :boolean, :decimal, 
                   #        :date, :datetime, :atom, :struct, :list, :tuple, 
                   #        :record, :union, :literal
  :encoded,        # atom - wire format type hint
  :constraints,    # keyword list - [{:min, 3}, {:max, 10}, {:pattern, ~r/.../, {:unique, true}]
  :fields,         # keyword list | nil - for struct: [{:name, schema}, ...]
                   #                      for record: [key: key_schema, value: value_schema]
  :inner_type,     # Schema.t() | nil - for list: element schema
  :types,          # [Schema.t()] | nil - for union/tuple: list of schemas
  :values,         # [any()] | nil - for literal: allowed values
  :optional,       # boolean - field can be missing (default: false)
  :nullable,       # boolean - value can be nil (default: false)
  :default,        # any() | nil - default value when nil/missing
  :annotations     # map - user metadata
]
```

**Field Semantics**:

| Field | Used By | Purpose |
|-------|---------|---------|
| `type` | All | Identifies the schema type |
| `encoded` | All | Hint for serialization format |
| `constraints` | Primitives, List | Validation constraints as keyword list |
| `fields` | Struct, Record | Named fields or key/value schemas |
| `inner_type` | List | Element schema |
| `types` | Union, Tuple | Component schemas |
| `values` | Literal | Allowed literal values |
| `optional` | All (in struct context) | Field presence descriptor |
| `nullable` | All | Nil value allowed |
| `default` | All | Default value |
| `annotations` | All | User-defined metadata |

### Validation Error

```elixir
%{
  path: [atom() | integer()],  # Path to error location
  message: String.t(),          # Human-readable error description
  value: any(),                 # The invalid value
  constraint: atom() | nil      # Which constraint failed (:min, :max, :pattern, :unique, :type)
}
```

### Validation Result

```elixir
@type validation_result :: 
  {:ok, any()} | 
  {:error, [validation_error()]} |
  {:ok, {successes :: any(), failures :: [validation_error()]}}  # partial mode
```

## Type Constructors

### Primitive Types

| Constructor | Returns | Constraints |
|-------------|---------|-------------|
| `string(opts \\ [])` | `%Schema{type: :string}` | min, max, pattern, default |
| `integer(opts \\ [])` | `%Schema{type: :integer}` | min, max, default |
| `float(opts \\ [])` | `%Schema{type: :float}` | min, max, default |
| `boolean(opts \\ [])` | `%Schema{type: :boolean}` | default |
| `decimal(opts \\ [])` | `%Schema{type: :decimal}` | min, max, default |
| `date(opts \\ [])` | `%Schema{type: :date}` | default |
| `datetime(opts \\ [])` | `%Schema{type: :datetime}` | default |
| `atom(opts \\ [])` | `%Schema{type: :atom}` | default |

### Composite Types

| Constructor | Returns | Arguments |
|-------------|---------|-----------|
| `struct(fields)` | `%Schema{type: :struct, fields: fields}` | `[{atom, Schema.t}]` |
| `list(inner, opts \\ [])` | `%Schema{type: :list, inner_type: inner}` | `Schema.t`, min, max, unique, default |
| `tuple(types)` | `%Schema{type: :tuple, types: types}` | `[Schema.t]` |
| `record(key, value)` | `%Schema{type: :record, fields: [...]}` | `Schema.t`, `Schema.t` |
| `union(types)` | `%Schema{type: :union, types: types}` | `[Schema.t]` |
| `literal(values...)` | `%Schema{type: :literal, values: [...]}` | variadic any() |

### Field Descriptors

| Function | Returns | Effect |
|----------|---------|--------|
| `optional(schema)` | `%Schema{...schema, optional: true}` | Field can be missing |
| `nullable(schema)` | `%Schema{...schema, nullable: true}` | Value can be nil |

## Constraint Semantics

### min

```elixir
# For numbers: value >= min
Schema.integer(min: 0)  # value must be >= 0

# For strings: String.length(value) >= min
Schema.string(min: 3)   # string must have at least 3 characters

# For lists: length(value) >= min
Schema.list(Schema.string(), min: 1)  # list must have at least 1 element
```

### max

```elixir
# For numbers: value <= max
Schema.integer(max: 100)  # value must be <= 100

# For strings: String.length(value) <= max
Schema.string(max: 20)    # string must have at most 20 characters

# For lists: length(value) <= max
Schema.list(Schema.string(), max: 10)  # list must have at most 10 elements
```

### pattern

```elixir
# For strings only: Regex.match?(pattern, value)
Schema.string(pattern: ~r/^[A-Z][a-z]+$/)  # must match pattern
```

### unique

```elixir
# For lists only: no duplicate elements
Schema.list(Schema.string(), unique: true)  # all elements must be unique
```

## Syntax Node Entities (Raggio.Syntax)

### Node Protocol

```elixir
defprotocol Raggio.Syntax.Node do
  @spec node_type(t) :: atom()
  def node_type(node)
  
  @spec children(t) :: [t]
  def children(node)
end
```

### SchemaNode

```elixir
defstruct [
  :type,        # :schema
  :name,        # atom | nil - optional name
  :schema_type, # atom - :struct, :list, etc.
  :fields,      # [FieldNode.t()] | nil
  :metadata     # map
]
```

### FieldNode

```elixir
defstruct [
  :type,       # :field
  :name,       # atom - field name
  :field_type, # TypeNode.t() - field type reference
  :required,   # boolean
  :default,    # any() | nil
  :metadata    # map
]
```

### TypeNode

```elixir
defstruct [
  :type,       # :type
  :name,       # atom - type name (:string, :integer, etc.)
  :parameters, # [TypeNode.t()] | nil - for generics
  :metadata    # map
]
```

### SyntaxTree

```elixir
defstruct [
  :root,     # Node.t() - root node
  :metadata  # map - tree-level metadata
]
```

## Adapter Entities

### BigQuery Column Mapping

| Schema Type | BigQuery Type |
|-------------|---------------|
| `:string` | `STRING` |
| `:integer` | `INT64` |
| `:float` | `FLOAT64` |
| `:boolean` | `BOOL` |
| `:decimal` | `NUMERIC` |
| `:date` | `DATE` |
| `:datetime` | `DATETIME` |
| `:atom` | `STRING` |
| `:struct` | `STRUCT<...>` |
| `:list` | `ARRAY<...>` |

### SheetSchema Column Format

| Column | Type | Description |
|--------|------|-------------|
| `field_name` | string | Field identifier |
| `type` | string | Type name (string, integer, list(string), etc.) |
| `required` | boolean | Whether field is required |
| `constraints` | string | Pipe-separated constraints (min:3\|max:10) |
| `description` | string | Human-readable description |
| `example` | string | Example value |
| `default` | string | Default value |
| `parent_path` | string | Dot notation for nesting (address.city) |

## State Transitions

Schema structs are immutable. Wrapper functions return new structs:

```
Schema.t() --optional()--> Schema.t(optional: true)
Schema.t() --nullable()--> Schema.t(nullable: true)
```

Validation is stateless:
```
{Schema.t(), any()} --validate()--> {:ok, any()} | {:error, [error()]}
```
