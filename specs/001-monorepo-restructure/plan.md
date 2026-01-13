# Implementation Plan: Single-Package Restructure (Ecto-style)

**Branch**: `001-monorepo-restructure` | **Date**: 2026-01-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-monorepo-restructure/spec.md`

## Summary

Restructure the existing old_code/data_schema codebase into a single Elixir package with submodules (Raggio.Schema, Raggio.Syntax) following Ecto's architecture pattern. The new API will use argument composition syntax for constraints (e.g., `Schema.string(min: 3, max: 5)`) instead of pipe-based builders, minimize macros, and prioritize composability. Includes BigQuery exporter and SheetSchema importer adapters.

## Technical Context

**Language/Version**: Elixir 1.14+ (minimum supported version per spec)  
**Primary Dependencies**: Decimal (precise numerics), Jason (JSON encoding for BigQuery exporter)  
**Storage**: N/A (library for data validation and syntax manipulation, not data storage)  
**Testing**: ExUnit (standard Elixir testing framework)  
**Target Platform**: Elixir/BEAM (library package)  
**Project Type**: Single package with submodules (Ecto-style, NOT umbrella)  
**Performance Goals**: N/A (explicitly out of scope per spec - focus is on API design)  
**Constraints**: Minimal macros in public API, function composition over DSLs, module-level docs only  
**Scale/Scope**: Library package - Raggio.Schema + Raggio.Syntax submodules (Raggio.Tabular deferred)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Status**: PASS (No constitution defined)

The project constitution (`.specify/memory/constitution.md`) contains only template placeholders - no project-specific principles or gates are defined. Proceeding without constitution constraints.

**Applicable Constraints from Spec**:
- [x] Single package structure (NOT umbrella) - Clarified in spec
- [x] Minimal macros in public API - Core design principle
- [x] Function composition over macro DSLs - Core design principle  
- [x] Module-level docs only, no function docs - Documentation standard
- [x] Working examples as primary documentation - Documentation standard
- [x] No circular dependencies between submodules - Architecture constraint

## Project Structure

### Documentation (this feature)

```text
specs/001-monorepo-restructure/
├── plan.md              # This file
├── research.md          # Phase 0 output - Effect-TS/Schema patterns, Ecto structure
├── data-model.md        # Phase 1 output - Schema type definitions
├── quickstart.md        # Phase 1 output - Getting started guide
├── contracts/           # Phase 1 output - API type specifications
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (Ecto-style single package)

```text
raggio/
├── mix.exs                          # Single package configuration
├── lib/
│   ├── raggio.ex                    # Root module (minimal - version, config)
│   ├── raggio/
│   │   ├── schema.ex                # Raggio.Schema - main entry point
│   │   ├── schema/
│   │   │   ├── type.ex              # Type struct definition
│   │   │   ├── types/               # Primitive type constructors
│   │   │   │   ├── string.ex
│   │   │   │   ├── integer.ex
│   │   │   │   ├── float.ex
│   │   │   │   ├── decimal.ex
│   │   │   │   ├── boolean.ex
│   │   │   │   ├── date.ex
│   │   │   │   └── datetime.ex
│   │   │   ├── composites/          # Composite type constructors
│   │   │   │   ├── list.ex
│   │   │   │   ├── struct.ex
│   │   │   │   ├── record.ex
│   │   │   │   ├── tuple.ex
│   │   │   │   └── literal.ex
│   │   │   ├── constraints.ex       # min, max, pattern, unique
│   │   │   ├── descriptors.ex       # optional, nullable, default
│   │   │   ├── coercion.ex          # Type coercion builders
│   │   │   ├── transform.ex         # Bidirectional transforms
│   │   │   ├── validator.ex         # Core validation logic
│   │   │   ├── error.ex             # Error struct with path, message, value
│   │   │   └── adapters/
│   │   │       ├── bigquery.ex      # BigQuery DDL exporter
│   │   │       └── sheet_schema.ex  # SheetSchema importer
│   │   ├── syntax.ex                # Raggio.Syntax - main entry point
│   │   └── syntax/
│   │       ├── node.ex              # Syntax node struct
│   │       ├── builder.ex           # Node builders
│   │       ├── traversal.ex         # Tree traversal functions
│   │       └── transform.ex         # Transformation utilities
├── test/
│   ├── test_helper.exs
│   ├── raggio/
│   │   ├── schema_test.exs
│   │   ├── schema/
│   │   │   ├── types_test.exs
│   │   │   ├── constraints_test.exs
│   │   │   ├── validator_test.exs
│   │   │   └── adapters/
│   │   │       ├── bigquery_test.exs
│   │   │       └── sheet_schema_test.exs
│   │   ├── syntax_test.exs
│   │   └── syntax/
│   │       └── builder_test.exs
│   └── examples_test.exs            # Automated example verification
└── examples/
    ├── schema/
    │   ├── basic_validation/
    │   ├── nested_structs/
    │   ├── coercion/
    │   ├── transforms/
    │   └── bigquery_export/
    └── syntax/
        ├── node_building/
        └── tree_traversal/
```

**Structure Decision**: Single Elixir package with submodules following Ecto's organizational pattern. The root `Raggio` module is minimal; `Raggio.Schema` and `Raggio.Syntax` are the primary API entry points. This structure supports:
- Independent submodule usage within a single dependency
- Clear layered architecture (Schema is foundational, Syntax may depend on Schema)
- Example-driven documentation with automated verification

## Complexity Tracking

> No constitution violations to justify. Design follows all spec constraints.

| Design Decision | Rationale | Alternatives Considered |
|-----------------|-----------|------------------------|
| Single package vs umbrella | Spec clarification: like Ecto, not Phoenix umbrella | Umbrella rejected per user requirement |
| Argument composition API | Concise syntax per spec: `string(min: 3, max: 5)` | Pipe-based rejected (old_code style) |
| 4 core constraints only | Simplicity: min, max, pattern, unique | Extended set (email, url, etc.) - can be helpers |
| Keyword list for structs | `Schema.struct([{:name, ...}])` - dynamic construction | Map syntax conflicts with reserved keywords |

---

## Post-Design Constitution Re-check

**Status**: PASS

All design decisions align with spec constraints:
- [x] Single package structure verified in Source Code section
- [x] Argument composition API documented in contracts
- [x] No macros in public API - all functions are composable
- [x] Module-level docs only - reflected in examples structure
- [x] Layered architecture - Schema has no Raggio dependencies, Syntax may depend on Schema
- [x] BigQuery exporter and SheetSchema importer included in scope

---

## Generated Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| Implementation Plan | `specs/001-monorepo-restructure/plan.md` | ✓ Complete |
| Research Findings | `specs/001-monorepo-restructure/research.md` | ✓ Complete |
| Data Model | `specs/001-monorepo-restructure/data-model.md` | ✓ Complete |
| Schema API Contract | `specs/001-monorepo-restructure/contracts/raggio_schema_api.md` | ✓ Complete |
| Syntax API Contract | `specs/001-monorepo-restructure/contracts/raggio_syntax_api.md` | ✓ Complete |
| Adapters Contract | `specs/001-monorepo-restructure/contracts/adapters.md` | ✓ Complete |
| Quickstart Guide | `specs/001-monorepo-restructure/quickstart.md` | ✓ Complete |
| Agent Context | `AGENTS.md` | ✓ Updated |

---

## Next Steps

Run `/speckit.tasks` to generate the implementation task list from this plan.
