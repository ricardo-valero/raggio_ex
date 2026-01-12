# Tasks: Multi-Package Monorepo Restructure

**Input**: Design documents from `/specs/001-monorepo-restructure/`
**Prerequisites**: plan.md (complete), spec.md (complete), research.md (complete), data-model.md (complete), contracts/ (complete)

**Tests**: Tests are NOT explicitly requested in specification. Focus on example verification instead.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Per plan.md, this is an Elixir umbrella project:
- **Umbrella root**: `mix.exs`, `config/config.exs`
- **Package**: `apps/raggio_schema/`, `apps/raggio_syntax/`
- **Example**: `examples/raggio_schema/`, `examples/raggio_syntax/`
- **Test**: `test/example_test.exs` (root), package test in respective app

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize Elixir umbrella project structure and shared tooling

- [x] T001 Create root umbrella mix.exs file with apps_path, version 0.1.0, and Mix alias
- [x] T002 Create config/config.exs for shared configuration
- [x] T003 [P] Create .formatter.exs at root with umbrella configuration
- [x] T004 [P] Create .gitignore with Elixir/Mix ignore pattern (_build, deps, mix.lock artifacts)
- [x] T005 [P] Create apps/ directory for umbrella application
- [x] T006 [P] Create examples/ directory with two-level hierarchy structure
- [x] T007 [P] Create test/ directory for example verification test
- [x] T008 [P] Create README.md at root explaining umbrella structure and setup
- [x] T009 [P] Create LICENSE file (MIT per research.md package configuration)
- [x] T010 Verify umbrella structure match plan.md and compile successfully

**Checkpoint**: Umbrella project structure complete and compiling

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core package structure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until both package skeleton are created

- [x] T011 Create apps/raggio_schema directory structure (lib, test, README.md)
- [x] T012 [P] Create apps/raggio_schema/mix.exs with package configuration per research.md
- [x] T013 [P] Create apps/raggio_schema/.formatter.exs with package-specific rule
- [x] T014 [P] Create apps/raggio_schema/test/test_helper.exs
- [x] T015 [P] Create apps/raggio_schema/README.md with package purpose (module-level only)
- [x] T016 Create apps/raggio_syntax directory structure (lib, test, README.md)
- [x] T017 [P] Create apps/raggio_syntax/mix.exs with package configuration per research.md
- [x] T018 [P] Create apps/raggio_syntax/.formatter.exs with package-specific rule
- [x] T019 [P] Create apps/raggio_syntax/test/test_helper.exs
- [x] T020 [P] Create apps/raggio_syntax/README.md with package purpose (module-level only)
- [x] T021 Run mix deps.get and mix compile to verify both package compile independently

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Developer imports and uses Raggio.Schema package (Priority: P1) 🎯 MVP

**Goal**: Enable developer to define schema with composable API and validate data without macro

**Independent Test**: Install Raggio.Schema as dependency, define simple schema (user with name/age), validate data successfully, handle validation error with clear message

### Core Schema Structure

- [x] T022 [P] [US1] Create apps/raggio_schema/lib/raggio_schema.ex entry point with module doc (purpose only)
- [x] T023 [P] [US1] Create apps/raggio_schema/lib/raggio_schema/schema.ex with Schema struct per data-model.md
- [x] T024 [P] [US1] Create apps/raggio_schema/lib/raggio_schema/error.ex with ValidationError and CompositionError struct

### Primitive Type Function (can run in parallel)

- [x] T025 [P] [US1] Implement Raggio.Schema.string/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T026 [P] [US1] Implement Raggio.Schema.integer/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T027 [P] [US1] Implement Raggio.Schema.float/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T028 [P] [US1] Implement Raggio.Schema.boolean/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T029 [P] [US1] Implement Raggio.Schema.date/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T030 [P] [US1] Implement Raggio.Schema.datetime/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T031 [P] [US1] Implement Raggio.Schema.decimal/0 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T032 [P] [US1] Implement Raggio.Schema.atom/0 in apps/raggio_schema/lib/raggio_schema.ex

