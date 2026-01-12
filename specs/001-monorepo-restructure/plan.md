# Implementation Plan: Multi-Package Monorepo Restructure

**Branch**: `001-monorepo-restructure` | **Date**: 2026-01-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-monorepo-restructure/spec.md`

## Summary

Transform the existing single-package codebase in `/old_code` into an Elixir umbrella monorepo with two independent package: Raggio.Schema (for data schema definition and validation) and Raggio.Syntax (for AST manipulation). Each package will expose a composable, function-based API (minimal macro) with working, compilable example as primary documentation. The structure follows Ecto/Phoenix patterns, with inspiration from Effect-TS/Schema for API design.

## Technical Context

**Language/Version**: Elixir 1.14+ (compatible with current Elixir ecosystem)
**Primary Dependencies**: None initially (both package are foundational library with no external dependency beyond Elixir stdlib)
**Storage**: N/A (library do not persist data)
**Testing**: ExUnit (standard Elixir test framework)
**Target Platform**: Elixir/Erlang BEAM VM (any platform running Elixir)
**Project Type**: Umbrella (multi-package monorepo)
**Performance Goals**: Compilation time under 5 minute for all package; example execution under 30 second
**Constraints**: Minimal macro usage; module-level documentation only; no circular dependency between package
**Scale/Scope**: 2 package initially (Raggio.Schema, Raggio.Syntax); ~15-20 working example; migration of existing functionality from old_code

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Status**: Constitution file is currently a template. No specific gate defined yet. Proceeding with standard Elixir best practice:

- ✓ **Test Coverage**: ExUnit test for all public API
- ✓ **Documentation**: Module-level purpose only (per spec requirement)
- ✓ **Composability**: Function composition over macro (per spec requirement)
- ✓ **Independence**: Each package independently compilable and publishable
- ✓ **Example Verification**: Automated test suite for all example

**Re-evaluation Required**: After Phase 1 design completion

## Project Structure

### Documentation (this feature)

```text
specs/001-monorepo-restructure/
├── plan.md              # This file
├── research.md          # Phase 0: Effect-TS/Schema pattern, umbrella structure
├── data-model.md        # Phase 1: Schema and AST entity model
├── quickstart.md        # Phase 1: Getting started guide
├── contracts/           # Phase 1: Public API contract for both package
│   ├── raggio_schema_api.md
│   └── raggio_syntax_api.md
└── tasks.md             # Phase 2: NOT created by this command
```

### Source Code (repository root)

```text
# Elixir Umbrella Project Structure (Ecto/Phoenix style)

# Root umbrella configuration
mix.exs                  # Umbrella project definition
config/
└── config.exs          # Shared configuration

# Package directory
apps/
├── raggio_schema/      # Schema definition and validation package
│   ├── mix.exs         # Package-specific mix file
│   ├── lib/
│   │   ├── raggio_schema.ex           # Main module entry point
│   │   ├── raggio_schema/
│   │   │   ├── builder.ex             # Schema builder function
│   │   │   ├── validator.ex           # Validation function
│   │   │   ├── combinator.ex          # Composition combinator
│   │   │   ├── type/                  # Type definition (string, integer, etc.)
│   │   │   │   ├── string.ex
│   │   │   │   ├── integer.ex
│   │   │   │   ├── float.ex
│   │   │   │   ├── boolean.ex
│   │   │   │   ├── date.ex
│   │   │   │   ├── datetime.ex
│   │   │   │   ├── decimal.ex
│   │   │   │   ├── array.ex
│   │   │   │   ├── struct.ex
│   │   │   │   └── enum.ex
│   │   │   ├── error.ex               # Error type for validation failure
│   │   │   └── transformer.ex         # Data transformation
│   ├── test/
│   │   ├── test_helper.exs
│   │   ├── raggio_schema_test.exs
│   │   ├── builder_test.exs
│   │   ├── validator_test.exs
│   │   └── type/                      # Test for each type
│   └── README.md                       # Package-specific README
│
└── raggio_syntax/      # AST manipulation package
    ├── mix.exs         # Package-specific mix file
    ├── lib/
    │   ├── raggio_syntax.ex           # Main module entry point
    │   ├── raggio_syntax/
    │   │   ├── ast.ex                 # Core AST definition
    │   │   ├── builder.ex             # AST builder function
    │   │   ├── traversal.ex           # Traversal combinator
    │   │   ├── transformer.ex         # AST transformation function
    │   │   ├── node/                  # AST node type
    │   │   │   ├── field.ex
    │   │   │   ├── schema.ex
    │   │   │   ├── type.ex
    │   │   │   └── transform.ex
    │   │   └── error.ex               # AST error type
    ├── test/
    │   ├── test_helper.exs
    │   ├── raggio_syntax_test.exs
    │   ├── builder_test.exs
    │   ├── traversal_test.exs
    │   └── transformer_test.exs
    └── README.md                       # Package-specific README

