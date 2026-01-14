# Tasks: Multi-Package Monorepo Restructure

**Input**: Design documents from `/specs/001-monorepo-restructure/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Branch**: `001-monorepo-restructure`  
**Feature**: Restructure repository into Elixir umbrella monorepo with Raggio.Schema and Raggio.Syntax packages

**Tests**: Tests are included per FR-009 requirement for automated example verification

**Organization**: Tasks grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5, US6)
- File paths use Elixir umbrella monorepo structure per plan.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Umbrella project initialization and structure

- [ ] T001 Create umbrella project structure with `mix new . --umbrella`
- [ ] T002 Configure root mix.exs with umbrella settings and apps_path: "apps"
- [ ] T003 [P] Create config/config.exs for shared configuration
- [ ] T004 [P] Create config/test.exs for test environment configuration
- [ ] T005 [P] Create root .formatter.exs with subdirectories: ["apps/*"]
- [ ] T006 [P] Create root .gitignore with Elixir patterns
- [ ] T007 [P] Create apps/raggio_schema/ directory
- [ ] T008 [P] Create apps/raggio_syntax/ directory
- [ ] T009 [P] Create examples/ directory at root
- [ ] T010 [P] Create test/ directory at root for example verification

**Checkpoint**: Umbrella structure ready - package scaffolding can begin in parallel

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Package scaffolds and shared tooling that user stories depend on

**⚠️ CRITICAL**: Complete before user story implementation begins

### Package Scaffolds (can run in parallel)

- [ ] T011 [P] Initialize Raggio.Schema package with `mix new apps/raggio_schema`
- [ ] T012 [P] Configure apps/raggio_schema/mix.exs with app: :raggio_schema, version: "0.1.0", elixir: "~> 1.14"
- [ ] T013 [P] Create apps/raggio_schema/lib/raggio_schema.ex entry point with module doc
- [ ] T014 [P] Create apps/raggio_schema/lib/raggio_schema/ subdirectory
- [ ] T015 [P] Create apps/raggio_schema/test/test_helper.exs
- [ ] T016 [P] Initialize Raggio.Syntax package with `mix new apps/raggio_syntax`
- [ ] T017 [P] Configure apps/raggio_syntax/mix.exs with app: :raggio_syntax, version: "0.1.0", elixir: "~> 1.14", deps: [{:raggio_schema, in_umbrella: true}]
- [ ] T018 [P] Create apps/raggio_syntax/lib/raggio_syntax.ex entry point with module doc
- [ ] T019 [P] Create apps/raggio_syntax/lib/raggio_syntax/ subdirectory
- [ ] T020 [P] Create apps/raggio_syntax/test/test_helper.exs

### Example Test Infrastructure

- [ ] T021 [P] Create test/test_helper.exs at root with ExUnit.start()

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Developer imports and uses Raggio.Schema package (Priority: P1) 🎯 MVP

**Goal**: Core schema definition and validation functionality with composable API

**Independent Test**: Install Raggio.Schema, define simple schema (user with name/age), validate data successfully

### Core Schema Structure

- [ ] T022 [P] [US1] Create apps/raggio_schema/lib/raggio_schema/schema.ex with Schema struct per data-model.md
- [ ] T023 [P] [US1] Create apps/raggio_schema/lib/raggio_schema/filter.ex with Filter struct per data-model.md
- [ ] T024 [P] [US1] Create apps/raggio_schema/lib/raggio_schema/validation_result.ex per data-model.md
- [ ] T025 [P] [US1] Create apps/raggio_schema/lib/raggio_schema/validation_error.ex per data-model.md

### Type Constructors (can run in parallel)

- [ ] T026 [P] [US1] Implement Raggio.Schema.string/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T027 [P] [US1] Implement Raggio.Schema.integer/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T028 [P] [US1] Implement Raggio.Schema.float/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T029 [P] [US1] Implement Raggio.Schema.boolean/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T030 [P] [US1] Implement Raggio.Schema.date/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T031 [P] [US1] Implement Raggio.Schema.datetime/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T032 [P] [US1] Implement Raggio.Schema.decimal/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T033 [P] [US1] Implement Raggio.Schema.atom/0 in apps/raggio_schema/lib/raggio_schema.ex

### Composite Types (can run in parallel after T026-T033)

- [ ] T034 [P] [US1] Implement Raggio.Schema.struct/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T035 [P] [US1] Implement Raggio.Schema.list/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T036 [P] [US1] Implement Raggio.Schema.map/0 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T037 [P] [US1] Implement Raggio.Schema.union/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T038 [P] [US1] Implement Raggio.Schema.enum/1 in apps/raggio_schema/lib/raggio_schema.ex

### String Constraints (can run in parallel)

- [ ] T039 [P] [US1] Implement Raggio.Schema.min_length/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T040 [P] [US1] Implement Raggio.Schema.max_length/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T041 [P] [US1] Implement Raggio.Schema.pattern/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T042 [P] [US1] Implement Raggio.Schema.email/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T043 [P] [US1] Implement Raggio.Schema.url/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T044 [P] [US1] Implement Raggio.Schema.uuid/1 in apps/raggio_schema/lib/raggio_schema.ex

### Number Constraints (can run in parallel)

- [ ] T045 [P] [US1] Implement Raggio.Schema.min/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T046 [P] [US1] Implement Raggio.Schema.max/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T047 [P] [US1] Implement Raggio.Schema.positive/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T048 [P] [US1] Implement Raggio.Schema.negative/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T049 [P] [US1] Implement Raggio.Schema.range/3 in apps/raggio_schema/lib/raggio_schema.ex

### Collection Constraints (can run in parallel)

- [ ] T050 [P] [US1] Implement Raggio.Schema.min_items/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T051 [P] [US1] Implement Raggio.Schema.max_items/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T052 [P] [US1] Implement Raggio.Schema.unique/1 in apps/raggio_schema/lib/raggio_schema.ex

### Modifier Functions (can run in parallel)

- [ ] T053 [P] [US1] Implement Raggio.Schema.optional/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T054 [P] [US1] Implement Raggio.Schema.nullable/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T055 [P] [US1] Implement Raggio.Schema.default/2 in apps/raggio_schema/lib/raggio_schema.ex

### Validation Engine

- [ ] T056 [US1] Create apps/raggio_schema/lib/raggio_schema/validator.ex with validation logic per data-model.md
- [ ] T057 [US1] Implement Raggio.Schema.validate/2 in apps/raggio_schema/lib/raggio_schema.ex (depends on T056)
- [ ] T058 [US1] Implement Raggio.Schema.validate!/2 in apps/raggio_schema/lib/raggio_schema.ex

### Metadata and Custom Constraints

- [ ] T059 [P] [US1] Implement Raggio.Schema.annotate/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T060 [P] [US1] Implement Raggio.Schema.constraint/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T061 [P] [US1] Define Raggio.Schema.Constraint protocol in apps/raggio_schema/lib/raggio_schema/constraint.ex
- [ ] T062 [P] [US1] Implement Raggio.Schema.Constraint for Function in apps/raggio_schema/lib/raggio_schema/constraint.ex
- [ ] T063 [P] [US1] Implement Raggio.Schema.Constraint for Regex in apps/raggio_schema/lib/raggio_schema/constraint.ex

### Package Tests (US1 acceptance scenario verification)

- [ ] T064 [P] [US1] Create apps/raggio_schema/test/raggio_schema_test.exs with basic type tests
- [ ] T065 [P] [US1] Create apps/raggio_schema/test/types_test.exs with all type constructor tests
- [ ] T066 [P] [US1] Create apps/raggio_schema/test/constraints_test.exs with constraint tests
- [ ] T067 [P] [US1] Create apps/raggio_schema/test/validation_test.exs with validation tests (US1 acceptance 3, 4)
- [ ] T068 [US1] Run `mix test` in apps/raggio_schema/ to verify all tests pass

**Checkpoint**: At this point, User Story 1 should be fully functional - developer can define schemas and validate data

---

## Phase 4: User Story 3 - Developer learns through working examples (Priority: P1)

**Goal**: Working examples for Raggio.Schema demonstrating common patterns

**Independent Test**: Navigate to examples directory, run any example, verify it compiles and executes successfully

### Example Directory Structure

- [ ] T069 [P] [US3] Create examples/raggio_schema/basic_validation/ directory
- [ ] T070 [P] [US3] Create examples/raggio_schema/composite_types/ directory
- [ ] T071 [P] [US3] Create examples/raggio_schema/constraints/ directory
- [ ] T072 [P] [US3] Create examples/raggio_schema/composition/ directory

### Basic Validation Examples (can run in parallel)

- [ ] T073 [P] [US3] Create examples/raggio_schema/basic_validation/simple_schema.exs demonstrating US1 acceptance scenario 2
- [ ] T074 [P] [US3] Create examples/raggio_schema/basic_validation/type_validation.exs showing all primitive types
- [ ] T075 [P] [US3] Create examples/raggio_schema/basic_validation/error_handling.exs showing US1 acceptance scenario 4

### Composite Type Examples (can run in parallel)

- [ ] T076 [P] [US3] Create examples/raggio_schema/composite_types/struct_validation.exs showing nested structs
- [ ] T077 [P] [US3] Create examples/raggio_schema/composite_types/list_validation.exs showing list types
- [ ] T078 [P] [US3] Create examples/raggio_schema/composite_types/union_types.exs showing union types

### Constraint Examples (can run in parallel)

- [ ] T079 [P] [US3] Create examples/raggio_schema/constraints/string_constraints.exs showing min_length, max_length, pattern
- [ ] T080 [P] [US3] Create examples/raggio_schema/constraints/number_constraints.exs showing min, max, range
- [ ] T081 [P] [US3] Create examples/raggio_schema/constraints/custom_constraints.exs showing constraint/2 usage

### Composition Examples (US4 related, can run in parallel)

- [ ] T082 [P] [US3] Create examples/raggio_schema/composition/reusable_schemas.exs showing composable patterns
- [ ] T083 [P] [US3] Create examples/raggio_schema/composition/combinator_pattern.exs showing validator composition
- [ ] T084 [P] [US3] Create examples/raggio_schema/composition/protocol_extension.exs showing Constraint protocol

### Automated Example Test

- [ ] T085 [US3] Create test/example_test.exs with automated verification of all examples per FR-009
- [ ] T086 [US3] Run `mix test test/example_test.exs` and verify all Raggio.Schema examples pass (US3 acceptance 2)

**Checkpoint**: At this point, User Story 3 (for Raggio.Schema) should be complete - developers can learn from working examples

---

## Phase 5: User Story 2 - Developer uses Raggio.Syntax for syntax manipulation (Priority: P2)

**Goal**: Syntax tree construction, traversal, and transformation functionality

**Independent Test**: Install Raggio.Syntax, create syntax nodes, traverse with combinators, transform successfully

### Core Syntax Structure

- [ ] T087 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/syntax_tree.ex with SyntaxTree struct per data-model.md
- [ ] T088 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node.ex with base Node protocol per data-model.md
- [ ] T089 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/ directory for node types

### Node Type Structures (can run in parallel)

- [ ] T090 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/schema_node.ex with SchemaNode struct per data-model.md
- [ ] T091 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/field_node.ex with FieldNode struct per data-model.md
- [ ] T092 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/type_node.ex with TypeNode struct per data-model.md
- [ ] T093 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/transform_node.ex with TransformNode struct per data-model.md

### Node Construction Functions (can run in parallel after T090-T093)

- [ ] T094 [P] [US2] Implement Raggio.Syntax.schema/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T095 [P] [US2] Implement Raggio.Syntax.schema/2 (named variant) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T096 [P] [US2] Implement Raggio.Syntax.field/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T097 [P] [US2] Implement Raggio.Syntax.field/3 (with options) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T098 [P] [US2] Implement Raggio.Syntax.type/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T099 [P] [US2] Implement Raggio.Syntax.type/2 (generic variant) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T100 [P] [US2] Implement Raggio.Syntax.transform_node/2 in apps/raggio_syntax/lib/raggio_syntax.ex

### Syntax Tree Construction (can run in parallel)

- [ ] T101 [P] [US2] Implement Raggio.Syntax.ast/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T102 [P] [US2] Implement Raggio.Syntax.ast/2 (with metadata) in apps/raggio_syntax/lib/raggio_syntax.ex

### Traversal Functions (US2 acceptance scenario 3)

- [ ] T103 [US2] Create apps/raggio_syntax/lib/raggio_syntax/traversal.ex with traversal logic per data-model.md
- [ ] T104 [US2] Implement Raggio.Syntax.traverse/2 (depth-first) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T105 [US2] Implement Raggio.Syntax.traverse/3 (with accumulator) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T106 [US2] Implement Raggio.Syntax.traverse_breadth_first/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T107 [P] [US2] Implement Raggio.Syntax.find/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T108 [P] [US2] Implement Raggio.Syntax.find_all/2 in apps/raggio_syntax/lib/raggio_syntax.ex

### Transformation Functions (US2 acceptance scenario 2)

- [ ] T109 [US2] Create apps/raggio_syntax/lib/raggio_syntax/transformer.ex with transformation logic per data-model.md
- [ ] T110 [US2] Implement Raggio.Syntax.transform/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T111 [P] [US2] Implement Raggio.Syntax.map/2 (alias for transform) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T112 [P] [US2] Implement Raggio.Syntax.filter/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T113 [P] [US2] Implement Raggio.Syntax.replace/3 in apps/raggio_syntax/lib/raggio_syntax.ex

### Query Functions (can run in parallel)

- [ ] T114 [P] [US2] Implement Raggio.Syntax.get_fields/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T115 [P] [US2] Implement Raggio.Syntax.get_field/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T116 [P] [US2] Implement Raggio.Syntax.get_type/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T117 [P] [US2] Implement Raggio.Syntax.get_children/1 in apps/raggio_syntax/lib/raggio_syntax.ex

### Package Tests (US2 acceptance scenario verification)

- [ ] T118 [P] [US2] Create apps/raggio_syntax/test/raggio_syntax_test.exs with basic node creation test
- [ ] T119 [P] [US2] Create apps/raggio_syntax/test/builder_test.exs with node composition test (US2 acceptance 1)
- [ ] T120 [P] [US2] Create apps/raggio_syntax/test/traversal_test.exs with traversal test (US2 acceptance 3)
- [ ] T121 [P] [US2] Create apps/raggio_syntax/test/transformer_test.exs with transformation test (US2 acceptance 2)
- [ ] T122 [US2] Run `mix test` in apps/raggio_syntax/ to verify all tests pass

**Checkpoint**: At this point, User Story 2 should be fully functional - developer can build, traverse, transform syntax trees

---

## Phase 6: User Story 3 (continued) - Examples for Raggio.Syntax (Priority: P1/P2)

**Goal**: Provide working examples for Raggio.Syntax (completing US3 for both packages)

**Note**: This continues US3 but for the P2 package (Raggio.Syntax)

### Example Directory Structure

- [ ] T123 [P] [US3] Create examples/raggio_syntax/syntax_building/ directory
- [ ] T124 [P] [US3] Create examples/raggio_syntax/traversal/ directory
- [ ] T125 [P] [US3] Create examples/raggio_syntax/transformation/ directory
- [ ] T126 [P] [US3] Create examples/raggio_syntax/advanced/ directory

### Syntax Building Examples (per quickstart.md, can run in parallel)

- [ ] T127 [P] [US3] Create examples/raggio_syntax/syntax_building/simple_syntax.exs demonstrating US2 acceptance scenario 1
- [ ] T128 [P] [US3] Create examples/raggio_syntax/syntax_building/complex_schema.exs showing nested structures
- [ ] T129 [P] [US3] Create examples/raggio_syntax/syntax_building/node_composition.exs showing composing nodes

### Traversal Examples (can run in parallel)

- [ ] T130 [P] [US3] Create examples/raggio_syntax/traversal/depth_first.exs showing DFS traversal per data-model.md
- [ ] T131 [P] [US3] Create examples/raggio_syntax/traversal/visitor_pattern.exs showing visitor combinators
- [ ] T132 [P] [US3] Create examples/raggio_syntax/traversal/filtering.exs showing find/find_all usage

### Transformation Examples (can run in parallel)

- [ ] T133 [P] [US3] Create examples/raggio_syntax/transformation/modify_nodes.exs showing transform function
- [ ] T134 [P] [US3] Create examples/raggio_syntax/transformation/rewrite_rules.exs showing syntax rewriting
- [ ] T135 [P] [US3] Create examples/raggio_syntax/transformation/optimization.exs showing optimization patterns

### Advanced Examples (can run in parallel)

- [ ] T136 [P] [US3] Create examples/raggio_syntax/advanced/code_generation.exs showing code gen patterns
- [ ] T137 [P] [US3] Create examples/raggio_syntax/advanced/analysis.exs showing syntax analysis

### Automated Example Test Update

- [ ] T138 [US3] Update test/example_test.exs to include Raggio.Syntax example verification
- [ ] T139 [US3] Run `mix test test/example_test.exs` and verify all examples (both packages) pass

**Checkpoint**: At this point, User Story 3 is fully complete - working examples for both packages

---

## Phase 7: User Story 4 - Developer extends functionality through composition (Priority: P2)

**Goal**: Demonstrate composability through advanced examples and protocol extensions

**Independent Test**: Create custom composite function using public API, verify it works without library modifications

### Composability Examples (can run in parallel)

- [ ] T140 [P] [US4] Create examples/raggio_schema/composition/custom_validators.exs demonstrating composable validators (US4 acceptance 1)
- [ ] T141 [P] [US4] Create examples/raggio_schema/composition/domain_constraints.exs showing domain-specific composition
- [ ] T142 [P] [US4] Create examples/raggio_syntax/advanced/custom_transformers.exs demonstrating composable transformers (US4 acceptance 1)
- [ ] T143 [P] [US4] Create examples/raggio_syntax/advanced/combinator_patterns.exs showing transformation composition

### Advanced Composition Utilities (optional, for power users)

- [ ] T144 [P] [US4] Create apps/raggio_schema/lib/raggio_schema/combinators.ex with all/1, any/1, optional/1 functions
- [ ] T145 [P] [US4] Create apps/raggio_syntax/lib/raggio_syntax/combinators.ex with composition helpers

### Verification

- [ ] T146 [US4] Run examples demonstrating composability without library modification (US4 acceptance 1, 2)
- [ ] T147 [US4] Verify 90% of use cases work without macros (SC-004)

**Checkpoint**: At this point, User Story 4 is complete - composability validated through examples

---

## Phase 8: User Story 5 - Developer exports schema to BigQuery (Priority: P2)

**Goal**: BigQuery DDL export adapter for Raggio.Schema

**Independent Test**: Define Raggio.Schema, export to BigQuery DDL, verify generated SQL is valid

### BigQuery Exporter Implementation

- [ ] T148 [US5] Create apps/raggio_schema/lib/raggio_schema/adapters/ directory
- [ ] T149 [US5] Create apps/raggio_schema/lib/raggio_schema/adapters/bigquery.ex per adapters.md contract
- [ ] T150 [US5] Implement Raggio.Schema.Exporter.BigQuery.to_ddl/2 per contracts/adapters.md (US5 acceptance 1)
- [ ] T151 [US5] Implement Raggio.Schema.Exporter.BigQuery.to_ddl/3 with options (partition_by, cluster_by)
- [ ] T152 [US5] Implement type mapping function (Schema types → BigQuery types) per research.md
- [ ] T153 [US5] Implement STRUCT/ARRAY handling for nested schemas (US5 acceptance 3)
- [ ] T154 [US5] Implement constraint mapping (required → NOT NULL) (US5 acceptance 2)

### BigQuery Exporter Tests

- [ ] T155 [P] [US5] Create apps/raggio_schema/test/adapters/bigquery_test.exs with type mapping tests
- [ ] T156 [P] [US5] Add nested structure tests to bigquery_test.exs (US5 acceptance 3)
- [ ] T157 [P] [US5] Add constraint mapping tests to bigquery_test.exs (US5 acceptance 2)
- [ ] T158 [US5] Run `mix test apps/raggio_schema/test/adapters/bigquery_test.exs`

### BigQuery Examples

- [ ] T159 [P] [US5] Create examples/raggio_schema/adapters/bigquery_export.exs demonstrating DDL generation (US5 acceptance 1)
- [ ] T160 [P] [US5] Create examples/raggio_schema/adapters/bigquery_nested.exs showing nested schemas

**Checkpoint**: At this point, User Story 5 is complete - BigQuery export working

---

## Phase 9: User Story 6 - Developer imports schema from SheetSchema (Priority: P2)

**Goal**: SheetSchema spreadsheet importer adapter for Raggio.Schema

**Independent Test**: Provide SheetSchema spreadsheet, import to Raggio.Schema code, verify generated code compiles

### SheetSchema Importer Implementation

- [ ] T161 [US6] Create apps/raggio_schema/lib/raggio_schema/adapters/sheet_schema.ex per adapters.md contract
- [ ] T162 [US6] Implement Raggio.Schema.Importer.SheetSchema.from_csv/1 per contracts/adapters.md (US6 acceptance 1)
- [ ] T163 [US6] Implement Raggio.Schema.Importer.SheetSchema.from_csv/2 with options
- [ ] T164 [US6] Implement CSV parsing with column validation per research.md SheetSchema format
- [ ] T165 [US6] Implement type parser (string type syntax → Schema types) (US6 acceptance 2)
- [ ] T166 [US6] Implement constraint parser (pipe-separated constraints → Schema functions) (US6 acceptance 3)
- [ ] T167 [US6] Implement nesting resolution (parent_path → nested structs) per research.md
- [ ] T168 [US6] Implement code generation using Raggio.Syntax for correctness
- [ ] T169 [US6] Implement Raggio.Schema.Importer.SheetSchema.validate/1 for format validation
- [ ] T170 [US6] Implement Raggio.Schema.Importer.SheetSchema.from_url/1 for Google Sheets integration (optional)
- [ ] T171 [US6] Implement Raggio.Schema.Importer.SheetSchema.from_url/2 with options (optional)

### SheetSchema Importer Tests

- [ ] T172 [P] [US6] Create apps/raggio_schema/test/adapters/sheet_schema_test.exs with CSV parsing tests
- [ ] T173 [P] [US6] Add type parsing tests to sheet_schema_test.exs (US6 acceptance 2)
- [ ] T174 [P] [US6] Add constraint parsing tests to sheet_schema_test.exs (US6 acceptance 3)
- [ ] T175 [P] [US6] Add nesting tests to sheet_schema_test.exs
- [ ] T176 [P] [US6] Add validation tests to sheet_schema_test.exs
- [ ] T177 [US6] Run `mix test apps/raggio_schema/test/adapters/sheet_schema_test.exs`

### SheetSchema Examples

- [ ] T178 [P] [US6] Create test fixtures: examples/raggio_schema/adapters/fixtures/user_schema.csv with sample SheetSchema
- [ ] T179 [P] [US6] Create examples/raggio_schema/adapters/sheet_import.exs demonstrating CSV import (US6 acceptance 1)
- [ ] T180 [P] [US6] Create examples/raggio_schema/adapters/sheet_nested.exs showing nested structure import

**Checkpoint**: At this point, User Story 6 is complete - SheetSchema import working

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Final touches, documentation, and release preparation

### Documentation

- [ ] T181 [P] Create apps/raggio_schema/README.md with overview, installation, quickstart
- [ ] T182 [P] Create apps/raggio_syntax/README.md with overview, installation, quickstart
- [ ] T183 [P] Create root README.md with umbrella project overview and links to package READMEs
- [ ] T184 [P] Update apps/raggio_schema/lib/raggio_schema.ex with module-level documentation (no function docs per FR-005)
- [ ] T185 [P] Update apps/raggio_syntax/lib/raggio_syntax.ex with module-level documentation (no function docs per FR-005)

### Code Quality

- [ ] T186 Run `mix format` from root to format all code
- [ ] T187 Run `mix compile --warnings-as-errors` to check for warnings
- [ ] T188 Run `mix test --cover` from root to verify test coverage
- [ ] T189 Verify no circular dependencies: confirm apps/raggio_schema/mix.exs does NOT depend on raggio_syntax (FR-004)

### Success Criteria Verification

- [ ] T190 Verify SC-001: Clone repo and compile all packages within 5 minutes
- [ ] T191 Verify SC-002: Run any example and see output within 30 seconds
- [ ] T192 Verify SC-003: Test independent package usage (create test project with only raggio_schema dependency)
- [ ] T193 Verify SC-004: Confirm 90% of use cases work without macros (review examples)
- [ ] T194 Verify SC-005: Confirm umbrella structure matches Ecto/Phoenix patterns (apps/, mix.exs structure)
- [ ] T195 Verify SC-006: Verify developers can learn from examples without extensive docs

### Final Validation

- [ ] T196 Run full test suite: `mix test` from root
- [ ] T197 Run example verification: `mix test test/example_test.exs`
- [ ] T198 Verify all user stories have acceptance criteria met (US1-US6)

---

## Task Statistics

**Total Tasks**: 198

**Tasks by User Story**:
- Setup (Phase 1): 10 tasks
- Foundational (Phase 2): 11 tasks
- US1 (Schema core): 47 tasks
- US3 (Schema examples): 18 tasks
- US2 (Syntax core): 36 tasks
- US3 (Syntax examples): 17 tasks
- US4 (Composability): 8 tasks
- US5 (BigQuery export): 13 tasks
- US6 (SheetSchema import): 20 tasks
- Polish: 18 tasks

**Parallel Opportunities**: 142 tasks marked [P] can run in parallel within their phase

---

## Dependencies & Story Completion Order

### Story Dependencies

```
Phase 1 (Setup) 
  ↓