### Composite Type Function

- [x] T033 [US1] Implement Raggio.Schema.array/1 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T034 [US1] Implement Raggio.Schema.struct/1 in apps/raggio_schema/lib/raggio_schema.ex (core for user story)
- [x] T035 [US1] Implement Raggio.Schema.enum/1 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T036 [US1] Implement Raggio.Schema.union/1 in apps/raggio_schema/lib/raggio_schema.ex

### Validation Core

- [x] T037 [US1] Create apps/raggio_schema/lib/raggio_schema/validator.ex with validation logic per data-model.md
- [x] T038 [US1] Implement Raggio.Schema.validate/2 in apps/raggio_schema/lib/raggio_schema.ex (core validation function)
- [x] T039 [US1] Implement Raggio.Schema.validate!/2 in apps/raggio_schema/lib/raggio_schema.ex (raising variant)
- [x] T040 [US1] Add error accumulation logic per research.md Pattern 3

### String Constraint (compose with pipe operator)

- [x] T041 [P] [US1] Implement Raggio.Schema.min_length/2 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T042 [P] [US1] Implement Raggio.Schema.max_length/2 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T043 [P] [US1] Implement Raggio.Schema.pattern/2 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T044 [P] [US1] Implement Raggio.Schema.email/1 in apps/raggio_schema/lib/raggio_schema.ex

### Numeric Constraint

- [x] T045 [P] [US1] Implement Raggio.Schema.min/2 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T046 [P] [US1] Implement Raggio.Schema.max/2 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T047 [P] [US1] Implement Raggio.Schema.positive/1 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T048 [P] [US1] Implement Raggio.Schema.range/3 in apps/raggio_schema/lib/raggio_schema.ex

### Composition Function

- [x] T049 [US1] Implement Raggio.Schema.compose/2 with type compatibility check per clarification (composition-time error)
- [x] T050 [US1] Implement Raggio.Schema.optional/1 in apps/raggio_schema/lib/raggio_schema.ex
- [x] T051 [US1] Implement Raggio.Schema.default/2 in apps/raggio_schema/lib/raggio_schema.ex

### Package Test (US1 acceptance scenario verification)

- [x] T052 [US1] Create apps/raggio_schema/test/raggio_schema_test.exs with basic type creation test
- [x] T053 [US1] Create apps/raggio_schema/test/validator_test.exs with validation test (valid data succeed, invalid fail)
- [x] T054 [US1] Create apps/raggio_schema/test/composition_test.exs with pipe operator composition test
- [x] T055 [US1] Create apps/raggio_schema/test/error_test.exs with composition-time error test
- [x] T056 [US1] Run mix test in apps/raggio_schema to verify all test pass

**Checkpoint**: At this point, User Story 1 should be fully functional - developer can define schema, validate data, handle error

---

## Phase 4: User Story 3 - Developer learns through working examples (Priority: P1) 🎯 MVP

**Goal**: Provide working, compilable example as primary documentation for Raggio.Schema

**Independent Test**: Navigate to examples directory, run any example with elixir command, observe compilation and execution success with clear output

**Note**: US3 depends on US1 completion but is also P1 priority (both are MVP)

### Example Directory Structure

- [x] T057 [P] [US3] Create examples/raggio_schema/basic_validation/ directory
- [x] T058 [P] [US3] Create examples/raggio_schema/composition/ directory
- [ ] T059 [P] [US3] Create examples/raggio_schema/transformation/ directory (SKIPPED - no transformation implemented yet)
- [ ] T060 [P] [US3] Create examples/raggio_schema/advanced/ directory (SKIPPED - covered in basic_validation)

### Basic Validation Example (per quickstart.md)