# Example directory (two-level hierarchy per clarification)
examples/
├── raggio_schema/
│   ├── basic_validation/
│   │   ├── simple_schema.exs          # Basic schema definition
│   │   ├── nested_schema.exs          # Nested structure
│   │   └── validation_error.exs       # Error handling
│   ├── composition/
│   │   ├── combine_validator.exs      # Composing validator
│   │   ├── custom_type.exs            # Creating custom type
│   │   └── reusable_schema.exs        # Schema reuse pattern
│   ├── transformation/
│   │   ├── data_mapping.exs           # Transform input data
│   │   └── coercion.exs               # Type coercion
│   └── advanced/
│       ├── conditional_validation.exs # Conditional logic
│       └── cross_field.exs            # Cross-field validation
│
└── raggio_syntax/
    ├── ast_building/
    │   ├── simple_ast.exs             # Basic AST construction
    │   ├── complex_schema.exs         # Complex AST structure
    │   └── node_composition.exs       # Composing node
    ├── traversal/
    │   ├── depth_first.exs            # DFS traversal
    │   ├── visitor_pattern.exs        # Visitor combinator
    │   └── filtering.exs              # Filter node during traversal
    ├── transformation/
    │   ├── modify_node.exs            # Transform AST node
    │   ├── rewrite_rule.exs           # Apply rewrite rule
    │   └── optimization.exs           # AST optimization
    └── advanced/
        ├── code_generation.exs        # Generate code from AST
        └── analysis.exs               # AST analysis pattern

# Example test suite (automated verification)
test/
└── example_test.exs                   # Test that runs all example and verifies output

# Archive original code
old_code/
└── data_schema/                       # Reference only, not part of new structure
```

**Structure Decision**: Selected Elixir umbrella project structure to match Ecto/Phoenix patterns (FR-001). This provides:
- Independent package compilation and publishing (FR-004)
- Clear separation of concern (Schema vs Syntax)
- Shared tooling at umbrella root
- No circular dependency by design (FR-004 clarification)
- Example organized by package and use case (clarification from session 2026-01-12)

## Complexity Tracking

> No constitution violation detected. This section remains empty.

## Phase 0: Research & Decision

**Objective**: Resolve technical unknowns and establish API design pattern

### Research Task

1. **Effect-TS/Schema API Pattern Analysis**
   - Research: How does Effect-TS/Schema structure composable API?
   - Research: What composition pattern are used (pipe, compose, combinator)?
   - Research: How are error handled in composition?
   - Research: How is type safety achieved without macro?
   - Output: Pattern applicable to Elixir functional programming

2. **Elixir Umbrella Best Practice**
   - Research: How do Ecto and Phoenix structure umbrella project?
   - Research: Dependency management between umbrella app
   - Research: Shared configuration and tooling
   - Research: Publishing strategy for umbrella package
   - Output: Concrete umbrella structure decision

3. **Composability without Macro**
   - Research: Elixir function composition pattern (pipe operator, composition combinator)
   - Research: How to achieve fluent API without `use` macro
   - Research: Error accumulation pattern (Result/Either type in Elixir)
   - Output: API design guideline for both package

4. **Example Testing Strategy**
   - Research: How to automatically verify example output
   - Research: Example execution in CI environment
   - Research: Approach to maintain example freshness
   - Output: Automated test suite approach for example

**Output File**: `research.md` (consolidated finding with decision and rationale)

## Phase 1: Design & Contract

**Prerequisites**: `research.md` complete

### Task 1.1: Data Model Design

**Objective**: Define entity and relationship for both package

**Input**: 
- Feature spec Key Entity section
- Existing old_code structure (old_code/data_schema, old_code/data_schema/ast)
- Research finding on Effect-TS pattern

**Output**: `data-model.md` containing:

**Raggio.Schema Entity**:
- Schema: Container for field definition and validation rule
- Field: Individual data field with type, constraint, and validation
- Type: Primitive type (string, integer, float, boolean, date, datetime, decimal, array, struct, enum)
- Validator: Composable validation function
- ValidationResult: Success or error with detail
- ValidationError: Error information with path and message
- Transformer: Data transformation function

**Raggio.Syntax Entity**:
- AST: Root abstract syntax tree structure
- Node: Base AST node (field, schema, type, transform)
- FieldNode: Represents a field in schema
- SchemaNode: Represents a schema definition
- TypeNode: Represents a type annotation
- TransformNode: Represents a transformation
- Traversal: Visitor pattern for AST navigation
- Transformer: AST rewrite function

**Relationship**:
- Schema contains multiple Field
- Field has one Type
- Type can be composite (array of Type, struct with Field)
- Validator operate on Field and Schema
- AST contains multiple Node
- Node can have child Node (tree structure)
- Traversal visit Node in defined order
- Transformer produce new AST from existing AST

**State Transition**:
- Schema: draft → validated → ready
- ValidationResult: pending → success/error
- AST: constructed → traversed → transformed

### Task 1.2: API Contract Definition

**Objective**: Define public API for both package

**Input**:
- Functional requirement (FR-007, FR-008, FR-010, FR-011)
- Data model from Task 1.1
- Research finding on composable API pattern

**Output**: Two contract file in `contracts/`

**File**: `contracts/raggio_schema_api.md`

```markdown
# Raggio.Schema Public API Contract

