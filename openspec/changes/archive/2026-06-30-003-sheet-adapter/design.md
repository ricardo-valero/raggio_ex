# Design: Sheet Adapter (Parser-Agnostic)

## Context

Raggio is an Elixir library (~> 1.14) for parsing and validating data against
declarative schemas. A legacy implementation in `old/data_schema/` modeled
tabular ingestion: header detection by text and/or fixed position, optional
columns, union schemas with match strategies, row-range filtering, and
row-numbered errors. An interim `lib/raggio/tabular/` implementation bundled
concrete CSV/XLSX adapters built on `nimble_csv` and `xlsx_reader`.

This change reshapes that subsystem to be parser-agnostic: the library defines a
behaviour contract, and users supply parser implementations using whatever
parsing libraries they prefer. The goal is to keep zero parsing dependencies in
production while preserving full behavioral parity with the legacy pipeline. It
is a library, not a service, so contracts are module APIs and data shapes, not
HTTP endpoints.

## Goals / Non-Goals

**Goals:**
- Provide one consistent API to parse CSV and XLSX (and TSV as a CSV variant)
  into typed rows using a declarative `SheetSchema`.
- Cleanly separate valid rows from invalid rows, with row-numbered, field-level,
  actionable errors aligned to the original file.
- Keep the core library free of bundled parsing libraries; users bring their own
  parser via a behaviour.
- Support large inputs via streaming (target: 100k rows in <10s without loading
  the whole file into memory).
- Maintain legacy parity for header detection, optional columns, header
  variants, union matching, row filtering, and row-numbered errors.

**Non-Goals:**
- Bundling `nimble_csv`, `xlsx_reader`, or any parsing library as a production
  dependency.
- Implicit parser auto-detection, config-based registries, or protocol dispatch
  on source type.
- Live integrations (e.g., reading a remote Google Sheet without exporting a
  file).
- Niche formats (fixed-width) and legacy `.xls` support absent demonstrated
  demand.
- Shipping the reference CSV/XLSX parsers as part of the library (they live in
  `examples/`).

## Decisions

### Decision 1: Bring-your-own parser (no bundled libraries)
The core library defines behaviours and ships no parsing dependencies.
`nimble_csv` and `xlsx_reader` become `:dev`-only, used solely to run examples
and any local checks. Rationale: maximum flexibility, minimal footprint, no
version conflicts with user deps, and users can optimize for their case.
Alternatives rejected: bundled defaults with override (still couples to specific
libs, adds complexity); separate packages `raggio_csv`/`raggio_xlsx`
(maintenance and versioning burden).

### Decision 2: Parser behaviour contract — two streaming callbacks
`Raggio.Tabular.Parser` defines exactly two callbacks:
- `stream_rows(source, opts) :: {:ok, Enumerable.t({pos_integer(), [term()]})} | {:error, map()}`
- `sheet_names(source) :: {:ok, [String.t()]} | {:error, map()}`

Streaming-first satisfies large-file processing; `sheet_names/1` supports
multi-sheet workbooks. Single-sheet formats (CSV) return `{:ok, ["default"]}`.
Alternatives rejected: a single `parse/2` returning a full list (no streaming);
extra callbacks like `sniff/1` / `validate_source/1` (over-engineered for
initial scope).

### Decision 3: Explicit parser selection at call site
The parser module is passed explicitly via the `parser:` option, e.g.
`Tabular.parse(source, schema, parser: MyApp.CSVParser)`. Calls without a
`parser:` return `{:error, %{type: :missing_parser}}`. Rationale: explicit over
implicit, easy to trace and test, idiomatic Elixir (modules as arguments), no
global state. The old `registry.ex` and `parse_file/2` (no-opts) are removed.

### Decision 4: Column definitions and resolution order
`ColumnDef` maps one output field: `field_name` (atom), optional `header`
(string), optional `at` (0-based fixed position), `type_schema` (a
`Raggio.Schema`), and `required` (default true). Resolution order: (1) fixed
position `at` if given; (2) header text match (case-insensitive); (3) header
variants for alternative spellings; (4) if not found and `required: false`, skip
the column. This mirrors legacy behavior of resolving by header and/or position.

### Decision 5: Worksheet selection
Multi-sheet sources are addressed by sheet name via the `sheet:` option, passed
through to the parser's `stream_rows/2`; `list_sheets/2` exposes available
names. Selection works by name (and by index where the parser supports it).
Single-sheet formats expose the synthetic `"default"` sheet. Requesting an
unknown sheet yields `{:error, %{type: :sheet_not_found, ...}}` listing
available sheets.

### Decision 6: Row parsing pipeline
`RowParser` (renamed from the old `parser.ex` to free the `Parser` name for the
behaviour) consumes the `{row_number, cells}` stream from any parser and runs:
header extraction (modes `:auto | :present | :absent`) → column resolution →
row-range/skip filtering → per-cell transforms → schema validation →
accumulation into a `Result`. Deterministic defaults: completely blank rows are
skipped (not counted); short rows are padded with empty strings; extra trailing
cells are ignored unless configured to error; header matching is
case-insensitive; row numbers are always 1-based and always from the original
file, even after filtering.

### Decision 7: Value transforms (opt-in)
`Raggio.Tabular.Transform` provides spreadsheet-oriented normalizations applied
before type validation, configured per schema and opt-in: `:trim`,
`:strip_currency`, `:normalize_decimal` (thousand separators), `:excel_date`
(serial → Date), and `:float_to_int` (e.g., "1.0" → "1" for IDs). This preserves
legacy normalization behavior without silently mutating values.

### Decision 8: Union handling and match strategies
`Raggio.Tabular.Union` holds an ordered list of `schemas` plus a `strategy`:
- `:first_match` — use the first schema whose required headers match.
- `:exact_one` — require exactly one matching schema; error on 0 or 2+
  (`:no_match` / `:ambiguous_match`).
The matched variant is tracked in `Result.matched_schema`.

### Decision 9: Error model (retained)
Two error surfaces. Format errors return `{:error, map}` with at least `type`
and `message` (e.g., `:file_not_found`, `:invalid_format`, `:sheet_not_found`,
`:missing_headers`, `:no_match`, `:ambiguous_match`, `:missing_parser`). Row
errors are `Raggio.Tabular.Error` structs with `row`, `path`, `message`,
`value`, and optional `constraint`, collected in `result.invalid_rows`. Parser
errors are wrapped into the consistent format-error shape by the entry point.

## Risks / Trade-offs

- **Breaking change for existing users.** Auto-detection is gone; every call now
  requires a `parser:` option, and users must add a parsing library and either
  copy an example parser or write their own. Mitigation: runnable examples in
  `examples/tabular/` and migration notes.
- **Implementation quality pushed to users.** Streaming, encoding, and
  blank/ragged-row handling now live in user-supplied parsers; a non-streaming
  implementation can break the large-file performance goal. Mitigation: the
  contract documents MUST-stream / 1-based row-number rules, and examples
  demonstrate correct streaming wrappers.
- **Parity verification deferred.** The legacy-parity and large-file performance
  validation tasks (Phase 6: T065–T069) were left unchecked at archive time; no
  automated test suite was requested in the source spec, so parity rests on
  manual review and the example-based integration checks.
- **Locale/encoding ambiguity.** Date and decimal-separator interpretation and
  character encoding are the parser's responsibility; inconsistent handling
  across user parsers could surface differently. Mitigation: documented
  expectations and opt-in transforms for normalization.
