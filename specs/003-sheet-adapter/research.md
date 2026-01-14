# Research: Sheet Adapter

**Date**: 2026-01-14  
**Feature**: `003-sheet-adapter`  

## Goal

Select dependencies and a design approach for implementing a tabular "Sheet adapter" supporting CSV and XLSX, with streaming, consistent errors, and parity with legacy `old/` behaviors.

## Repo Reality Check

### Legacy capabilities (source of truth)

The legacy implementation in `old/` already models:
- Header detection by header text and/or fixed position
- Optional columns (skip when missing)
- Union schemas with match strategies (`first_match`, `exact_one`)
- Row range filtering and row-numbered errors

Relevant legacy modules:
- `old/data_schema/sheet_schema.ex` (SheetSchema builder API)
- `old/data_schema/sheet_schema/parser.ex` (pipeline: header → resolve → range → parse rows)
- `old/data_schema/adapters/tabular.ex` (row parsing with row-numbered errors)
- `old/data_schema/parse_error.ex` (error type includes optional `row`)

### Current codebase status

- The repo contains `Raggio.Schema` and `Raggio.Syntax` implementations.
- There is no `RaggioTabular` implementation under `lib/` today; the `examples/raggio_tabular/*` scripts reference `RaggioTabular.*` modules as a future/demo API.

## Decisions

### Decision 1: CSV parsing library

**Decision**: Use `nimble_csv`.

**Rationale**:
- High performance and common Elixir choice.
- Strong streaming story (`parse_stream/1`) for large files.
- RFC4180-compatible parsing via built-in parser modules.

**Alternatives considered**:
- `CSV` (beatrichartz/csv): richer header/validation ergonomics, built-in BOM trimming.

**Notes / pitfalls**:
- `nimble_csv` returns binary references; must `:binary.copy/1` if values need to outlive the original binary.
- BOM trimming for streams needs to happen at stream source (or explicit handling).

### Decision 2: XLSX reader library

**Decision**: Prefer `xlsx_reader` (pure Elixir) for v1.

**Rationale**:
- Streaming support for large workbooks.
- Can expose either values-only or cell structs including raw formulas when needed.
- Avoids adding native dependencies (NIF) to a foundational library.

**Alternatives considered**:
- `spreadsheet` (Rust/Calamine): best performance + memory, supports more formats (incl. `.xls`, `.ods`), but introduces NIF/native dependency.
- `xlsxir`: older but stable, ETS-heavy, last major updates older.

**Tradeoff**:
- If `xlsx_reader` performance is insufficient for large real-world files, switch to `spreadsheet` later behind the same adapter interface.

### Decision 3: Error model for tabular parsing

**Decision**: Introduce a tabular-specific error struct (e.g., `Raggio.Tabular.Error`) that includes:
- `row` (original row number in source)
- `path` (field name / column)
- `message`
- `value`
- optional `constraint`

**Rationale**:
- `Raggio.Schema.Error` does not include `row`, but row context is a core requirement (FR-012).
- Keep a stable, explicit shape for consumers.

**Alternatives considered**:
- Extending `Raggio.Schema.Error` to include `row`: would couple schema errors to a tabular concern.

### Decision 4: API surface / extension point

**Decision**: Implement a behaviour-based adapter interface for sources:
- `Raggio.Tabular.Adapter` behaviour with CSV and XLSX implementations.
- Public entry point `Raggio.Tabular` delegates to configured adapters.

**Rationale**:
- Matches existing adapter pattern used in `Raggio.BigQuery`.
- Satisfies FR-004 (future formats) while keeping format-agnostic API.

**Alternatives considered**:
- Single monolithic parser with format detection inside: harder to extend/test.

## Open Questions (resolved)

- TSV support: treat as delimiter variant of CSV, not a separate adapter (matches spec FR-003).
- Formula handling: v1 reads cached/computed values; raw formulas may be optionally surfaced where available.

## Implementation Implications

- Add new dependency: `nimble_csv`.
- Add new dependency: `xlsx_reader` (initial choice).
- Implement adapters so swapping XLSX implementation later is a config change, not a public API break.