- [x] T061 [P] [US3] Create examples/raggio_schema/basic_validation/simple_schema.exs demonstrating US1 acceptance scenario 2-4
- [x] T062 [P] [US3] Create examples/raggio_schema/basic_validation/nested_schema.exs showing struct within struct
- [x] T063 [P] [US3] Create examples/raggio_schema/basic_validation/validation_error.exs showing error handling pattern
- [x] T063a [P] [US3] Create examples/raggio_schema/basic_validation/array_validation.exs showing array validation
- [x] T063b [P] [US3] Create examples/raggio_schema/basic_validation/enum_union.exs showing enum and union types
- [x] T063c [P] [US3] Create examples/raggio_schema/basic_validation/optional_default.exs showing optional fields and defaults

### Composition Example

- [x] T064 [P] [US3] Create examples/raggio_schema/composition/combine_validator.exs showing pipe operator composition
- [x] T065 [P] [US3] Create examples/raggio_schema/composition/custom_type.exs showing reusable schema pattern
- [x] T066 [P] [US3] Create examples/raggio_schema/composition/reusable_schema.exs per quickstart.md pattern

### Transformation Example

- [ ] T067 [P] [US3] Create examples/raggio_schema/transformation/data_mapping.exs if transformer implemented (SKIPPED - not in MVP)
- [ ] T068 [P] [US3] Create examples/raggio_schema/transformation/coercion.exs showing type coercion (SKIPPED - not in MVP)

### Advanced Example

- [ ] T069 [P] [US3] Create examples/raggio_schema/advanced/conditional_validation.exs showing conditional logic (SKIPPED - not in MVP)
- [ ] T070 [P] [US3] Create examples/raggio_schema/advanced/cross_field.exs showing cross-field validation (SKIPPED - not in MVP)

### Automated Example Test (per research.md and clarification)

- [x] T071 [US3] Create test/example_test.exs implementing automated example verification per research.md
- [ ] T072 [US3] Add ExUnit test that discover all example file in examples/**/*.exs
- [ ] T073 [US3] Add execution check verifying exit code 0 for each example
- [ ] T074 [US3] Run mix test test/example_test.exs and verify all Raggio.Schema example pass

**Checkpoint**: At this point, User Story 3 should be complete - developer can learn from working example

---

## Phase 5: User Story 2 - Developer uses Raggio.Syntax for AST manipulation (Priority: P2)

**Goal**: Enable developer to construct, traverse, and transform AST using composable function

**Independent Test**: Install Raggio.Syntax, create AST node programmatically, traverse with combinator, transform structure successfully

### Core AST Structure

- [ ] T075 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax.ex entry point with module doc (purpose only)
- [ ] T076 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/ast.ex with AST struct per data-model.md
- [ ] T077 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node.ex with base Node protocol

### Node Type Structure (can run in parallel)

- [ ] T078 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/field.ex with FieldNode struct per data-model.md
- [ ] T079 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/schema.ex with SchemaNode struct per data-model.md
- [ ] T080 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/type.ex with TypeNode struct per data-model.md
- [ ] T081 [P] [US2] Create apps/raggio_syntax/lib/raggio_syntax/node/transform.ex with TransformNode struct per data-model.md

### Node Construction Function

- [ ] T082 [P] [US2] Implement Raggio.Syntax.field/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T083 [P] [US2] Implement Raggio.Syntax.field/3 in apps/raggio_syntax/lib/raggio_syntax.ex (with option)
- [ ] T084 [P] [US2] Implement Raggio.Syntax.schema/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T085 [P] [US2] Implement Raggio.Syntax.schema/2 in apps/raggio_syntax/lib/raggio_syntax.ex (named variant)
- [ ] T086 [P] [US2] Implement Raggio.Syntax.type/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T087 [P] [US2] Implement Raggio.Syntax.type/2 in apps/raggio_syntax/lib/raggio_syntax.ex (generic variant)

### AST Construction

- [ ] T088 [P] [US2] Implement Raggio.Syntax.ast/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T089 [P] [US2] Implement Raggio.Syntax.ast/2 in apps/raggio_syntax/lib/raggio_syntax.ex (with metadata)

