# Implementation Plan: Multi-Package Monorepo Restructure

**Branch**: `001-monorepo-restructure` | **Date**: 2026-01-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-monorepo-restructure/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Restructure the repository into an Elixir umbrella monorepo containing two independently compilable packages: Raggio.Schema (data validation with composable API) and Raggio.Syntax (syntax structure manipulation). The packages follow Effect-TS/Schema patterns for API design, minimize macro usage, prioritize function composition, and use working examples as primary documentation. Includes adapters for BigQuery export and SheetSchema import.

## Technical Context

**Language/Version**: Elixir 1.14+ (minimum supported version per spec clarifications)  
**Primary Dependencies**: None initially (both packages are foundational libraries with no external dependencies beyond Elixir stdlib)  
**Storage**: N/A (libraries for data validation and syntax manipulation, not data storage)  
**Testing**: ExUnit (standard Elixir testing framework)  
**Target Platform**: Elixir/Erlang VM (BEAM) on any OS supporting Elixir 1.14+  
**Project Type**: Elixir umbrella monorepo (multi-package structure similar to Ecto/Phoenix)  
**Performance Goals**: Compilation <5 minutes for all packages, example execution <30 seconds (SC-001, SC-002)  
**Constraints**: Minimal macros in public API, module-level documentation only (no function docs), working examples as primary documentation, no circular dependencies between packages  
**Scale/Scope**: 2 packages (Raggio.Schema, Raggio.Syntax), 4 adapters (BigQuery export, SheetSchema import), layered architecture (Syntax may depend on Schema, not vice versa), 90% of use cases achievable through function composition

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Note**: No constitution.md file found with specific constraints. Using general best practices:
- ✅ **Modularity**: Two independent packages, clear separation of concerns
- ✅ **Testability**: Automated test suite for examples (FR-009), acceptance criteria defined
- ✅ **Simplicity**: Function composition over macros, minimal inline docs
- ✅ **Standards**: Follows Elixir ecosystem conventions (umbrella projects, ExUnit)

**Constitution Status**: PASS (no violations)

## Project Structure

### Documentation (this feature)

```text
specs/001-monorepo-restructure/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (to be generated)
├── data-model.md        # Phase 1 output (to be generated)
├── quickstart.md        # Phase 1 output (to be generated)
├── contracts/           # Phase 1 output (to be generated)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Elixir Umbrella Monorepo Structure (Ecto/Phoenix style)

# Root umbrella configuration
mix.exs                  # Umbrella project definition
config/                  # Shared configuration
  config.exs
  test.exs

# Package: Raggio.Schema
apps/raggio_schema/
  mix.exs                # Package-specific mix file
  lib/
    raggio_schema.ex     # Main module
    raggio_schema/
      types/             # Type constructors (string, integer, etc.)
      constraints/       # Constraint functions (min, max, etc.)
      validators/        # Validation engine
      adapters/
        bigquery.ex      # BigQuery exporter
        sheet_schema.ex  # SheetSchema importer
  test/
    raggio_schema_test.exs
    types_test.exs
    constraints_test.exs
    validators_test.exs
    adapters/
      bigquery_test.exs
      sheet_schema_test.exs

# Package: Raggio.Syntax
apps/raggio_syntax/
  mix.exs                # Package-specific mix file
  lib/
    raggio_syntax.ex     # Main module
    raggio_syntax/
      node.ex            # Node type definitions
      builder.ex         # Node construction functions
      traversal.ex       # Tree traversal functions
      transformer.ex     # Tree transformation functions
  test/
    raggio_syntax_test.exs
    builder_test.exs
    traversal_test.exs
    transformer_test.exs

# Working Examples (primary documentation)
examples/
  raggio_schema/
    basic_validation/    # Simple schema validation
    composite_types/     # Structs, arrays, unions
    constraints/         # Min/max, patterns, custom
    adapters/
      bigquery_export.exs
      sheet_import.exs
  raggio_syntax/
    syntax_building/     # Creating syntax structures
    traversal/           # Walking trees
    transformation/      # Rewriting structures
    analysis/            # Analyzing syntax patterns

# Example Test Suite (FR-009)
test/
  example_test.exs       # Automated verification of all examples
  test_helper.exs
```

**Structure Decision**: Selected Elixir umbrella monorepo (Option 3 variant) to match Ecto/Phoenix organizational patterns. Two independent apps under `apps/` directory with shared tooling at root. Examples live at root level for easy access. This structure supports independent compilation/publishing while enabling shared development workflows.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - constitution check passed.

## Phase 0: Research & Design Decisions

