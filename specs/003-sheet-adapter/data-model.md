# Data Model: Sheet Adapter (Parser-Agnostic)

**Feature**: `003-sheet-adapter`  
**Date**: 2026-01-14 (Updated for parser-agnostic architecture)

## Overview

This feature introduces a tabular ingestion subsystem that reads sheet-like files (CSV, XLSX) and parses them into typed rows using a declarative SheetSchema. The library defines behaviours; **users provide parser implementations** using their preferred libraries.

## Entity Diagram

```
┌─────────────────┐     implements     ┌──────────────────┐
│  User's Parser  │◄──────────────────►│  Parser Behaviour│
│  (CSV/XLSX/...) │                    │  (2 callbacks)   │
└────────┬────────┘                    └──────────────────┘
         │
         │ provides rows
         ▼
┌─────────────────┐     references     ┌──────────────────┐
│   Row Stream    │───────────────────►│   SheetSchema    │
│ {row_num, cells}│                    │   (column defs)  │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │ parsed by                            │ contains
         ▼                                      ▼
┌─────────────────┐                    ┌──────────────────┐
│   RowParser     │                    │   ColumnDef      │
│ (validation)    │                    │   (field spec)   │
└────────┬────────┘                    └──────────────────┘
         │
         │ produces
         ▼
┌─────────────────┐
│     Result      │
│ valid + invalid │
│    + errors     │
└─────────────────┘
```

## Entities

### 1) Parser (Behaviour) - NEW

**Module**: `Raggio.Tabular.Parser`

**Represents**: User-implemented behaviour for reading tabular files.

**Callbacks**:

| Callback | Signature | Returns |
|----------|-----------|---------|
| `stream_rows/2` | `stream_rows(source, opts)` | `{:ok, Stream.t({row_num, [cell]})}` or `{:error, reason}` |
| `sheet_names/1` | `sheet_names(source)` | `{:ok, [String.t()]}` or `{:error, reason}` |

**Key Rules**:
- Users MUST implement this behaviour with their preferred parsing library
- `stream_rows/2` MUST return `{row_number, cells}` tuples where `row_number` is 1-based
- `sheet_names/1` MUST return `["default"]` for single-sheet formats (CSV)
- Parsers SHOULD stream lazily for large file support

**Examples**: See `examples/tabular/csv_parser.ex` and `examples/tabular/xlsx_parser.ex`

---

### 2) Sheet Source

**Represents**: A user-provided input to parse.

**Key fields**:
- `path`: File path or source identifier
- `hints`: Optional parsing hints passed to parser (delimiter, encoding, sheet)

**Notes**:
- Source format is opaque to the library; the user's parser implementation handles format-specific concerns

---

### 3) SheetSchema

**Module**: `Raggio.Tabular.SheetSchema`

**Represents**: Declarative mapping from tabular columns to typed fields.

**Key fields**:
- `columns`: Ordered list of Column Definitions
- `header_mode`: Whether header detection is enabled (`:auto | :present | :absent`)
- `header_variants`: Optional header synonym mapping `%{String.t() => atom()}`
- `row_filters`: Optional skipping/range rules
- `transforms`: Value normalization transforms to apply

**Validation Rules**:
- At least one column must be defined
- Column field names must be unique atoms
- Header variants must map to existing field names

---

### 4) Column Definition

**Module**: `Raggio.Tabular.ColumnDef`

**Represents**: A single output field mapping.

**Key fields**:
- `field_name`: Canonical output field identifier (atom)
- `header`: Optional expected header text (String)
- `at`: Optional fixed column position (0-based integer)
- `type_schema`: The Raggio.Schema used to parse/validate the cell value
- `required`: Whether column must exist (boolean, default: true)

**Resolution Order**:
1. If `at` specified, use fixed position
2. If `header` specified, match by header text (case-insensitive)
3. Check `header_variants` for alternative spellings
4. If not found and `required: false`, skip column

---

### 5) Schema Union

**Module**: `Raggio.Tabular.Union`

**Represents**: Multiple SheetSchemas with a matching strategy.

**Key fields**:
- `schemas`: Ordered list of SheetSchemas
- `strategy`: `:first_match` or `:exact_one`

**Strategies**:
- `:first_match` - Use first schema whose required headers match
- `:exact_one` - Require exactly one schema to match; error if 0 or 2+

---

### 6) Parse Result

**Module**: `Raggio.Tabular.Result`

**Represents**: Output of a parse operation.

**Key fields**:
- `valid_rows`: List of typed row maps
- `invalid_rows`: List of Tabular.Error structs
- `row_count`: Total rows processed (excluding skipped blank rows)
- `matched_schema`: Which union schema matched (atom or nil)

---

### 7) Tabular Error

**Module**: `Raggio.Tabular.Error`

**Represents**: A row-specific parsing error.

**Key fields**:
- `row`: Original row number in source (1-based)
- `path`: Field name where error occurred (atom)
- `message`: Human-readable error message
- `value`: The original value that failed validation
- `constraint`: Optional constraint identifier (atom)

**Rules**:
- Must be actionable (help locate error in the input file)

---

### 8) Transform

**Module**: `Raggio.Tabular.Transform`

**Represents**: Value normalization functions applied before type validation.

**Available Transforms**:
| Transform | Effect |
|-----------|--------|
| `:trim` | Trim whitespace |
| `:strip_currency` | Remove currency symbols ($, €, etc.) |
| `:normalize_decimal` | Handle thousand separators |
| `:excel_date` | Convert Excel serial to date |
| `:float_to_int` | Convert "1.0" to "1" for IDs |

## State Transitions

### Parse Flow

```
Source + Parser Module + Schema
         │
         ▼
    ┌─────────┐
    │ INIT    │ (call parser.stream_rows/2)
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │ HEADER  │ (extract header row if header_mode != :absent)
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │ STREAM  │ (iterate rows, apply transforms, validate with schema)
    └────┬────┘
         │
         ├─── valid row ───► accumulate in Result.valid_rows
         │
         └─── invalid row ─► accumulate in Result.invalid_rows
         │
         ▼
    ┌─────────┐
    │ DONE    │ (finalize Result)
    └─────────┘
```

## Derived Constraints

- Parser implementations are provided by users, not bundled
- Row-numbered error reporting is mandatory across formats
- Parsing must support large files via streaming
- Format-specific concerns are isolated in user's parser implementation
