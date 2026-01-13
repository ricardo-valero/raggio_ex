# Tasks: Single-Package Restructure (Ecto-style)

**Feature**: 001-monorepo-restructure  
**Branch**: `001-monorepo-restructure`  
**Date**: 2026-01-13

**Organization**: Tasks grouped by user story to enable independent implementation and testing

## Summary

**Total Tasks**: 95  
**MVP Scope**: Phase 1-4 (T001-T060) - Core schema validation + Examples  
**Parallelizable**: ~60 tasks marked [P]

**By User Story**:
- US1 (Core schema validation): 35 tasks (P1 MVP)
- US2 (Syntax manipulation): 18 tasks (P2)
- US3 (Working examples): 12 tasks (P1 MVP)
- US4 (Composability/extension): 6 tasks (P2)
- US5 (BigQuery export): 8 tasks (P2)
- US6 (SheetSchema import): 8 tasks (P2)
- Setup/Polish: 8 tasks

**Note**: User Story 7 (Raggio.Tabular) is DEFERRED to follow-up iteration per spec clarification.

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure) ✅ COMPLETE

**Purpose**: Project initialization with single package structure (Ecto-style, NOT umbrella)

- [x] T001 Create mix.exs for single package at mix.exs (app: :raggio, elixir: "~> 1.14")
- [x] T002 [P] Add Decimal dependency to mix.exs
- [x] T003 [P] Add Jason dependency to mix.exs for BigQuery JSON export
- [x] T004 [P] Create lib/raggio.ex root module (minimal - version, config only)
- [x] T005 [P] Create config/config.exs with shared configuration
- [x] T006 [P] Create .formatter.exs for code formatting
- [x] T007 [P] Create test/test_helper.exs for ExUnit setup

---

## Phase 2: Foundational (Blocking Prerequisites) ✅ COMPLETE

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T008 Create Type struct in lib/raggio/schema/type.ex with fields: kind, constraints, inner, fields, elements, key_type, value_type, values, transform, metadata
- [x] T009 [P] Create Error struct in lib/raggio/schema/error.ex with fields: path, message, value, constraint
- [x] T010 [P] Define validation_result type in lib/raggio/schema.ex as {:ok, any()} | {:error, [Error.t()]}
- [x] T011 Create base Raggio.Schema module in lib/raggio/schema.ex with module-level doc only

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Developer imports and uses Raggio.Schema (Priority: P1) 🎯 MVP ✅ COMPLETE

**Goal**: Enable developers to define schemas and validate data using composable API with argument composition syntax

**Independent Test**: `alias Raggio.Schema`, define user schema with `Schema.struct([{:name, Schema.string()}, {:age, Schema.integer()}])`, validate data successfully

### Implementation for User Story 1

#### Primitive Type Constructors (lib/raggio/schema.ex)

- [x] T012 [P] [US1] Implement string/1 type constructor with opts (min, max, pattern, default)
- [x] T013 [P] [US1] Implement integer/1 type constructor with opts (min, max, default)
- [x] T014 [P] [US1] Implement float/1 type constructor with opts (min, max, default)
- [x] T015 [P] [US1] Implement boolean/1 type constructor with opts (default)
- [x] T016 [P] [US1] Implement date/1 type constructor with opts (default)
- [x] T017 [P] [US1] Implement datetime/1 type constructor with opts (default)
- [x] T018 [P] [US1] Implement decimal/1 type constructor with opts (min, max, default)
- [x] T019 [P] [US1] Implement atom/1 type constructor with opts (default)

#### Composite Type Constructors (lib/raggio/schema.ex)

- [x] T020 [P] [US1] Implement struct/1 for struct type with keyword list of tuples [{:field, schema}]
- [x] T021 [P] [US1] Implement list/2 for list type with inner schema and opts (min, max, unique, default)
- [x] T022 [P] [US1] Implement tuple/1 for tuple type with list of schemas (positional)
- [x] T023 [P] [US1] Implement union/1 for union type (multiple alternatives)
- [x] T024 [P] [US1] Implement literal/1 variadic for literal type with allowed values
- [x] T025 [P] [US1] Implement record/2 for typed maps with dynamic keys (key_schema, value_schema)