### Traversal Function (US2 acceptance scenario 3)

- [ ] T090 [US2] Create apps/raggio_syntax/lib/raggio_syntax/traversal.ex with traversal logic per data-model.md
- [ ] T091 [US2] Implement Raggio.Syntax.traverse/2 (depth-first) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T092 [US2] Implement Raggio.Syntax.traverse/3 (with accumulator) in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T093 [US2] Implement Raggio.Syntax.traverse_breadth_first/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T094 [P] [US2] Implement Raggio.Syntax.find/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T095 [P] [US2] Implement Raggio.Syntax.find_all/2 in apps/raggio_syntax/lib/raggio_syntax.ex

### Transformation Function (US2 acceptance scenario 2)

- [ ] T096 [US2] Create apps/raggio_syntax/lib/raggio_syntax/transformer.ex with transformation logic per data-model.md
- [ ] T097 [US2] Implement Raggio.Syntax.transform/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T098 [P] [US2] Implement Raggio.Syntax.map/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T099 [P] [US2] Implement Raggio.Syntax.filter/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T100 [P] [US2] Implement Raggio.Syntax.replace/3 in apps/raggio_syntax/lib/raggio_syntax.ex

### Query Function

- [ ] T101 [P] [US2] Implement Raggio.Syntax.get_fields/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T102 [P] [US2] Implement Raggio.Syntax.get_field/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T103 [P] [US2] Implement Raggio.Syntax.get_type/1 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T104 [P] [US2] Implement Raggio.Syntax.get_children/1 in apps/raggio_syntax/lib/raggio_syntax.ex

### Package Test (US2 acceptance scenario verification)

- [ ] T105 [P] [US2] Create apps/raggio_syntax/test/raggio_syntax_test.exs with basic node creation test
- [ ] T106 [P] [US2] Create apps/raggio_syntax/test/builder_test.exs with node composition test (US2 acceptance 1)
- [ ] T107 [P] [US2] Create apps/raggio_syntax/test/traversal_test.exs with traversal test (US2 acceptance 3)
- [ ] T108 [P] [US2] Create apps/raggio_syntax/test/transformer_test.exs with transformation test (US2 acceptance 2)
- [ ] T109 [US2] Run mix test in apps/raggio_syntax to verify all test pass

**Checkpoint**: At this point, User Story 2 should be fully functional - developer can build, traverse, transform AST

---

## Phase 6: User Story 3 (continued) - Examples for Raggio.Syntax (Priority: P1/P2)

**Goal**: Provide working example for Raggio.Syntax (completing US3 for both package)

**Note**: This continue US3 but for the P2 package (Raggio.Syntax)

### Example Directory Structure

- [ ] T110 [P] [US3] Create examples/raggio_syntax/ast_building/ directory
- [ ] T111 [P] [US3] Create examples/raggio_syntax/traversal/ directory
- [ ] T112 [P] [US3] Create examples/raggio_syntax/transformation/ directory
- [ ] T113 [P] [US3] Create examples/raggio_syntax/advanced/ directory

### AST Building Example (per quickstart.md)

- [ ] T114 [P] [US3] Create examples/raggio_syntax/ast_building/simple_ast.exs demonstrating US2 acceptance scenario 1
- [ ] T115 [P] [US3] Create examples/raggio_syntax/ast_building/complex_schema.exs showing nested structure
- [ ] T116 [P] [US3] Create examples/raggio_syntax/ast_building/node_composition.exs showing composing node

### Traversal Example

- [ ] T117 [P] [US3] Create examples/raggio_syntax/traversal/depth_first.exs showing DFS traversal per data-model.md
- [ ] T118 [P] [US3] Create examples/raggio_syntax/traversal/visitor_pattern.exs showing visitor combinator
- [ ] T119 [P] [US3] Create examples/raggio_syntax/traversal/filtering.exs showing find/find_all usage

### Transformation Example

