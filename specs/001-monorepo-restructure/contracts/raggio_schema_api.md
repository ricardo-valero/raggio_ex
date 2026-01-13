# Raggio.Schema Public API Contract

**Version**: 0.3.0  
**Date**: 2026-01-13

## Type Constructors

### Primitive Types

```elixir
@spec string() :: Schema.t()
@spec string(keyword()) :: Schema.t()
@spec string(default :: any()) :: Schema.t()
@spec string(default :: any(), keyword()) :: Schema.t()
def string()
def string(opts) when is_list(opts)
def string(default)
def string(default, opts)
# opts: min: integer, max: integer, pattern: Regex.t

@spec integer() :: Schema.t()
@spec integer(keyword()) :: Schema.t()
@spec integer(default :: any()) :: Schema.t()
@spec integer(default :: any(), keyword()) :: Schema.t()
def integer()
def integer(opts) when is_list(opts)
def integer(default)
def integer(default, opts)
# opts: min: integer, max: integer

@spec float() :: Schema.t()
@spec float(keyword()) :: Schema.t()
@spec float(default :: any()) :: Schema.t()
def float()
def float(opts) when is_list(opts)
def float(default)
# opts: min: number, max: number

@spec boolean() :: Schema.t()
@spec boolean(default :: boolean()) :: Schema.t()
def boolean()
def boolean(default)

@spec decimal() :: Schema.t()
@spec decimal(keyword()) :: Schema.t()
@spec decimal(default :: any()) :: Schema.t()
def decimal()
def decimal(opts) when is_list(opts)
def decimal(default)
# opts: min: number, max: number

@spec date() :: Schema.t()
@spec date(default :: Date.t()) :: Schema.t()
def date()
def date(default)

@spec datetime() :: Schema.t()
@spec datetime(default :: DateTime.t() | NaiveDateTime.t()) :: Schema.t()
def datetime()
def datetime(default)

@spec atom() :: Schema.t()
@spec atom(default :: atom()) :: Schema.t()
def atom()
def atom(default)
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
