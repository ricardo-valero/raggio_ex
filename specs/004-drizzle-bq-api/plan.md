# Implementation Plan: Drizzle-like Composable BigQuery API

**Branch**: `004-drizzle-bq-api` | **Date**: 2026-01-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-drizzle-bq-api/spec.md`

## Summary

Enhance the Raggio BigQuery adapter with a Drizzle-inspired composable API that enables hierarchical schema definition (project -> dataset -> table), functional composition patterns from Effect-TS/Schema, and bidirectional DDL conversion using NimbleParsec.

**Key Architecture Decision**: raggio.schema.Type is THE canonical, portable schema format. BigQuery (and future adapters like API/JSON-Schema) implement the `Raggio.Schema.Adapter` behaviour to convert to/from this canonical format, enabling "define once, deploy anywhere" workflows.

## Technical Context

**Language/Version**: Elixir ~> 1.14  
**Primary Dependencies**: decimal ~> 2.0, jason ~> 1.4, telemetry ~> 1.0, nimble_parsec ~> 1.4 (to add)  
**Storage**: N/A (BigQuery external service - library generates DDL/schemas)  
**Testing**: ExUnit (standard Elixir testing framework)  
**Target Platform**: Elixir library (OTP applications)
**Project Type**: single (Elixir library)  
**Performance Goals**: Schema composition/validation <50ms for typical project (10+ tables)  
**Constraints**: Development-time operations; must maintain backward compatibility with existing `use Raggio.BigQuery.Table` pattern  
**Scale/Scope**: 3+ datasets, 10+ tables per project definition; support 95% of real-world BigQuery DDL

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Constitution Defined | SKIP | Constitution file is template-only; no project-specific rules defined |
| Library Self-Contained | PASS | Feature extends existing raggio library with new modules |
| Independently Testable | PASS | Each component (Adapter behaviour, Project/Dataset/Table structs, DDL parser, DDL generator) testable in isolation |
| Backward Compatible | PASS | New API coexists with existing behaviour-based patterns |
| Extensible | PASS | Adapter behaviour enables future adapters (API, JSON-Schema) without modifying core |

**Gate Result**: PASS - No blocking violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/004-drizzle-bq-api/
├── spec.md              # Feature specification (with clarifications)
├── plan.md              # This file
├── research.md          # Phase 0 output - API design research + adapter architecture
├── data-model.md        # Phase 1 output - Entity definitions including Adapter
├── quickstart.md        # Phase 1 output - Usage guide with bidirectional conversion
├── contracts/           # Phase 1 output - API contracts
│   ├── adapter.ex       # Adapter behaviour contract
│   ├── project.ex       # Project struct contract
│   ├── dataset.ex       # Dataset struct contract
│   ├── composer.ex      # Composer builder contract
│   └── ddl_parser.ex    # Parser function contracts
└── checklists/
    └── requirements.md  # Validation checklist
```

### Source Code (repository root)

```text
lib/raggio/
├── schema.ex                    # Existing - type constructors
├── schema/
│   ├── type.ex                  # Existing - Type struct (canonical format)
│   ├── validator.ex             # Existing - validation engine
│   ├── adapter.ex               # NEW - Adapter behaviour definition
│   └── adapters/
│       └── bigquery.ex          # ENHANCE - Implement Adapter behaviour
├── syntax.ex                    # Existing - AST manipulation
├── syntax/
│   ├── node.ex                  # Existing - AST nodes
│   └── traversal.ex             # Existing - visitor pattern
└── bigquery/
    ├── project.ex               # NEW - Project composition struct
    ├── dataset.ex               # NEW - Dataset composition struct  
    ├── table_def.ex             # NEW - TableDef struct (distinct from Table behaviour)
    ├── column.ex                # NEW - Column struct
    ├── table.ex                 # Existing - Table behaviour (keep)
    ├── ddl.ex                   # Existing - DDL generation (enhance)
    ├── ddl/
    │   └── parser.ex            # NEW - NimbleParsec DDL parser
    ├── composer.ex              # NEW - Functional composition helpers
    └── error.ex                 # NEW - Validation error struct

test/raggio/
├── schema/
│   └── adapter_test.exs         # NEW - Adapter behaviour tests
└── bigquery/
    ├── project_test.exs         # NEW
    ├── dataset_test.exs         # NEW
    ├── table_def_test.exs       # NEW
    ├── composer_test.exs        # NEW
    └── ddl/
        └── parser_test.exs      # NEW
```

**Structure Decision**: 
- Adapter behaviour lives in `lib/raggio/schema/adapter.ex` (schema-level, not BigQuery-specific)
- BigQuery adapter implementation enhances existing `lib/raggio/schema/adapters/bigquery.ex`
- New composition structs in `lib/raggio/bigquery/` 
- Parser in `ddl/` subdirectory
- Tests mirror source structure

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          User Code                                          │
│  project("my-project") |> dataset("analytics") |> table("events") |> build()│
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Raggio.BigQuery.Composer                                 │
│  Fluent builder API for composing BigQuery project hierarchies              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│          BigQuery Structs (Project, Dataset, TableDef, Column)              │
│  Adapter-specific data structures with validation                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
┌───────────────────────────────┐   ┌───────────────────────────────────────┐
│  Raggio.Schema.Adapters.      │   │  Raggio.BigQuery.DDL                  │
│  BigQuery (implements Adapter)│   │  DDL generation + parsing             │
│                               │   │                                       │
│  to_schema/1: TableDef → Type │   │  to_ddl/1: TableDef → SQL            │
│  from_schema/1: Type → TableDef│   │  Parser.parse/1: SQL → TableDef      │
└───────────────────────────────┘   └───────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Raggio.Schema.Type (CANONICAL)                           │
│  Portable schema format - adapters convert to/from this                     │
│  metadata: %{bigquery: %{partition_by: ...}, api: %{...}}                  │
└─────────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              Future Adapters (Out of Scope for This Feature)                │
│  Raggio.Schema.Adapters.OpenAPI  - API endpoint schemas                     │
│  Raggio.Schema.Adapters.JSONSchema - JSON Schema format                     │
│  All implement same Adapter behaviour with to_schema/1, from_schema/1       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Complexity Tracking

> No constitution violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | - | - |
