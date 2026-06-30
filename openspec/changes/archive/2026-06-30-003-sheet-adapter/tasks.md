# Tasks: Sheet Adapter (Parser-Agnostic)

## 1. Setup — Refactor to Parser-Agnostic

- [x] 1.1 Move `nimble_csv` dependency to `:dev` only in `mix.exs` (was production dep)
- [x] 1.2 Move `xlsx_reader` dependency to `:dev` only in `mix.exs` (was production dep)
- [x] 1.3 Create `examples/tabular/` directory for reference parser implementations
- [x] 1.4 Move `lib/raggio/tabular/adapters/csv.ex` to `examples/tabular/csv_parser.ex` (preserve as example)
- [x] 1.5 Move `lib/raggio/tabular/adapters/xlsx.ex` to `examples/tabular/xlsx_parser.ex` (preserve as example)
- [x] 1.6 Delete `lib/raggio/tabular/adapters/` directory after migration
- [x] 1.7 Delete `lib/raggio/tabular/registry.ex` (no longer needed with explicit parser selection)

## 2. Foundational — Core Behaviour & Types

- [x] 2.1 Create `Raggio.Tabular.Parser` behaviour in `lib/raggio/tabular/parser.ex` with callbacks `stream_rows/2`, `sheet_names/1`
- [x] 2.2 Add `@callback` typespec: `stream_rows(source, opts) :: {:ok, Enumerable.t({pos_integer(), [term()]})} | {:error, map()}`
- [x] 2.3 Add `@callback` typespec: `sheet_names(source) :: {:ok, [String.t()]} | {:error, map()}`
- [x] 2.4 Add module documentation to `parser.ex` explaining the behaviour contract and implementation requirements
- [x] 2.5 Rename existing parsing logic `lib/raggio/tabular/parser.ex` to `lib/raggio/tabular/row_parser.ex` to avoid conflict with the behaviour module
- [x] 2.6 Update all internal references from `Raggio.Tabular.Parser` (old) to `Raggio.Tabular.RowParser`
- [x] 2.7 Verify `Raggio.Tabular.Error` struct fields: `row`, `path`, `message`, `value`, `constraint`
- [x] 2.8 Verify `Raggio.Tabular.Result` struct fields: `valid_rows`, `invalid_rows`, `row_count`, `matched_schema`
- [x] 2.9 Verify `Raggio.Tabular.SheetSchema` struct fields: `columns`, `header_mode`, `header_variants`, `row_filters`, `transforms`
- [x] 2.10 Verify `Raggio.Tabular.ColumnDef` struct fields: `field_name`, `header`, `at`, `required`, `type_schema`

## 3. User Story 1 — Parse tabular files into typed data (P1)

- [x] 3.1 Update `Raggio.Tabular.parse/3` to REQUIRE the `parser:` option (no auto-detection)
- [x] 3.2 Return `{:error, %{type: :missing_parser}}` when the `parser:` option is not provided
- [x] 3.3 Update `Raggio.Tabular.list_sheets/2` to REQUIRE the `parser:` option
- [x] 3.4 Remove `parse_file/2` (without opts) — all calls must specify a parser
- [x] 3.5 Call `parser.stream_rows(source, opts)` from the provided parser module
- [x] 3.6 Call `parser.sheet_names(source)` from the provided parser module
- [x] 3.7 Pass the `sheet:` option through to the parser's `stream_rows/2`
- [x] 3.8 Wrap parser errors in a consistent format-error shape
- [x] 3.9 Update `row_parser.ex` to accept a stream from any Parser behaviour implementation
- [x] 3.10 Handle the `{row_number, cells}` tuple format from parsers in `row_parser.ex`
- [x] 3.11 Verify header detection (`:auto`, `:present`, `:absent`) works with behaviour-provided streams
- [x] 3.12 Verify row-numbered error accumulation uses original row numbers from the parser
- [x] 3.13 Update `examples/tabular/csv_parser.ex` to implement the `Raggio.Tabular.Parser` behaviour
- [x] 3.14 Implement `sheet_names/1` in the CSV example returning `{:ok, ["default"]}`
- [x] 3.15 Implement `stream_rows/2` in the CSV example using NimbleCSV with streaming
- [x] 3.16 Add delimiter option support (comma, tab, semicolon) to the CSV example
- [x] 3.17 Add error handling for file-not-found / read errors in the CSV example
- [x] 3.18 Update `examples/tabular/xlsx_parser.ex` to implement the `Raggio.Tabular.Parser` behaviour
- [x] 3.19 Implement `sheet_names/1` in the XLSX example using XlsxReader
- [x] 3.20 Implement `stream_rows/2` in the XLSX example using XlsxReader
- [x] 3.21 Add sheet selection support (by name via `sheet:` option) in the XLSX example
- [x] 3.22 Add error handling for file-not-found / invalid-format / sheet-not-found in the XLSX example
- [x] 3.23 Create `examples/tabular/README.md` with setup instructions (deps, implementing the behaviour)
- [x] 3.24 Add usage examples to the README showing explicit parser selection
- [x] 3.25 Verify actionable error messages for missing required headers (FR-013)
- [x] 3.26 Verify duplicate-header detection with an actionable error
- [x] 3.27 Verify blank-row skipping works with any parser output (FR-016)
- [x] 3.28 Verify ragged-row handling (pad short, ignore extra trailing) (FR-016)

