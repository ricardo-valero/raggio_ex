# Contract: Tabular Adapter Interface

**Feature**: `003-sheet-adapter`

## Purpose

Define the adapter boundary that isolates file-format specific reading (CSV/XLSX) from schema-based row parsing.

## `Raggio.Tabular.Adapter` (behaviour)

### `sniff/1`

Determine if this adapter can handle a given source.

**Signature**: `sniff(source) :: :ok | :no`

---

### `list_sheets/2`

List available sheets for a source.

**Signature**: `list_sheets(source, opts) :: {:ok, [sheet_info]} | {:error, reason}`

**Notes**:
- CSV adapters return a single synthetic sheet (e.g., name "Sheet 1" or "CSV").

---

### `stream_rows/2`

Stream data rows as `{row_number, row_cells}`.

**Signature**: `stream_rows(source, opts) :: {:ok, row_stream} | {:error, reason}`

**Rules**:
- Must be streaming (must not require loading all rows into memory).
- Must align row numbering to the original file.
- Must apply deterministic blank/ragged row behavior.

## `sheet_info`

Minimum fields:
- `name`: sheet name
- `index`: sheet index

## `source`

Supported sources for v1:
- file paths
- in-memory strings/binaries for CSV (optional scope)

## Errors

`reason` MUST be a structured map with at least:
- `type`
- `message`

It MAY include:
- `details` (map)