- [ ] T120 [P] [US3] Create examples/raggio_syntax/transformation/modify_node.exs showing transform function
- [ ] T121 [P] [US3] Create examples/raggio_syntax/transformation/rewrite_rule.exs showing AST rewrite
- [ ] T122 [P] [US3] Create examples/raggio_syntax/transformation/optimization.exs showing optimization pattern

### Advanced Example

- [ ] T123 [P] [US3] Create examples/raggio_syntax/advanced/code_generation.exs showing code gen pattern
- [ ] T124 [P] [US3] Create examples/raggio_syntax/advanced/analysis.exs showing AST analysis

### Automated Example Test Update

- [ ] T125 [US3] Update test/example_test.exs to include Raggio.Syntax example verification
- [ ] T126 [US3] Run mix test test/example_test.exs and verify all example (both package) pass

**Checkpoint**: At this point, User Story 3 is fully complete - working example for both package

---

## Phase 7: User Story 4 - Developer extends functionality through composition (Priority: P2)

**Goal**: Validate composability - developer can create custom validator/transformer by composing primitive

**Independent Test**: Use public API to create custom composite function (validator or transformer), use in real scenario, verify correct behavior without library modification

**Note**: US4 test composability of both package, building on US1 and US2

### Additional Composition Utility (enable US4)

- [ ] T127 [P] [US4] Implement Raggio.Schema.transform/2 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T128 [P] [US4] Implement Raggio.Schema.coerce/1 in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T129 [P] [US4] Implement Raggio.Syntax.merge/2 in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T130 [P] [US4] Implement Raggio.Syntax.compose/1 in apps/raggio_syntax/lib/raggio_syntax.ex

### Composition Example (demonstrating US4)

- [ ] T131 [P] [US4] Add custom validator example to examples/raggio_schema/composition/ showing US4 acceptance 1-2
- [ ] T132 [P] [US4] Add custom transformer example to examples/raggio_syntax/transformation/ showing composition pattern
- [ ] T133 [P] [US4] Create examples/raggio_schema/advanced/combinator.exs showing combinator pattern per research.md
- [ ] T134 [US4] Verify example demonstrate composition without requiring library modification (US4 acceptance 1)

**Checkpoint**: At this point, User Story 4 is complete - composability validated through working example

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories or complete remaining requirements

### Documentation

- [ ] T135 [P] Update apps/raggio_schema/README.md with installation instruction and basic usage per quickstart.md
- [ ] T136 [P] Update apps/raggio_syntax/README.md with installation instruction and basic usage per quickstart.md
- [ ] T137 [P] Create CHANGELOG.md for each package documenting initial 0.1.0 release
- [ ] T138 Update root README.md with umbrella overview, package description, example navigation

### Additional Type and Constraint

- [ ] T139 [P] Implement remaining array constraint (min_items, max_items, unique) in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T140 [P] Implement remaining string constraint (url) in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T141 [P] Implement negative/1 numeric constraint in apps/raggio_schema/lib/raggio_schema.ex

### Error Handling Enhancement

- [ ] T142 Add comprehensive error message for ValidationError per data-model.md specification
- [ ] T143 Add comprehensive error message for CompositionError per clarification requirement

### Formatter and Tooling

- [ ] T144 [P] Run mix format across all package and verify consistent style
- [ ] T145 [P] Run mix compile --warnings-as-errors and fix any warning
- [ ] T146 [P] Add mix alias to root mix.exs per research.md (test.all, format.all)

### Validation and Verification

- [ ] T147 Run mix deps.get and mix compile from root - verify umbrella compile under 5 minute (SC-001)
- [ ] T148 Run random example and verify execution under 30 second (SC-002)
- [ ] T149 Create test project, add raggio_schema as dependency, verify independent usage (SC-003)
- [ ] T150 Create test project, add raggio_syntax as dependency, verify independent usage (SC-003)
- [ ] T151 Verify no circular dependency between package per clarification and FR-004
- [ ] T152 Run quickstart.md validation - execute all command and verify output
- [ ] T153 Verify example directory structure match two-level hierarchy per clarification
- [ ] T154 Verify module-level documentation only (no function doc) per FR-005 and clarification