## 4. User Story 2 — Multiple input formats and header variants (P2)

- [x] 4.1 Verify `with_header_variants/2` exists in `sheet_schema.ex` for header synonym configuration
- [x] 4.2 Verify header resolution checks variants when the primary header is not found (FR-007)
- [x] 4.3 Verify case-insensitive header matching in `row_parser.ex`
- [x] 4.4 Verify `Raggio.Tabular.Union` struct fields: `schemas`, `strategy`
- [x] 4.5 Verify `Union.new/2` creates union schemas
- [x] 4.6 Verify `:first_match` strategy in union matching (FR-008)
- [x] 4.7 Verify `:exact_one` strategy with ambiguous-match error (FR-008)
- [x] 4.8 Verify the matched schema variant is tracked in the parse result

## 5. User Story 3 — Row filtering and spreadsheet messiness (P2)

- [x] 5.1 Verify `row_filters` support in SheetSchema (`skip_rows`, `row_range`)
- [x] 5.2 Verify `skip_rows` skips leading N rows (FR-010)
- [x] 5.3 Verify `row_range` parses only the specified row range (FR-010)
- [x] 5.4 Verify row numbers in errors align to original file positions after filtering
- [x] 5.5 Verify `Raggio.Tabular.Transform` module exists (FR-018)
- [x] 5.6 Verify currency-symbol stripping transform
- [x] 5.7 Verify thousand-separator removal transform
- [x] 5.8 Verify whitespace-trimming transform
- [x] 5.9 Verify Excel-date-serial to Date conversion transform
- [x] 5.10 Verify float-to-integer ID coercion transform
- [x] 5.11 Verify transform-pipeline integration with `row_parser.ex`

## 6. Polish & Cross-Cutting Concerns

- [x] 6.1 Verify streaming behavior with the example CSV parser for a 100k-row file within memory bounds (SC-003)
- [x] 6.2 Verify streaming behavior with the example XLSX parser for a 100k-row file within memory bounds (SC-003)
- [x] 6.3 Review `old/data_schema/sheet_schema.ex` and validate API parity (FR-020)
- [x] 6.4 Review `old/data_schema/sheet_schema/parser.ex` and validate behavior parity (FR-020)
- [x] 6.5 Review `old/data_schema/adapters/tabular.ex` and validate error-reporting parity (FR-020)
- [x] 6.6 Update module docs in `tabular.ex` for the parser-agnostic architecture and `parser:` requirement
- [x] 6.7 Update module docs in `parser.ex` with the behaviour implementation guide
- [x] 6.8 Update module docs in `sheet_schema.ex` with schema-definition examples
- [x] 6.9 Confirm typespecs on all public functions in `lib/raggio/tabular/`
- [x] 6.10 Update example script `examples/raggio_tabular/csv_parsing/basic_csv.exs` to use the explicit parser option
- [x] 6.11 Update remaining example scripts in `examples/raggio_tabular/` to use the explicit parser option
- [x] 6.12 Validate quickstart scenarios work with the new API (quickstart corrected)
- [x] 6.13 Remove dead-code references to the old Adapter behaviour
- [x] 6.14 Confirm no test files required (tests not explicitly requested in spec)
- [x] 6.15 Run `mix compile --warnings-as-errors` to verify no compilation warnings