Phase 2 (Foundational)
  ↓
├─→ Phase 3: US1 (Schema core) ← MVP
│     ↓
├─→ Phase 4: US3 (Schema examples)
│
├─→ Phase 5: US2 (Syntax core) ← Depends on US1 (in_umbrella dependency)
│     ↓
├─→ Phase 6: US3 (Syntax examples)
│
├─→ Phase 7: US4 (Composability) ← Depends on US1 + US2
│
├─→ Phase 8: US5 (BigQuery) ← Depends on US1
│
├─→ Phase 9: US6 (SheetSchema) ← Depends on US1 (and US2 for code gen)
  ↓
Phase 10 (Polish)
```

### Parallel Execution Examples

**After Foundational phase complete:**

- **Parallel Track 1**: US1 tasks (T022-T068)
- **Parallel Track 2**: US3 Schema examples preparation (T069-T072) - can prep directories early

**After US1 complete:**

- **Parallel Track 1**: US3 Schema examples (T073-T086)
- **Parallel Track 2**: US5 BigQuery exporter (T148-T160)
- **Parallel Track 3**: US2 Syntax core (T087-T122) - if dependency on US1 is minimal

**After US2 complete:**

- **Parallel Track 1**: US3 Syntax examples (T123-T139)
- **Parallel Track 2**: US6 SheetSchema importer (T161-T180)
- **Parallel Track 3**: US4 Composability examples (T140-T147)

---

## Implementation Strategy

### MVP (Minimum Viable Product)

**Scope**: Complete Phase 1-4 (Setup + Foundational + US1 + US3 Schema examples)

**Delivers**:
- ✅ Working Raggio.Schema package with full validation functionality
- ✅ Working examples demonstrating all patterns
- ✅ Automated example verification
- ✅ Independent compilation and testing

**Test**: A developer can install Raggio.Schema, define schemas, validate data, and learn from examples

**Estimated Tasks**: ~86 tasks (43% of total)

### Incremental Delivery

1. **MVP** (Phases 1-4): Raggio.Schema + examples
2. **Increment 2** (Phase 5-6): Add Raggio.Syntax + examples
3. **Increment 3** (Phase 7): Validate composability
4. **Increment 4** (Phases 8-9): Add adapters (BigQuery + SheetSchema)
5. **Increment 5** (Phase 10): Polish and release

Each increment is independently testable and delivers value.

---

## Format Validation

✅ **All tasks follow checklist format**:
- Checkbox: `- [ ]`
- Task ID: Sequential (T001-T198)
- [P] marker: 142 tasks marked for parallel execution
- [Story] label: All US tasks properly labeled (US1-US6)
- File paths: Included in all implementation task descriptions

✅ **Task organization by user story**: Each story has complete implementation path with tests

✅ **Independent test criteria**: Each phase has checkpoint verifying story works independently

---

*Tasks ready for implementation. Execute in order respecting dependencies, or parallelize within phases as marked.*
