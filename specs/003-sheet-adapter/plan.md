# Implementation Plan: Sheet Adapter

**Branch**: `003-sheet-adapter` | **Date**: 2026-01-14 | **Spec**: `specs/003-sheet-adapter/spec.md`
**Input**: Feature specification from `specs/003-sheet-adapter/spec.md`

## Summary

Add a new tabular ingestion capability that can read CSV and XLSX files, normalize them into a consistent row stream, and parse them with a declarative SheetSchema to produce typed rows plus row-numbered errors.

## Technical Context

**Language/Version**: Elixir `~> 1.14` (per `mix.exs`)  
**Primary Dependencies**: `decimal`, `jason`, `telemetry` (existing); add `nimble_csv` for CSV parsing; add one XLSX reader (`xlsx_reader` or `spreadsheet`)  
**Storage**: N/A  
**Testing**: `mix test` (ExUnit)  
**Target Platform**: BEAM (library)  
**Project Type**: single Elixir library package (Ecto-style submodules)  
**Performance Goals**: Stream parse 100k rows within ~10s on typical dev laptop  
**Constraints**: Consistent error shape across formats; memory bounded by streaming (avoid loading entire file)  
**Scale/Scope**: CSV + XLSX v1; TSV as delimiter variant; extension point for future formats

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Constitution file `.specify/memory/constitution.md` currently contains placeholder sections (e.g., `[PRINCIPLE_1_NAME]`) and defines no enforceable gates.
- Gate result: PASS (no explicit constitution constraints to enforce).

## Project Structure

### Documentation (this feature)

```text
specs/003-sheet-adapter/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks, not created here)
```

### Source Code (repository root)

```text
lib/
├── raggio.ex
├── raggio/
│   ├── schema.ex
│   ├── schema/
│   ├── syntax.ex
│   ├── syntax/
│   └── bigquery/
└── mix/tasks/

examples/
  raggio_tabular/

test/
```

**Structure Decision**: Implement this feature as a new submodule `Raggio.Tabular` under `lib/raggio/tabular.ex` with internal modules under `lib/raggio/tabular/`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| NIF dependency (optional) | Considered if choosing `spreadsheet` for XLSX performance/format support | Pure-Elixir XLSX parsing may be slower/more memory-hungry for large files |
