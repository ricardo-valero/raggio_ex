# Raggio.Schema Public API Contract

**Version**: 0.2.0  
**Date**: 2026-01-13

## Type Constructors

### Primitive Types

```elixir
@spec string(keyword()) :: Schema.t()
def string(opts \\ [])
# opts: min: integer, max: integer, pattern: Regex.t, default: String.t

@spec integer(keyword()) :: Schema.t()
def integer(opts \\ [])
# opts: min: integer, max: integer, default: integer

@spec float(keyword()) :: Schema.t()
def float(opts \\ [])
# opts: min: number, max: number, default: float

@spec boolean(keyword()) :: Schema.t()
def boolean(opts \\ [])
# opts: default: boolean

@spec decimal(keyword()) :: Schema.t()
def decimal(opts \\ [])
# opts: min: number, max: number, default: Decimal.t

@spec date(keyword()) :: Schema.t()
def date(opts \\ [])
# opts: default: Date.t

@spec datetime(keyword()) :: Schema.t()
def datetime(opts \\ [])
# opts: default: DateTime.t | NaiveDateTime.t

@spec atom(keyword()) :: Schema.t()
def atom(opts \\ [])
# opts: default: atom
```

### Composite Types

```elixir
@spec struct([{atom(), Schema.t()}]) :: Schema.t()
def struct(fields)
# fields: keyword list of {field_name, field_schema}

@spec list(Schema.t(), keyword()) :: Schema.t()
def list(inner_schema, opts \\ [])
# opts: min: integer, max: integer, unique: boolean, default: list

@spec tuple([Schema.t()]) :: Schema.t()
def tuple(schemas)
# schemas: list of schemas for each tuple position

@spec record(Schema.t(), Schema.t()) :: Schema.t()
def record(key_schema, value_schema)
# key_schema: schema for map keys
# value_schema: schema for map values

@spec union([Schema.t()]) :: Schema.t()
def union(schemas)
# schemas: list of alternative schemas (minimum 2)

@spec literal(any(), ...) :: Schema.t()
def literal(value, ...)
# variadic: allowed literal values (atoms, strings, integers)
```

### Field Descriptors

```elixir
@spec optional(Schema.t()) :: Schema.t()
def optional(schema)
# Marks field as optional (can be missing from struct)

@spec nullable(Schema.t()) :: Schema.t()
def nullable(schema)
# Allows nil as valid value
```

### Convenience Helpers

```elixir
@spec email() :: Regex.t()
def email()
# Returns regex for email validation

@spec url() :: Regex.t()
def url()
# Returns regex for URL validation

@spec uuid() :: Regex.t()
def uuid()
# Returns regex for UUID validation
```

## Validation

```elixir
@spec validate(Schema.t(), any()) :: {:ok, any()} | {:error, [map()]}
def validate(schema, data)
# Default mode: fail-fast

@spec validate(Schema.t(), any(), keyword()) :: 
  {:ok, any()} | 
  {:error, [map()]} |
  {:ok, {any(), [map()]}}
def validate(schema, data, opts)
# opts: 
#   mode: :fail_fast (default) | :all_errors
#   partial: boolean (default: false)

@spec validate!(Schema.t(), any()) :: any()
def validate!(schema, data)
# Raises Raggio.Schema.ValidationError on failure
```

## Error Structure

```elixir
%{
  path: [atom() | integer()],  # [:user, :address, 0, :zip]
  message: String.t(),          # "minimum length is 5"
  value: any(),                 # "123"
  constraint: atom()            # :min | :max | :pattern | :unique | :type | :required
}
```

## Adapters

### BigQuery Exporter

```elixir
@spec to_ddl(Schema.t(), String.t()) :: String.t()
def to_ddl(schema, table_name)

@spec to_ddl(Schema.t(), String.t(), keyword()) :: String.t()
def to_ddl(schema, table_name, opts)
# opts: partition_by: String.t, cluster_by: [String.t], description: String.t
```

### SheetSchema Importer

```elixir
@spec from_csv(String.t()) :: {:ok, String.t()} | {:error, [map()]}
def from_csv(csv_path)
# Returns generated Elixir code

@spec from_csv(String.t(), keyword()) :: {:ok, String.t()} | {:error, [map()]}
def from_csv(csv_path, opts)
# opts: module_name: String.t, format: :code | :schema

@spec from_url(String.t()) :: {:ok, String.t()} | {:error, term()}
def from_url(google_sheets_url)

@spec validate_format(String.t()) :: :ok | {:error, [map()]}
def validate_format(csv_path)
# Validates CSV format without generating code
```
