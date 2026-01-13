# Implementation Plan: Multi-Package Monorepo Restructure

**Branch**: `001-monorepo-restructure` | **Date**: 2026-01-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-monorepo-restructure/spec.md`

## Summary

Restructure the Raggio codebase into an Elixir umbrella monorepo with three independent packages (Raggio.Schema, Raggio.Syntax, Raggio.Tabular), each independently compilable and publishable. The API follows argument composition syntax where constraints are keyword options to type constructors (`Schema.string(min: 3, max: 5)`). Core constraints are minimal (min, max, pattern, unique). Field descriptors (optional, nullable) are wrapper functions. Examples serve as primary documentation.

## Technical Context

**Language/Version**: Elixir 1.14+ (minimum supported version per spec)  
**Primary Dependencies**: Decimal (precise numeric types), Jason (JSON encoding for BigQuery exporter), standard Elixir libraries (Date, DateTime, Regex)  
**Storage**: N/A (libraries for data validation and syntax manipulation, not data storage)  
**Testing**: ExUnit (Elixir's built-in test framework), automated example verification tests  
**Target Platform**: Elixir/Erlang BEAM VM, any platform supporting Elixir 1.14+  
**Project Type**: Elixir umbrella monorepo with multiple packages  
**Performance Goals**: N/A (focus is on API design and composability, not performance)  
**Constraints**: No macros in public API, minimal inline documentation (module-level only), no circular dependencies between packages  
**Scale/Scope**: 3 packages (Raggio.Schema, Raggio.Syntax, Raggio.Tabular), ~50 public functions, ~20 working examples

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution file contains template placeholders only (project constitution not yet defined). Proceeding with standard Elixir best practices:

| Principle | Status | Notes |
|-----------|--------|-------|
| Function composition over macros | ✅ PASS | FR-007 requires no macros in public API |
| Independent packages | ✅ PASS | FR-004 requires no circular dependencies |
| Example-driven documentation | ✅ PASS | FR-005, FR-006 require working examples |
| Layered architecture | ✅ PASS | Schema is foundational, others depend on it |

## Project Structure

### Documentation (this feature)

```text
specs/001-monorepo-restructure/
├── plan.md              # This file
├── research.md          # Phase 0 output - API design research
├── data-model.md        # Phase 1 output - Schema struct definitions
├── quickstart.md        # Phase 1 output - Getting started guide
├── contracts/           # Phase 1 output - Public API contracts
└── tasks.md             # Phase 2 output - Implementation tasks
```

### Source Code (repository root)

```text
# Elixir Umbrella Monorepo Structure
apps/
├── raggio_schema/           # Core schema validation package
│   ├── lib/
│   │   ├── raggio_schema.ex           # Main module, type constructors
│   │   └── raggio_schema/
│   │       ├── validator.ex           # Validation engine
│   │       ├── error.ex               # Error structs
│   │       ├── coercion.ex            # Type coercion
│   │       ├── transform.ex           # Bidirectional transforms
│   │       └── adapters/
│   │           ├── bigquery.ex        # BigQuery DDL exporter
│   │           └── sheet_schema.ex    # SheetSchema importer
│   ├── test/
│   └── mix.exs
│
├── raggio_syntax/           # Syntax tree manipulation package
│   ├── lib/
│   │   ├── raggio_syntax.ex           # Main module, node builders
│   │   └── raggio_syntax/
│   │       ├── node.ex                # Node protocol
│   │       ├── traversal.ex           # Tree traversal
│   │       └── transformer.ex         # Tree transformation
│   ├── test/
│   └── mix.exs
│
└── raggio_tabular/          # Excel/CSV parsing package (P2)
    ├── lib/
    │   ├── raggio_tabular.ex          # Main module
    │   └── raggio_tabular/
    │       ├── sheet_schema.ex        # DSL for column definitions
    │       ├── parser.ex              # CSV/Excel parsing
    │       ├── adapter.ex             # Batch processing
    │       └── transforms/
    │           └── excel.ex           # Excel-specific transforms
    ├── test/
    └── mix.exs

examples/
├── raggio_schema/
│   ├── basic_validation/    # Simple schema examples
│   ├── composition/         # Schema composition patterns
│   ├── coercion/            # Type coercion examples
│   ├── transforms/          # Bidirectional transform examples
│   └── adapters/            # BigQuery/SheetSchema examples
├── raggio_syntax/
│   ├── node_building/       # Creating syntax nodes
│   ├── traversal/           # Tree traversal patterns
│   └── transformation/      # Tree transformation examples
└── raggio_tabular/
    ├── csv_parsing/         # CSV examples
    └── excel_transforms/    # Excel cleanup examples

test/
└── example_test.exs         # Automated example verification

config/
├── config.exs               # Shared configuration
└── test.exs                 # Test environment config

mix.exs                      # Umbrella project root
```

**Structure Decision**: Elixir umbrella project with apps/ containing independent packages. Examples directory at root level organized by package and use case. Umbrella-level test/ for cross-package example verification.

## Complexity Tracking

No violations requiring justification. Design follows standard Elixir umbrella patterns.
