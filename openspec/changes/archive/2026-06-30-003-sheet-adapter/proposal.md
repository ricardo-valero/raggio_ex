# Sheet Adapter (Parser-Agnostic Tabular Ingestion)

## Why

Raggio needs a single, consistent way to turn real-world spreadsheet files (CSV,
XLSX, TSV) into typed, validated rows. Business users send tabular data with
inconsistent headers, leading junk rows, messy value formatting, and multiple
file-format versions. Downstream pipelines need clean output that separates
valid rows from invalid rows with actionable, row-numbered errors.

The prior implementation bundled concrete CSV/XLSX adapters (`nimble_csv`,
`xlsx_reader`) as production dependencies. This coupled the core library to
specific parsing libraries, risked version conflicts in user projects, and grew
the dependency footprint. We want the core library to stay parser-agnostic:
define the contract, let users bring their own parser.

## What Changes

- Introduce a `Raggio.Tabular.Parser` behaviour as the single extension point for
  all tabular formats, with two streaming-focused callbacks (`stream_rows/2`,
  `sheet_names/1`).
- Require explicit parser selection at the call site via a `parser:` option; no
  implicit registration, auto-detection, or config-based resolution.
- Remove `nimble_csv` and `xlsx_reader` as production dependencies; move them to
  `:dev` only. Move the previously-bundled CSV/XLSX adapters out of `lib/` into
  `examples/tabular/` as runnable reference implementations.
- Rename the existing parsing-logic module `Raggio.Tabular.Parser` (old) to
  `Raggio.Tabular.RowParser` to free the name for the behaviour.
- Delete the adapter registry (`registry.ex`) — explicit selection makes it
  unnecessary.
- Preserve legacy parity for header detection, optional columns, header variants,
  union-schema matching, row-range filtering, value transforms, and
  row-numbered errors.

## Capabilities

### New Capabilities
- `tabular`: CSV/XLSX/TSV sheet parsing through a user-supplied
  `Raggio.Tabular.Parser` behaviour, plus schema-driven row parsing
  (`SheetSchema` + `ColumnDef`) that resolves columns by header/position,
  applies value transforms, filters rows, matches union schemas, and returns a
  `Result` splitting valid rows from row-numbered errors.

### Modified Capabilities
- `schema`: None. The tabular subsystem consumes `Raggio.Schema` types for
  per-cell validation but does not modify the schema capability itself. No
  `sheet_schema` adapter was added to the schema capability; `SheetSchema` lives
  entirely within the `tabular` capability under `lib/raggio/tabular/`.

## Impact

- `lib/raggio/tabular.ex` — public entry point (`parse/3`, `list_sheets/2`) now
  requires the `parser:` option.
- `lib/raggio/tabular/parser.ex` — NEW behaviour definition (`stream_rows/2`,
  `sheet_names/1`).
- `lib/raggio/tabular/row_parser.ex` — renamed from the old `parser.ex`; the
  parsing pipeline (header resolution, transforms, filtering, union matching,
  error accumulation).
- `lib/raggio/tabular/{sheet_schema,column_def,union,transform,result,error,
  source,sheet_info,worksheet_selector}.ex` — verified/retained.
- `lib/raggio/tabular/adapters/` — removed (migrated to examples).
- `lib/raggio/tabular/registry.ex` — removed.
- `examples/tabular/{csv_parser.ex,xlsx_parser.ex,README.md}` — reference parser
  implementations wrapping `nimble_csv` and `xlsx_reader`.
- `mix.exs` — `nimble_csv` and `xlsx_reader` moved to `:dev` only.
- Dependencies: per the research decision, the core library bundles **no**
  parsing libraries. `nimble_csv` + an XLSX reader are needed only to run the
  examples and are declared `:dev`-only.