#### Field Descriptors (lib/raggio/schema.ex)

- [x] T026 [P] [US1] Implement optional/1 wrapper function to mark field as optional
- [x] T027 [P] [US1] Implement nullable/1 wrapper function to allow nil values

#### Convenience Helpers (lib/raggio/schema.ex)

- [x] T028 [P] [US1] Implement email/0 returning email regex pattern
- [x] T029 [P] [US1] Implement url/0 returning URL regex pattern
- [x] T030 [P] [US1] Implement uuid/0 returning UUID regex pattern

#### Validation Engine (lib/raggio/schema/validator.ex)

- [x] T031 [US1] Implement validate/2 returning {:ok, data} | {:error, errors}
- [x] T032 [US1] Implement validate/3 with options (mode: :fail_fast | :all_errors, partial: boolean)
- [x] T033 [US1] Implement validate!/2 that raises on error in lib/raggio/schema.ex
- [x] T034 [US1] Implement type validation for all primitive types
- [x] T035 [US1] Implement polymorphic min constraint validation (numbers, strings, lists)
- [x] T036 [US1] Implement polymorphic max constraint validation (numbers, strings, lists)
- [x] T037 [US1] Implement pattern constraint validation for strings
- [x] T038 [US1] Implement unique constraint validation for lists
- [x] T039 [US1] Implement nested struct validation with path accumulation
- [x] T040 [US1] Implement list validation with index-based error paths
- [x] T041 [US1] Implement union type validation (try each alternative)
- [x] T042 [US1] Implement literal type validation
- [x] T043 [US1] Implement record type validation (key + value schemas)
- [x] T044 [US1] Implement optional field handling in struct validation
- [x] T045 [US1] Implement nullable field handling in validation
- [x] T046 [US1] Implement default value application in validation

**Checkpoint**: User Story 1 complete - schema definition and validation functional

---

## Phase 4: User Story 3 - Developer learns through working examples (Priority: P1) 🎯 MVP ✅ COMPLETE

**Goal**: Provide working, compilable examples that serve as primary documentation

**Independent Test**: Navigate to examples/schema/, run any example with `mix run`, verify output

### Implementation for User Story 3

#### Raggio.Schema Examples (examples/schema/)

- [x] T047 [P] [US3] Create examples/schema/basic_validation/simple_schema.exs demonstrating basic struct validation
- [x] T048 [P] [US3] Create examples/schema/basic_validation/validation_errors.exs demonstrating error structure
- [x] T049 [P] [US3] Create examples/schema/basic_validation/nested_structs.exs demonstrating nested validation
- [x] T050 [P] [US3] Create examples/schema/basic_validation/lists_and_records.exs demonstrating composite types
- [x] T051 [P] [US3] Create examples/schema/basic_validation/literals_and_unions.exs demonstrating literal() and union()
- [x] T052 [P] [US3] Create examples/schema/basic_validation/optional_nullable_default.exs demonstrating field descriptors

#### Example Test Suite

- [x] T053 [US3] Create test/examples_test.exs to verify all examples compile and run successfully

**Checkpoint**: MVP complete - User Stories 1 and 3 deliver core value

---

## Phase 5: User Story 2 - Developer uses Raggio.Syntax for syntax manipulation (Priority: P2) ✅ COMPLETE

**Goal**: Enable developers to construct, traverse, and transform syntax trees

**Independent Test**: `alias Raggio.Syntax`, create syntax nodes, traverse them, transform them successfully

### Implementation for User Story 2

#### Node Struct (lib/raggio/syntax/node.ex)

- [x] T054 [P] [US2] Create Node struct with fields: kind, name, children, metadata, source

#### Builder Functions (lib/raggio/syntax.ex)

- [x] T055 [P] [US2] Create Raggio.Syntax module in lib/raggio/syntax.ex with module-level doc
- [x] T056 [P] [US2] Implement schema/1 creating schema node from fields list
- [x] T057 [P] [US2] Implement field/2 and field/3 creating field nodes
- [x] T058 [P] [US2] Implement type/1 and type/2 creating type nodes