### Final Verification

- [ ] T155 Run mix test from umbrella root and verify all test pass (package test + example test)
- [ ] T156 Verify all 4 user story acceptance scenario are met independently
- [ ] T157 Verify all 6 success criteria (SC-001 through SC-006) are satisfied
- [ ] T158 Verify all 13 functional requirement (FR-001 through FR-013) are implemented

**Checkpoint**: Feature complete - all user story functional, all requirement met, ready for use

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) - Independent, can start immediately after Phase 2
- **User Story 3 for Schema (Phase 4)**: Depends on User Story 1 completion (need working package to demo)
- **User Story 2 (Phase 5)**: Depends on Foundational (Phase 2) - Independent, can run parallel to US1
- **User Story 3 for Syntax (Phase 6)**: Depends on User Story 2 completion (need working package to demo)
- **User Story 4 (Phase 7)**: Depends on User Story 1 AND 2 completion (test both package composability)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - No dependencies on other stories (can run parallel to US1)
- **User Story 3 (P1)**: Depends on US1 for Schema example, US2 for Syntax example - Split into two phase
- **User Story 4 (P2)**: Depends on both US1 and US2 completion - Test composability of both package

### Within Each User Story

**User Story 1** (Raggio.Schema):
- Core structure first (T022-T024)
- Then primitive type (T025-T032) in parallel
- Then composite type (T033-T036)
- Then validation core (T037-T040) - BLOCKS constraint function
- Then constraint function (T041-T048) in parallel
- Then composition function (T049-T051)
- Finally test (T052-T056)

**User Story 3** (Example):
- Example directory structure (T057-T060) in parallel
- Then example file (T061-T070) in parallel - all independent
- Finally automated test (T071-T074)

**User Story 2** (Raggio.Syntax):
- Core structure first (T075-T077)
- Then node type (T078-T081) in parallel
- Then construction function (T082-T089) in parallel
- Then traversal (T090-T095)
- Then transformation (T096-T100)
- Then query function (T101-T104) in parallel
- Finally test (T105-T109) in parallel

### Parallel Opportunities

**Within Setup (Phase 1)**:
- T003, T004, T005, T006, T007, T008, T009 can all run in parallel

**Within Foundational (Phase 2)**:
- T012-T015 (raggio_schema setup) can run parallel to T017-T020 (raggio_syntax setup)

**User Story Parallelization**:
- US1 (Phase 3) and US2 (Phase 5) can be developed in parallel by different developer after Phase 2 complete
- Within US1: T025-T032 (primitive type) all parallel
- Within US1: T041-T048 (constraint) all parallel after validation core complete
- Within US3: T057-T060 (directory) parallel, T061-T070 (example file) all parallel
- Within US2: T078-T081 (node type) parallel, T082-T089 (construction) parallel

---

## Parallel Example: User Story 1 (Raggio.Schema)

```bash
# After core structure (T022-T024), launch all primitive type together:
Task T025: "Implement Raggio.Schema.string/0"
Task T026: "Implement Raggio.Schema.integer/0"
Task T027: "Implement Raggio.Schema.float/0"
Task T028: "Implement Raggio.Schema.boolean/0"
Task T029: "Implement Raggio.Schema.date/0"
Task T030: "Implement Raggio.Schema.datetime/0"
Task T031: "Implement Raggio.Schema.decimal/0"
Task T032: "Implement Raggio.Schema.atom/0"

# After validation core (T037-T040), launch all constraint together:
Task T041: "Implement Raggio.Schema.min_length/2"
Task T042: "Implement Raggio.Schema.max_length/2"
Task T043: "Implement Raggio.Schema.pattern/2"
Task T044: "Implement Raggio.Schema.email/1"
Task T045: "Implement Raggio.Schema.min/2"
Task T046: "Implement Raggio.Schema.max/2"
Task T047: "Implement Raggio.Schema.positive/1"
Task T048: "Implement Raggio.Schema.range/3"
```

