# Implementation Plan: Sheet Adapter

**Branch**: `003-sheet-adapter` | **Date**: 2026-01-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-sheet-adapter/spec.md`

## Summary

Implement a parser-agnostic tabular file adapter for Raggio. The library defines a `Raggio.Tabular.Parser` behaviour that users implement with their preferred parsing libraries (nimble_csv, xlsx_reader, etc.). No bundled parsing dependencies - explicit parser selection at call site. Maintains parity with legacy `old/` capabilities for header detection, union schemas, row filtering, and row-numbered errors.

## Technical Context

**Language/Version**: Elixir ~> 1.14 (per existing mix.exs)  
**Primary Dependencies**: `decimal`, `jason`, `telemetry` (existing); NO parsing libraries bundled  
**Storage**: N/A (library for data parsing, not storage)  
**Testing**: ExUnit (mix test)  
**Target Platform**: Elixir/OTP applications  
**Project Type**: Single library package  
**Performance Goals**: 100,000 rows in <10 seconds, streaming to avoid full memory load (SC-003)  
**Constraints**: <reasonable memory footprint for file size, parser-agnostic API  
**Scale/Scope**: Support typical business spreadsheet sizes (10k-1M rows)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`constitution.md`) contains template placeholders without specific principles defined. No mandatory gates apply. The implementation follows standard Elixir library conventions:

| Principle | Status | Notes |
|-----------|--------|-------|
| Library-First | PASS | Feature is a standalone library module |
| Test Coverage | PASS | ExUnit tests will be provided |
| Documentation | PASS | Hexdocs + example implementations |

## Project Structure

### Documentation (this feature)

```text
specs/003-sheet-adapter/
├── plan.md              # This file
├── research.md          # Phase 0 output (completed)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── parser-behaviour.ex
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
lib/raggio/tabular/
├── parser.ex            # NEW: Behaviour definition (@callback stream_rows/2, sheet_names/1)
├── row_parser.ex        # RENAMED: Parsing logic (was parser.ex)
├── sheet_schema.ex      # Unchanged
├── column_def.ex        # Unchanged
├── result.ex            # Unchanged
├── error.ex             # Unchanged
├── transform.ex         # Unchanged
├── union.ex             # Unchanged
├── source.ex            # Unchanged
├── sheet_info.ex        # Unchanged
├── worksheet_selector.ex # Unchanged
└── registry.ex          # MAY REMOVE: No longer needed with explicit parser selection

lib/raggio/tabular/adapters/  # TO BE REMOVED (moved to examples/)

examples/tabular/
├── csv_parser.ex        # Reference implementation using nimble_csv
├── xlsx_parser.ex       # Reference implementation using xlsx_reader
└── README.md            # Setup and usage guide

test/raggio/tabular/
├── parser_test.exs      # Behaviour compliance tests
├── row_parser_test.exs  # Parsing logic tests
├── sheet_schema_test.exs
├── transform_test.exs
├── union_test.exs
└── integration/
    └── csv_xlsx_parity_test.exs  # Cross-format equivalence (uses example parsers)
```

**Structure Decision**: Single library package with example implementations in `examples/` directory. Existing adapters moved out of `lib/` to maintain zero external parsing dependencies in production.

## Complexity Tracking

No constitution violations to justify. The architecture follows the simplest viable approach:
- Single behaviour with 2 callbacks
- Explicit configuration (no magic)
- Examples in separate directory (not shipped)

## Key Implementation Notes

### Breaking Changes from Current Implementation

1. **Remove bundled parsers**: `nimble_csv` and `xlsx_reader` move to `:dev` only
2. **Explicit parser option**: All `Raggio.Tabular` calls require `parser:` option
3. **Rename behaviour**: `Raggio.Tabular.Adapter` -> `Raggio.Tabular.Parser`
4. **Simplified callbacks**: Remove `sniff/1`, keep only `stream_rows/2` + `sheet_names/1`

### Migration for Existing Users

Users currently relying on automatic CSV/XLSX detection will need to:
1. Add their preferred parsing library to deps
2. Either copy example implementations or write their own
3. Pass `parser:` option explicitly

### Behaviour Contract

```elixir
defmodule Raggio.Tabular.Parser do
  @callback stream_rows(source :: term(), opts :: keyword()) ::
    {:ok, Enumerable.t({pos_integer(), [term()]})} | {:error, term()}

  @callback sheet_names(source :: term()) ::
    {:ok, [String.t()]} | {:error, term()}
end
```