#### Tree Wrapper (lib/raggio/syntax.ex)

- [x] T059 [P] [US2] Implement ast/1 and ast/2 wrapping node in tree with metadata

#### Traversal Functions (lib/raggio/syntax/traversal.ex)

- [x] T060 [US2] Implement traverse/2 for depth-first traversal with visitor
- [x] T061 [US2] Implement traverse/3 for traversal with accumulator
- [x] T062 [US2] Implement find/2 to find first matching node
- [x] T063 [US2] Implement find_all/2 to find all matching nodes

#### Query Functions (lib/raggio/syntax.ex)

- [x] T064 [US2] Implement get_fields/1 to extract field nodes from schema
- [x] T065 [US2] Implement get_field/2 to get specific field by name
- [x] T066 [US2] Implement get_children/1 to get immediate children

#### Syntax Examples (examples/syntax/)

- [x] T067 [P] [US2] Create examples/syntax/node_building/basic_nodes.exs demonstrating node creation
- [x] T068 [P] [US2] Create examples/syntax/tree_traversal/depth_first.exs demonstrating traversal

**Checkpoint**: User Story 2 complete - syntax manipulation functional

---

## Phase 6: User Story 4 - Developer extends functionality through composition (Priority: P2) ✅ COMPLETE

**Goal**: Enable custom validators and transformers through composition

**Independent Test**: Create custom composed function, use alongside built-in functions successfully

### Implementation for User Story 4

#### Transformation Functions (lib/raggio/syntax/transform.ex)

- [x] T069 [US4] Implement transform/2 to apply transformation to all nodes
- [x] T070 [US4] Implement filter/2 to remove non-matching nodes
- [x] T071 [US4] Implement replace/3 to replace specific node

#### Extension Examples

- [x] T072 [P] [US4] Create examples/schema/composition/custom_validator.exs demonstrating custom validation (existing from old_code)
- [x] T073 [P] [US4] Create examples/syntax/transformation/custom_transformer.exs demonstrating transformer extension (existing from old_code)

**Checkpoint**: User Story 4 complete - extensibility through composition verified

---

## Phase 7: User Story 5 - Developer exports schema to BigQuery (Priority: P2) ✅ COMPLETE

**Goal**: Convert Raggio.Schema definitions to BigQuery Standard SQL DDL

**Independent Test**: Define schema, call `Raggio.Schema.Adapters.BigQuery.to_ddl/2`, verify valid DDL output

### Implementation for User Story 5

#### BigQuery Exporter (lib/raggio/schema/adapters/bigquery.ex)

- [x] T074 [US5] Create lib/raggio/schema/adapters/bigquery.ex with module-level doc
- [x] T075 [US5] Implement to_ddl/2 converting schema to BigQuery DDL string
- [x] T076 [US5] Implement to_ddl/3 with options (partition_by, cluster_by, description)
- [x] T077 [US5] Implement type mapping: string->STRING, integer->INT64, float->FLOAT64, boolean->BOOL
- [x] T078 [US5] Implement type mapping: decimal->NUMERIC, datetime->DATETIME, date->DATE
- [x] T079 [US5] Implement nested struct to STRUCT<...> conversion
- [x] T080 [US5] Implement list to ARRAY<type> conversion

#### BigQuery Examples

- [x] T081 [P] [US5] Create examples/schema/adapters/bigquery_export.exs demonstrating DDL generation

**Checkpoint**: User Story 5 complete - BigQuery export functional

---

## Phase 8: User Story 6 - Developer imports schema from SheetSchema (Priority: P2) ✅ COMPLETE

**Goal**: Convert SheetSchema spreadsheet definitions to Raggio.Schema code

**Independent Test**: Provide CSV with field definitions, run importer, verify generated code compiles

### Implementation for User Story 6

#### SheetSchema Importer (lib/raggio/schema/adapters/sheet_schema.ex)