## Module: Raggio.Schema

### Function: string()
**Signature**: `() -> schema`
**Purpose**: Create string type schema
**Return**: Schema representing string type
**Example**: `Raggio.Schema.string()`

### Function: integer()
**Signature**: `() -> schema`
**Purpose**: Create integer type schema
**Return**: Schema representing integer type

### Function: compose(schema, schema)
**Signature**: `(schema, schema) -> schema`
**Purpose**: Combine two schema into composite schema
**Return**: New schema combining both input
**Error**: Composition error if type incompatible

### Function: validate(schema, data)
**Signature**: `(schema, any) -> {:ok, data} | {:error, validation_error}`
**Purpose**: Validate data against schema
**Return**: Success tuple with data or error tuple with validation detail

[Additional function following same pattern...]
```

**File**: `contracts/raggio_syntax_api.md`

```markdown
# Raggio.Syntax Public API Contract

## Module: Raggio.Syntax

### Function: field(name, type)
**Signature**: `(atom, type) -> node`
**Purpose**: Create field node
**Return**: FieldNode with name and type

### Function: schema(fields)
**Signature**: `([node]) -> node`
**Purpose**: Create schema node from field list
**Return**: SchemaNode containing field

### Function: traverse(ast, visitor)
**Signature**: `(node, (node -> any)) -> any`
**Purpose**: Traverse AST applying visitor function
**Return**: Result of traversal

[Additional function following same pattern...]
```

### Task 1.3: Quickstart Guide

**Objective**: Create getting started guide for developer

**Input**:
- User story from spec (all 4 user story)
- API contract from Task 1.2
- Example structure from project layout

**Output**: `quickstart.md` containing:

1. **Installation** (User Story 1 acceptance scenario 1)
   - How to add Raggio.Schema to mix.exs
   - How to add Raggio.Syntax to mix.exs
   - Running mix deps.get

2. **First Schema** (User Story 1 acceptance scenario 2-4)
   - Define simple schema with Raggio.Schema
   - Validate data against schema
   - Handle validation error

3. **First AST** (User Story 2 acceptance scenario 1-3)
   - Create AST node with Raggio.Syntax
   - Compose node together
   - Traverse AST structure

4. **Exploring Example** (User Story 3 acceptance scenario 1-3)
   - Navigate example directory
   - Run example file
   - Understand example pattern

5. **Composing Custom Function** (User Story 4 acceptance scenario 1-3)
   - Combine primitive function
   - Create custom validator
   - Build custom AST transformer

### Task 1.4: Update Agent Context

**Objective**: Update AI agent context with technology from this plan

**Action**: Run agent context update script
```bash
.specify/scripts/bash/update-agent-context.sh opencode
```

**Verification**: Check that `.specify/memory/opencode/context.md` includes:
- Elixir umbrella project structure
- Raggio.Schema and Raggio.Syntax package
- Composable API pattern without macro
- Example-driven documentation approach

## Phase 1 Completion Checklist

- [ ] research.md completed with all decision documented
- [ ] data-model.md defines all entity and relationship
- [ ] contracts/raggio_schema_api.md specifies complete public API
- [ ] contracts/raggio_syntax_api.md specifies complete public API
- [ ] quickstart.md covers all 4 user story
- [ ] Agent context updated with new technology
- [ ] Constitution Check re-evaluated (no new violation)

## Next Step

After Phase 1 completion, run `/speckit.tasks` to generate Phase 2 task breakdown for implementation.
