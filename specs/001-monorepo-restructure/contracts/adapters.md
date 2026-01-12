# Adapter API Contracts

**Feature**: Import/Export Adapters for Raggio.Schema  
**Version**: 1.0.0

---

## BigQuery Exporter

**Module**: `Raggio.Schema.Exporter.BigQuery`

### `to_ddl/2`

Converts a Raggio.Schema to BigQuery Standard SQL DDL.

**Signature**: `to_ddl(schema :: Schema.t(), table_name :: String.t()) :: String.t()`

**Parameters**:
- `schema` - Schema to export
- `table_name` - Table name (supports `project.dataset.table` format)

**Returns**: BigQuery DDL string

**Example**:
```elixir
schema = Schema.struct([
  id: Schema.integer() |> Schema.positive(),
  email: Schema.string() |> Schema.email()
])

BigQuery.to_ddl(schema, "users")
# => """
# CREATE TABLE `users` (
#   id INT64 NOT NULL,
#   email STRING NOT NULL
# )
# """
```

### `to_ddl/3`

Converts schema with options.

**Signature**: `to_ddl(schema, table_name, opts :: keyword()) :: String.t()`

**Options**:
- `partition_by: string()` - PARTITION BY clause
- `cluster_by: [string()]` - CLUSTER BY fields
- `description: string()` - Table description

**Example**:
```elixir
BigQuery.to_ddl(schema, "users",
  partition_by: "DATE(created_at)",
  cluster_by: ["status", "id"]
)
```

### Type Mapping

| Raggio Type | BigQuery Type |
|-------------|---------------|
| `:string` | `STRING` |
| `:integer` | `INT64` |
| `:float` | `FLOAT64` |
| `:boolean` | `BOOL` |
| `:decimal` | `NUMERIC` |
| `:datetime` | `DATETIME` |
| `:date` | `DATE` |
| `:time` | `TIME` |
| `{:list, inner}` | `ARRAY<type>` |
| `{:struct, fields}` | `STRUCT<...>` |

### Constraint Handling

**Supported**:
- `required: true` → `NOT NULL`
- `default: value` → `DEFAULT value`

**Not Supported** (added as comments):
- `min/max`
- `pattern`
- `email` format

---

## SheetSchema Importer

**Module**: `Raggio.Schema.Importer.SheetSchema`

### `from_csv/1`

Imports schema from CSV file.

**Signature**: `from_csv(path :: Path.t()) :: {:ok, String.t()} | {:error, term()}`

**Parameters**:
- `path` - Path to CSV file

**Returns**:
- `{:ok, generated_code}` - Elixir code string
- `{:error, reason}` - Parse error

**Example**:
```elixir
{:ok, code} = SheetSchema.from_csv("schema.csv")
IO.puts(code)
# => """
# Schema.struct([
#   email: Schema.string() |> Schema.email() |> Schema.max_length(255),
#   age: Schema.integer() |> Schema.min(13) |> Schema.max(120) |> Schema.optional()
# ])
# """
```

### `from_csv/2`

Imports with options.

**Signature**: `from_csv(path, opts :: keyword()) :: {:ok, String.t()} | {:error, term()}`

**Options**:
- `format: boolean()` - Format generated code (default: true)
- `module_name: string()` - Wrap in module definition

### `from_url/1`

Imports schema from Google Sheets URL.

**Signature**: `from_url(url :: String.t()) :: {:ok, String.t()} | {:error, term()}`

**Parameters**:
- `url` - Google Sheets sharing URL

**Example**:
```elixir
SheetSchema.from_url("https://docs.google.com/spreadsheets/d/abc123/edit")
```

### `from_url/2`

Imports from URL with options.

**Signature**: `from_url(url, opts :: keyword()) :: {:ok, String.t()} | {:error, term()}`

**Options**:
- `sheet_name: string()` - Specific sheet to import (default: first sheet)
- `cache_ttl: integer()` - Cache duration in seconds (default: 300)
- All options from `from_csv/2`

### `validate/1`

Validates SheetSchema format without generating code.

**Signature**: `validate(path_or_url :: String.t()) :: :ok | {:error, [validation_error()]}`

**Returns**:
- `:ok` - Valid format
- `{:error, errors}` - List of validation errors with row numbers

**Example**:
```elixir
case SheetSchema.validate("schema.csv") do
  :ok -> 
    IO.puts("Valid schema format")
  {:error, errors} ->
    Enum.each(errors, fn {row, message} ->
      IO.puts("Row #{row}: #{message}")
    end)
end
```

### CSV Column Format

Required columns:
- `field_name` - Field identifier
- `type` - Type expression

Optional columns:
- `required` - Boolean (true/false/yes/no)
- `constraints` - Pipe-separated constraints
- `description` - Documentation
- `example` - Example value
- `default` - Default value
- `parent_path` - Nesting path (dot notation)

### Constraint Parsing

Constraints are parsed from pipe-separated function calls:

```
min_length(3) | max_length(50) | pattern(^[a-z]+$)
```

Becomes:
```elixir
Schema.string()
|> Schema.min_length(3)
|> Schema.max_length(50)
|> Schema.pattern(~r/^[a-z]+$/)
```

### Type Parsing

Supported type expressions:
- Primitives: `string`, `integer`, `float`, `boolean`, `date`, `datetime`
- Complex: `list(type)`, `tuple(type1, type2)`, `union(type1, type2)`
- Modifiers: `nullable(type)`

### Nesting via parent_path

Fields with `parent_path` are grouped into nested structs:

| field_name | type | parent_path |
|------------|------|-------------|
| street | string | address |
| city | string | address |
| lat | float | address.geo |
| lng | float | address.geo |

Generates:
```elixir
Schema.struct([
  address: Schema.struct([
    street: Schema.string(),
    city: Schema.string(),
    geo: Schema.struct([
      lat: Schema.float(),
      lng: Schema.float()
    ])
  ])
])
```

---

## Error Handling

Both adapters follow consistent error patterns:

**Parse Errors**:
```elixir
{:error, %{
  type: :parse_error,
  row: 5,
  column: "type",
  message: "Unknown type: strin (did you mean 'string'?)",
  value: "strin"
}}
```

**Validation Errors**:
```elixir
{:error, %{
  type: :validation_error,
  field: "email",
  message: "Circular reference detected",
  path: [:user, :profile, :user]
}}
```

**Format Errors**:
```elixir
{:error, %{
  type: :format_error,
  message: "Missing required column: field_name",
  found_columns: ["name", "type"]
}}
```

---

## Type Specifications

```elixir
# BigQuery Exporter
@type ddl_option :: 
  {:partition_by, String.t()} |
  {:cluster_by, [String.t()]} |
  {:description, String.t()}

@type ddl_result :: String.t()

# SheetSchema Importer
@type import_option ::
  {:format, boolean()} |
  {:module_name, String.t()} |
  {:sheet_name, String.t()} |
  {:cache_ttl, non_neg_integer()}

@type import_result :: {:ok, String.t()} | {:error, term()}

@type validation_error :: {row :: non_neg_integer(), message :: String.t()}
```

---

*Adapter API contracts complete.*