- [x] T082 [US6] Create lib/raggio/schema/adapters/sheet_schema.ex with module-level doc
- [x] T083 [US6] Implement from_csv/1 parsing CSV and returning generated Schema code string
- [x] T084 [US6] Implement from_csv/2 with options (module_name, format)
- [x] T085 [US6] Implement CSV column parsing: field_name, type, required, constraints
- [x] T086 [US6] Implement type parsing to generate new constructors (string->Schema.string())
- [x] T087 [US6] Implement constraint parsing to generate keyword options (min:3->min: 3)
- [x] T088 [US6] Implement validate_format/1 for format validation with row-level errors

#### SheetSchema Examples

- [x] T089 [P] [US6] Create examples/schema/adapters/sheet_import.exs demonstrating CSV import

**Checkpoint**: User Story 6 complete - SheetSchema import functional

---

## Phase 9: Polish & Cross-Cutting Concerns ✅ COMPLETE

**Purpose**: Final improvements across all user stories

- [x] T090 Create feature parity checklist comparing old_code to new package in specs/001-monorepo-restructure/parity-checklist.md (SKIPPED - old_code moved to old_code/umbrella_apps)
- [x] T091 Run mix format to format all code
- [x] T092 Run mix compile --warnings-as-errors to verify clean compilation
- [x] T093 Run mix test to verify all tests pass (11 tests, 0 failures)
- [x] T094 Validate all examples in examples/ compile and run via test/examples_test.exs
- [x] T095 Verify no macros in public API (only functions)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Core validation
- **User Story 3 (Phase 4)**: Depends on US1 - Examples need working schemas
- **User Story 2 (Phase 5)**: Depends on Foundational - Can parallel with US1
- **User Story 4 (Phase 6)**: Depends on US1 and US2 - Extension patterns
- **User Story 5 (Phase 7)**: Depends on US1 - BigQuery export
- **User Story 6 (Phase 8)**: Depends on US1 - SheetSchema import
- **Polish (Phase 9)**: Depends on all desired user stories complete

### User Story Dependencies

- **US1 (P1 MVP)**: Foundation only - Can start first
- **US3 (P1 MVP)**: Depends on US1 - Examples need schemas
- **US2 (P2)**: Foundation only - Can parallel with US1
- **US4 (P2)**: Depends on US1 + US2 - Extensibility
- **US5 (P2)**: Depends on US1 - Export
- **US6 (P2)**: Depends on US1 - Import

### Parallel Opportunities

**Within Phase 3 (US1)**:
- All primitive type constructors (T012-T019) can run in parallel
- All composite type constructors (T020-T025) can run in parallel
- All field descriptors (T026-T027) can run in parallel
- All convenience helpers (T028-T030) can run in parallel

**Within Phase 5 (US2)**:
- All builder functions (T055-T059) can run in parallel
- All syntax examples (T067-T068) can run in parallel

**Across Phases**:
- All [P] tasks within a phase can run in parallel
- All example tasks across phases can run in parallel (different files)

---

## Parallel Example: User Story 1 Primitive Types

```bash
# Launch all primitive type constructors together:
T012: string/1 type constructor
T013: integer/1 type constructor
T014: float/1 type constructor
T015: boolean/1 type constructor
T016: date/1 type constructor
T017: datetime/1 type constructor
T018: decimal/1 type constructor
T019: atom/1 type constructor

# All can be implemented simultaneously - no dependencies between them
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 3 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Core validation)
4. Complete Phase 4: User Story 3 (Examples)
5. **STOP and VALIDATE**: Run `mix test` and verify examples work
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → MVP! (validation works)
3. Add User Story 3 → Test independently → MVP! (examples work)
4. Add User Story 2 → Test independently → Syntax manipulation
5. Add User Story 4 → Test independently → Extensibility
6. Add User Stories 5-6 → Test independently → Adapters complete
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:
1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (validation)
   - Developer B: User Story 2 (syntax)
3. After US1 complete:
   - Developer A: User Story 3 (examples) + US4 (extensibility)
   - Developer B: User Stories 5-6 (adapters)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- **Structure**: Single package (lib/raggio.ex, lib/raggio/schema.ex, etc.), NOT umbrella
- **User Story 7 (Raggio.Tabular)**: DEFERRED to follow-up iteration per spec clarification
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
