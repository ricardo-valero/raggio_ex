# Quickstart: Sheet Adapter

This quickstart shows the intended usage of the Sheet Adapter feature as a developer-facing library API.

## 1) Define a schema

Define a SheetSchema that maps columns to typed fields.

## 2) Parse a CSV file

Parse a CSV file path using the schema and inspect valid vs invalid rows.

## 3) Parse an XLSX file

Parse an XLSX workbook (default first worksheet), or select a worksheet by name/index.

## 4) Handle errors

- Structural/format errors are returned as `{:error, reason}`.
- Row-level errors are accumulated in `result.invalid_rows` and include row numbers.

## 5) Large files

Use the streaming-based API so parsing does not require loading the entire file into memory.

## Next steps

Proceed to `specs/003-sheet-adapter/contracts/tabular_api.md` for the full public API contract.