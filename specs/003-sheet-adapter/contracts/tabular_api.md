# Contract: Raggio.Tabular Public API

**Feature**: `003-sheet-adapter`  
**Status**: Draft (Updated for parser-agnostic architecture)

> This repository is a library (not a service). Contracts are expressed as module APIs and data shapes rather than HTTP endpoints.

## `Raggio.Tabular`

### `parse/3` (primary entry point)

Parse a tabular source into typed rows using a schema.

**Signature**: 
```elixir
parse(source, schema_or_union, opts) :: {:ok, Result.t()} | {:error, map()}
```

**Parameters**:
- `source`: Source to parse (typically a file path, passed to parser)
- `schema_or_union`: A SheetSchema or Union of SheetSchemas
- `opts`: **Required** options including:
  - `parser: module()` - **REQUIRED** - Parser module implementing `Raggio.Tabular.Parser`

**Optional Options**:
- `sheet: String.t()` - Sheet name for multi-sheet sources (default: first sheet)
- `header: :auto | :present | :absent` - Header handling (default: `:auto`)
- Additional options passed through to parser's `stream_rows/2`

**Returns**:
- `{:ok, result}` on successful parse (even if some rows are invalid)
- `{:error, reason}` if the input cannot be read or structurally validated

**Example**:
```elixir
Raggio.Tabular.parse("data.csv", my_schema, parser: MyApp.CSVParser)

Raggio.Tabular.parse("workbook.xlsx", my_schema,
  parser: MyApp.XLSXParser,
  sheet: "Sheet2"
)
```

**Notes**:
- Partial-row failures are represented in `result.invalid_rows`, not as an overall `{:error, ...}`
- The `parser:` option is **required** - there are no bundled parsers

---

### `list_sheets/2`

List available sheets for a source.

**Signature**: 
```elixir
list_sheets(source, opts) :: {:ok, [String.t()]} | {:error, map()}
```

**Parameters**:
- `source`: Source to inspect
- `opts`:
  - `parser: module()` - **REQUIRED** - Parser module

**Returns**:
- `{:ok, sheet_names}` - List of sheet names
- `{:error, reason}` - If source cannot be read

**Example**:
```elixir
{:ok, sheets} = Raggio.Tabular.list_sheets("workbook.xlsx", parser: MyApp.XLSXParser)
# => {:ok, ["Sheet1", "Data", "Summary"]}

{:ok, sheets} = Raggio.Tabular.list_sheets("data.csv", parser: MyApp.CSVParser)
# => {:ok, ["default"]}
```

---

## `Raggio.Tabular.SheetSchema`

### `new/1`

Create a new schema with column definitions.

**Signature**: 
```elixir
new(columns) :: SheetSchema.t()
```

**Parameters**:
- `columns`: Ordered list of column definitions

**Example**:
```elixir
alias Raggio.Schema
alias Raggio.Tabular.{SheetSchema, ColumnDef}

schema = SheetSchema.new([
  ColumnDef.new(:id, header: "ID", type: Schema.integer(min: 1)),
  ColumnDef.new(:name, header: "Name", type: Schema.string(min: 1)),
  ColumnDef.new(:email, header: "Email", type: Schema.string(), required: false)
])
```

---

### `with_header_variants/2`

Specify header synonyms that map to canonical fields.

**Signature**: 
```elixir
with_header_variants(schema, variants) :: SheetSchema.t()
```

**Parameters**:
- `schema`: Existing SheetSchema
- `variants`: Map of header string to field name atom

**Example**:
```elixir
schema
|> SheetSchema.with_header_variants(%{
  "User ID" => :id,
  "user_id" => :id,
  "Full Name" => :name
})
```

---

### `with_transforms/2`

Add value transforms applied before type validation.

**Signature**: 
```elixir
with_transforms(schema, transforms) :: SheetSchema.t()
```

**Parameters**:
- `transforms`: List of transform atoms (`:trim`, `:strip_currency`, etc.)

---

### `with_row_filters/2`

Configure row filtering (skip rows, row range).

**Signature**: 
```elixir
with_row_filters(schema, filters) :: SheetSchema.t()
```

**Parameters**:
- `filters`: Map with optional keys:
  - `skip_rows: non_neg_integer()` - Skip first N rows
  - `row_range: Range.t()` - Only process rows in range

---

## `Raggio.Tabular.Union`

### `new/2`

Create a union of schemas with matching strategy.

**Signature**: 
```elixir
new(schemas, opts \\ []) :: Union.t()
```

**Parameters**:
- `schemas`: List of SheetSchema structs
- `opts`:
  - `strategy: :first_match | :exact_one` (default: `:first_match`)

**Example**:
```elixir
union = Union.new([schema_v1, schema_v2], strategy: :exact_one)
```

---

## Error Shapes

### Format errors (`{:error, reason}`)

Returned when source cannot be parsed at all:

```elixir
{:error, %{type: :file_not_found, message: "..."}}
{:error, %{type: :sheet_not_found, message: "...", details: %{requested: "Foo", available: [...]}}}
{:error, %{type: :missing_headers, message: "...", missing: [...], required: [...]}}
{:error, %{type: :no_match, message: "No schema matched the headers"}}
{:error, %{type: :ambiguous_match, message: "Multiple schemas matched", count: 2}}
```

### Row errors (`result.invalid_rows`)

Each error is a `Raggio.Tabular.Error` struct:

```elixir
%Raggio.Tabular.Error{
  row: 42,           # Original row number (1-based)
  path: :email,      # Field name
  message: "invalid email format",
  value: "not-an-email",
  constraint: :pattern
}
```

---

## Deterministic Defaults

- **Blank rows**: Skipped entirely (not counted in result)
- **Ragged rows**: Short rows padded with empty strings; extra trailing cells ignored
- **Header matching**: Case-insensitive
- **Row numbering**: Always 1-based, always from original file
