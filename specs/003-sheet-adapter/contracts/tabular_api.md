# Contract: Raggio.Tabular Public API

**Feature**: `003-sheet-adapter`  
**Status**: Draft  

> This repository is a library (not a service). Contracts are expressed as module APIs and data shapes rather than HTTP endpoints.

## `Raggio.Tabular`

### `parse_file/2`

Parse a tabular file into typed rows using a schema.

**Signature**: `parse_file(path, schema_or_union) :: {:ok, result} | {:error, reason}`

**Parameters**:
- `path`: Path to a CSV or XLSX file
- `schema_or_union`: A SheetSchema or union of SheetSchemas

**Returns**:
- `{:ok, result}` on successful parse (even if some rows are invalid)
- `{:error, reason}` if the input cannot be read or structurally validated (e.g., unknown worksheet, malformed CSV)

**Notes**:
- Partial-row failures are represented in `result.invalid_rows`, not as an overall `{:error, ...}`.

---

### `parse_file/3`

Parse with options.

**Signature**: `parse_file(path, schema_or_union, opts) :: {:ok, result} | {:error, reason}`

**Options**:
- `format`: Explicit format override (`:csv` | `:xlsx`) (optional)
- `delimiter`: Override delimiter for CSV/TSV (optional)
- `encoding`: Specify encoding (optional)
- `worksheet`: Worksheet selector for XLSX (optional)
  - `{:name, string}`
  - `{:index, integer}`
- `header`: Header handling (optional)
  - `:auto` (default)
  - `:present`
  - `:absent`

---

### `list_sheets/1`

List worksheets for a workbook.

**Signature**: `list_sheets(path) :: {:ok, [sheet_info]} | {:error, reason}`

**Returns**:
- `sheet_info`: at minimum includes `name` and `index`

---

## `Raggio.Tabular.SheetSchema`

### `define/1`

Define a schema mapping of field names to type schemas.

**Signature**: `define(fields) :: sheet_schema`

**Parameters**:
- `fields`: ordered list of `{field_name, type_schema}`

---

### `with_header_variants/2`

Specify header synonyms that map to canonical fields.

**Signature**: `with_header_variants(schema, variants) :: schema`

**Parameters**:
- `variants`: list of maps from header string to field identifier

---

### `union/2`

Create a union schema.

**Signature**: `union(schemas, opts) :: union_schema`

**Options**:
- `strategy`: `:first_match` (default) or `:exact_one`

---

## Error Shapes

### Format errors (`{:error, reason}`)

Examples:
- `{:error, %{type: :format_error, message: string, details: map}}`
- `{:error, %{type: :not_found, message: string}}` (e.g., unknown sheet)

### Row errors (`result.invalid_rows`)

Each row error MUST include:
- `row` (original row number)
- `path` (field name / column)
- `message`
- `value` (when available)

## Deterministic Defaults

- Blank rows are skipped.
- Ragged rows: short rows are padded with empty values; extra trailing cells are ignored unless configured to error.
