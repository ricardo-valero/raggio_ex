# Data Model: Sheet Adapter

**Feature**: `003-sheet-adapter`  
**Date**: 2026-01-14  

## Overview

This feature introduces a tabular ingestion subsystem that reads sheet-like files (CSV, XLSX) and parses them into typed rows using a declarative SheetSchema, returning both valid rows and row-numbered errors.

## Entities

### 1) Sheet Source

**Represents**: A user-provided input to parse.

**Key fields**:
- `source_type`: Identifies the kind of source (file path vs in-memory content)
- `location`: The file path or other identifier
- `hints`: Optional parsing hints (delimiter, encoding, worksheet selector)

**Notes**:
- A Sheet Source must be sufficient to open/stream data without loading the full dataset into memory.

---

### 2) Workbook

**Represents**: A multi-sheet container (e.g., XLSX).

**Key fields**:
- `sheets`: Ordered list of worksheet identifiers (names and indices)
- `metadata`: Optional metadata (visibility, row/column stats if discoverable)

**Relationships**:
- Workbook contains one or more Worksheets.

---

### 3) Worksheet Selector

**Represents**: How the user selects which worksheet to parse.

**Key fields**:
- `by_name`: String name (case-insensitive match)
- `by_index`: 0-based or 1-based index (must be specified clearly in contracts)

**Rules**:
- If selector does not match any sheet, parsing fails with a clear, actionable error.

---

### 4) Row

**Represents**: A single record from a tabular file.

**Key fields**:
- `row_number`: The original row number in the file (1-based)
- `cells`: Ordered list of cell values (raw)

**Rules**:
- Completely blank rows are skipped by default.
- Ragged rows are handled deterministically (see spec FR-016).

---

### 5) SheetSchema

**Represents**: Declarative mapping from tabular columns to typed fields.

**Key fields**:
- `columns`: Set of Column Definitions
- `header_mode`: Whether header detection is enabled
- `header_variants`: Optional header synonym mapping
- `row_filters`: Optional skipping/range rules

**Relationships**:
- SheetSchema is used by the parser to map a Row into a typed output map.

---

### 6) Column Definition

**Represents**: A single output field mapping.

**Key fields**:
- `field_name`: Canonical output field identifier
- `header`: Optional expected header text
- `at`: Optional fixed column position
- `required`: Required vs optional column
- `type_schema`: The schema used to parse the cell value

**Rules**:
- Must specify at least one of header or position.
- Duplicate headers must be disambiguated by position.

---

### 7) Schema Union

**Represents**: Multiple SheetSchemas with a matching strategy.

**Key fields**:
- `schemas`: List of SheetSchemas
- `strategy`: Matching strategy

**Rules**:
- Strategy can allow first match or require exactly one match.

---

### 8) Parse Result

**Represents**: Output of a parse operation.

**Key fields**:
- `valid_rows`: List of typed rows
- `invalid_rows`: List of row-numbered errors
- `total_rows`: Count of processed data rows
- `matched_schema`: Which schema variant matched (if union)
- `metadata`: Optional parse metadata (sheet name, delimiter, etc.)

---

### 9) Tabular Error

**Represents**: A row-specific parsing error.

**Key fields**:
- `row`: Original row number
- `path`: Field name or column identifier
- `message`: Human-readable message
- `value`: The offending value
- `constraint`: Optional constraint identifier

**Rules**:
- Must be actionable (help locate error in the input file).

## Derived Constraints

- Row-numbered error reporting is mandatory across formats.
- Parsing must support large files via streaming.
- Format-specific concerns are isolated behind an adapter boundary.