**Status**: ✅ Complete

Research tasks resolved:

1. ✅ **Effect-TS/Schema API Patterns**: Adopted pipe-based constraint composition pattern
2. ✅ **Elixir Umbrella Best Practices**: Confirmed umbrella monorepo structure per user requirements
3. ✅ **BigQuery DDL Generation**: Documented type mappings and DDL template
4. ✅ **SheetSchema Format**: Defined custom format with 8 columns
5. ✅ **Composable Function Design**: Selected pipe-first + higher-order functions + protocols

**Output**: ✅ `research.md` complete with all decisions documented

## Phase 1: Design Artifacts

**Status**: ✅ Complete

Artifacts generated:

1. ✅ **data-model.md**: Complete entity definitions:
   - Schema types (string, integer, array, struct, etc.)
   - Constraint types (min, max, pattern, email, etc.)
   - Syntax node types (SchemaNode, FieldNode, TypeNode, TransformNode)
   - Validation result structures
   - Error structures with path/message/value
   - All relationships and state transitions documented

2. ✅ **contracts/**: API contracts complete:
   - `raggio_schema_api.md`: Full public API for schema definition and validation
   - `raggio_syntax_api.md`: Full public API for syntax building, traversal, transformation
   - `adapters.md`: BigQuery export and SheetSchema import adapter contracts

3. ✅ **quickstart.md**: Getting started guide with working examples

**Output**: ✅ Complete design documentation ready for task decomposition

## Phase 2: Task Breakdown

**Status**: Not Started (requires Phase 1 completion)

**Note**: Task breakdown happens in separate `/speckit.tasks` command. This plan provides the foundation for that decomposition.

Expected task categories:
- Setup: Umbrella project structure, package scaffolding
- Core: Schema types, constraints, validation engine
- Core: Syntax nodes, builders, traversal, transformation
- Adapters: BigQuery exporter, SheetSchema importer
- Examples: Working examples for both packages
- Testing: Unit tests, example verification suite
- Documentation: README files, module-level docs

## Implementation Notes

### Critical Requirements

1. **Constraint API Must Match Spec**: Implementation must use `Schema.string(Schema.min(3), Schema.max(5))` pattern where constraints are composable functions passed as arguments (NOT keyword lists). This is the Effect-TS/Zod v4 style specified in FR-014.

2. **Terminology Consistency**: Use "Syntax" (not "AST" or "Syntax Tree") throughout code, examples, and documentation per clarification session.

3. **No Circular Dependencies**: Raggio.Syntax may depend on Raggio.Schema, but Raggio.Schema must NOT depend on Raggio.Syntax (FR-004).

4. **Minimal Documentation**: Module-level purpose only, no function docs. Working examples serve as primary documentation (FR-005).

5. **Error Structure**: Validation errors must include `%{path: [...], message: "...", value: actual_value}` (FR-015).

### Package Dependency Architecture

```
┌─────────────────┐
│ Raggio.Syntax   │  (Can depend on Schema)
│ (Syntax manip)  │
└────────┬────────┘
         │ depends on
         ▼
┌─────────────────┐
│ Raggio.Schema   │  (No dependencies on Syntax)
│ (Validation)    │
└─────────────────┘
```

### Example Organization Pattern

Examples follow two-level hierarchy: `examples/{package}/{use_case}/`
- Each example is a single `.exs` file
- Self-contained and independently runnable
- Automated test suite verifies all examples compile and execute
- Examples demonstrate one specific pattern/use case

### Adapter Design Pattern

Both BigQuery exporter and SheetSchema importer follow adapter pattern:
- Located in `apps/raggio_schema/lib/raggio_schema/adapters/`
- Clean separation from core validation logic
- Composable with schema definitions
- Independently testable

## Next Steps

1. ✅ Complete specification clarification
2. ✅ Execute Phase 0 research (research.md)
3. ✅ Execute Phase 1 design (data-model.md, contracts/, quickstart.md)
4. ✅ Update agent context (AGENTS.md)
5. ⏳ **Next**: Run `/speckit.tasks` to generate task breakdown (Phase 2)

---

## Phase Completion Summary

**Phase 0 - Research**: ✅ Complete
- All technical unknowns resolved
- 5 research areas investigated
- Decisions documented with rationale

**Phase 1 - Design**: ✅ Complete
- Data model defined (26 entities)
- API contracts created (3 documents)
- Quickstart guide ready
- Agent context updated

**Ready for Phase 2**: Task decomposition via `/speckit.tasks`

---

*Planning phase complete. Implementation ready to begin.*