---

## Parallel Example: User Story 3 (Example)

```bash
# Launch all example directory creation together:
Task T057: "Create examples/raggio_schema/basic_validation/ directory"
Task T058: "Create examples/raggio_schema/composition/ directory"
Task T059: "Create examples/raggio_schema/transformation/ directory"
Task T060: "Create examples/raggio_schema/advanced/ directory"

# Launch all example file creation together (after US1 complete):
Task T061: "Create simple_schema.exs"
Task T062: "Create nested_schema.exs"
Task T063: "Create validation_error.exs"
Task T064: "Create combine_validator.exs"
Task T065: "Create custom_type.exs"
Task T066: "Create reusable_schema.exs"
Task T067: "Create data_mapping.exs"
Task T068: "Create coercion.exs"
Task T069: "Create conditional_validation.exs"
Task T070: "Create cross_field.exs"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 3 for Schema only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Raggio.Schema)
4. Complete Phase 4: User Story 3 for Schema (Example)
5. **STOP and VALIDATE**: Test User Story 1 independently with example
6. Deploy/demo Raggio.Schema as standalone package

**Rationale**: Both US1 and US3 are P1 priority. Together they deliver a complete, usable Raggio.Schema package with working example. This is the true MVP.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 + User Story 3 (Schema) → Test independently → Deploy/Demo (MVP - Raggio.Schema!)
3. Add User Story 2 + User Story 3 (Syntax) → Test independently → Deploy/Demo (Raggio.Syntax!)
4. Add User Story 4 → Test composability → Complete feature
5. Each increment adds value without breaking previous work

### Parallel Team Strategy

With multiple developers (after Foundational complete):

1. **Developer A**: User Story 1 (Raggio.Schema implementation)
2. **Developer B**: User Story 2 (Raggio.Syntax implementation) - parallel to A
3. **Developer C**: User Story 3 preparation (example structure) - can prepare while A/B work
4. After A complete: **Developer A or C**: User Story 3 for Schema (example creation)
5. After B complete: **Developer B or C**: User Story 3 for Syntax (example creation)
6. After all complete: **Any developer**: User Story 4 (composability validation)

---

## Notes

- **[P] tasks**: Different files, no dependencies - can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **Each user story**: Independently completable and testable
- **No test task**: Test not explicitly requested in spec; example verification serve as validation
- **Module-level doc only**: Per FR-005 and clarification - no function @doc
- **Composition over macro**: Per FR-007 - pipe operator pattern throughout
- **Two-level hierarchy**: example/[package]/[use_case] per clarification
- **Composition-time error**: Per clarification - type incompatibility detected when composing
- **Independent package**: Per FR-004 - no circular dependency, independently publishable

### Commit Strategy

- Commit after each logical group of task (e.g., all primitive type T025-T032)
- Commit at each checkpoint (end of phase)
- Use conventional commit: `feat(schema): add primitive type function`

### Validation Checkpoint

- After Phase 3: Verify US1 acceptance scenario 1-4 are met
- After Phase 4: Verify US3 acceptance scenario 1-3 for Schema example
- After Phase 5: Verify US2 acceptance scenario 1-3 are met
- After Phase 6: Verify US3 acceptance scenario 1-3 for Syntax example
- After Phase 7: Verify US4 acceptance scenario 1-3 are met
- After Phase 8: Verify all 6 success criteria (SC-001 through SC-006)

### Success Criteria Verification

Map to specific task:
- **SC-001** (compile < 5 min): T147
- **SC-002** (example < 30 sec): T148
- **SC-003** (independent usage): T149, T150
- **SC-004** (90% without macro): Validated through US4 example
- **SC-005** (Ecto/Phoenix structure): Validated through Phase 1-2 structure
- **SC-006** (learn from example): Validated through US3 completion

**Total Task**: 158 task organized across 8 phase, supporting 4 user story with clear dependency and parallel opportunity
