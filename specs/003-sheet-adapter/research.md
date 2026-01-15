# Research: Sheet Adapter (Parser-Agnostic Architecture)

**Date**: 2026-01-14 (Updated)  
**Feature**: `003-sheet-adapter`  

## Goal

Design a tabular "Sheet adapter" that is **parser-agnostic**: the library defines behaviours, users provide implementations using their preferred parsing libraries. No bundled CSV/XLSX dependencies.

## Repo Reality Check

### Legacy capabilities (source of truth)

The legacy implementation in `old/` models:
- Header detection by header text and/or fixed position
- Optional columns (skip when missing)
- Union schemas with match strategies (`first_match`, `exact_one`)
- Row range filtering and row-numbered errors

Relevant legacy modules:
- `old/data_schema/sheet_schema.ex` (SheetSchema builder API)
- `old/data_schema/sheet_schema/parser.ex` (pipeline: header -> resolve -> range -> parse rows)
- `old/data_schema/adapters/tabular.ex` (row parsing with row-numbered errors)
- `old/data_schema/parse_error.ex` (error type includes optional `row`)

### Current codebase status

- Existing `lib/raggio/tabular/` implementation with concrete adapters using nimble_csv/xlsx_reader
- These adapters need to be **moved to examples/** per clarifications
- The `Raggio.Tabular.Adapter` behaviour exists but needs simplification

## Decisions

### Decision 1: No bundled parsing libraries

**Decision**: Remove `nimble_csv` and `xlsx_reader` as production dependencies.

**Rationale**:
- Maximum flexibility for users to choose their preferred libraries
- Minimal dependency footprint for the core library
- Avoids version conflicts with user's existing dependencies
- Users can optimize for their specific use case (performance vs simplicity)

**Alternatives considered**:
- Bundled defaults with override capability: adds complexity, still couples to specific libraries
- Separate packages (`raggio_csv`, `raggio_xlsx`): maintenance burden, versioning complexity

**Migration path**:
- Move existing `lib/raggio/tabular/adapters/{csv,xlsx}.ex` to `examples/tabular/`
- Keep nimble_csv/xlsx_reader as `:dev` dependencies for running examples/tests

### Decision 2: Parser behaviour contract

**Decision**: Define `Raggio.Tabular.Parser` behaviour with two callbacks:
- `stream_rows/2` - Returns `Stream.t()` of `{row_number, [cell]}` tuples
- `sheet_names/1` - Returns `{:ok, [String.t()]}` for multi-sheet formats

**Rationale**:
- Streaming-first aligns with FR-019 (large file processing)
- `sheet_names/1` needed for XLSX workbook support (FR-005)
- Minimal surface area - easy to implement wrappers

**Alternatives considered**:
- Single `parse/2` returning full list: doesn't support streaming large files
- Additional callbacks (`sniff/1`, `validate_source/1`): over-engineered for initial scope

**Notes**:
- Single-sheet formats (CSV) should return `{:ok, ["default"]}`
- The existing `Raggio.Tabular.Adapter` will be renamed/refactored to `Raggio.Tabular.Parser`

### Decision 3: Explicit parser selection

**Decision**: Parser module passed explicitly at call site via `parser:` option.

**Rationale**:
- Explicit over implicit - clear which parser handles each file
- No global config or registry needed
- Easy to test with mock parsers
- Matches Elixir idiom of passing modules as arguments

**Example API**:
```elixir
Raggio.Tabular.parse("data.csv", schema,
  parser: MyApp.CSVParser,
  sheet: "default"
)
```

**Alternatives considered**:
- Config-based registry: implicit, harder to trace
- Protocol dispatch on source type: requires wrapping all sources in structs

### Decision 4: Error model (unchanged)

**Decision**: Keep `Raggio.Tabular.Error` struct with `row`, `path`, `message`, `value`.

**Rationale**:
- Already implemented and working
- `row` field critical for FR-012 (row numbers in errors)
- Independent of parser implementation

### Decision 5: Documentation examples

**Decision**: Provide example parser implementations in `examples/tabular/` directory.

**Rationale**:
- Users get working, copy-paste starting points
- Examples are runnable but not shipped as dependencies
- Can demonstrate nimble_csv and xlsx_reader wrappers

**Contents**:
- `examples/tabular/csv_parser.ex` - NimbleCSV wrapper
- `examples/tabular/xlsx_parser.ex` - XlsxReader wrapper
- `examples/tabular/README.md` - Setup and usage guide

## Implementation Implications

### Dependencies to REMOVE from production:
- `nimble_csv` (move to `:dev` only)
- `xlsx_reader` (move to `:dev` only)

### Code changes:
1. Rename `Raggio.Tabular.Adapter` -> `Raggio.Tabular.Parser` (or create new simplified version)
2. Simplify callbacks to `stream_rows/2` and `sheet_names/1`
3. Update `Raggio.Tabular` entry point to require explicit `parser:` option
4. Move `lib/raggio/tabular/adapters/` -> `examples/tabular/`
5. Update tests to use example parsers

### Source structure impact:
```
lib/raggio/tabular/
├── parser.ex          # Behaviour definition (NEW - the behaviour, not the parser logic)
├── row_parser.ex      # Renamed from parser.ex (the actual parsing logic)
├── sheet_schema.ex    # Unchanged
├── column_def.ex      # Unchanged
├── result.ex          # Unchanged
├── error.ex           # Unchanged
├── transform.ex       # Unchanged
├── union.ex           # Unchanged
└── ...

examples/tabular/
├── csv_parser.ex      # Moved from lib/raggio/tabular/adapters/csv.ex
├── xlsx_parser.ex     # Moved from lib/raggio/tabular/adapters/xlsx.ex
└── README.md          # Usage documentation
```

## Open Questions (resolved)

- TSV support: Implemented via delimiter option in user's CSV parser
- Formula handling: User's XLSX parser implementation decides (computed values vs raw)
- Encoding handling: User's parser responsibility; library documents expectations
