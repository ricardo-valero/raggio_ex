# Tasks: Multi-Package Monorepo Restructure

**Feature**: 001-monorepo-restructure  
**Branch**: `001-monorepo-restructure`  
**Date**: 2026-01-13

**Organization**: Tasks grouped by user story to enable independent implementation and testing

## Summary

**Total Tasks**: 145  
**MVP Scope**: Phase 1-4 (T001-T057) - Core schema validation + Examples  
**Parallelizable**: ~95 tasks marked [P]

**By User Story**:
- US1 (Core schema validation): 35 tasks (P1 MVP)
- US2 (Syntax manipulation): 22 tasks (P2)
- US3 (Working examples): 15 tasks (P1 MVP)
- US4 (Composability/extension): 8 tasks (P2)
- US5 (BigQuery export): 10 tasks (P2)
- US6 (SheetSchema import): 10 tasks (P2)
- US7 (Tabular parsing): 25 tasks (P2)
- Setup/Polish: 20 tasks

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and verify existing structure

- [X] T001 Verify umbrella project structure at mix.exs
- [X] T002 [P] Add Decimal dependency to apps/raggio_schema/mix.exs
- [X] T003 [P] Add Jason dependency to apps/raggio_schema/mix.exs for BigQuery JSON export
- [X] T004 [P] Create config/config.exs with shared configuration
- [X] T005 [P] Create config/test.exs for test environment configuration
- [X] T006 [P] Verify .gitignore with Elixir patterns (_build/, deps/, *.beam, etc.)
- [X] T007 [P] Verify .formatter.exs for umbrella-wide code formatting
- [X] T008 [P] Verify apps/raggio_schema/test/test_helper.exs exists
- [X] T009 [P] Verify apps/raggio_syntax/test/test_helper.exs exists

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T010 Update Schema struct with new fields (type, encoded, constraints, fields, inner_type, types, values, optional, nullable, default, annotations) in apps/raggio_schema/lib/raggio_schema.ex
- [X] T011 [P] Create ValidationError struct in apps/raggio_schema/lib/raggio_schema/error.ex with path, message, value, constraint fields
- [X] T012 [P] Create CompositionError exception in apps/raggio_schema/lib/raggio_schema/error.ex for incompatible type composition
- [X] T013 Create base Node protocol in apps/raggio_syntax/lib/raggio_syntax/node.ex with node_type/1 and children/1
- [X] T014 [P] Define SyntaxTree struct in apps/raggio_syntax/lib/raggio_syntax/ast.ex with root and metadata fields
- [X] T015 Run mix compile to verify foundational structures compile

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Developer imports and uses Raggio.Schema package (Priority: P1) MVP

**Goal**: Enable developers to define schemas and validate data using composable API with argument composition syntax

**Independent Test**: Install package, define user schema with name/age, validate data successfully

### Implementation for User Story 1

#### Primitive Type Constructors (apps/raggio_schema/lib/raggio_schema.ex)

- [X] T016 [P] [US1] Implement string/1 type constructor with opts (min, max, pattern, default)
- [X] T017 [P] [US1] Implement integer/1 type constructor with opts (min, max, default)
- [X] T018 [P] [US1] Implement float/1 type constructor with opts (min, max, default)
- [X] T019 [P] [US1] Implement boolean/1 type constructor with opts (default)
- [X] T020 [P] [US1] Implement date/1 type constructor with opts (default)
- [X] T021 [P] [US1] Implement datetime/1 type constructor with opts (default)
- [X] T022 [P] [US1] Implement decimal/1 type constructor with opts (min, max, default)
- [X] T023 [P] [US1] Implement atom/1 type constructor with opts (default)

#### Composite Type Constructors

- [X] T024 [P] [US1] Implement struct/1 for struct type with keyword list of tuples in apps/raggio_schema/lib/raggio_schema.ex
- [X] T025 [P] [US1] Implement list/2 for list type with inner schema and opts (min, max, unique, default) in apps/raggio_schema/lib/raggio_schema.ex
- [X] T026 [P] [US1] Implement tuple/1 for tuple type with list of schemas in apps/raggio_schema/lib/raggio_schema.ex
- [X] T027 [P] [US1] Implement union/1 for union type (multiple alternatives) in apps/raggio_schema/lib/raggio_schema.ex
- [X] T028 [P] [US1] Implement literal/1 for literal type with variadic values in apps/raggio_schema/lib/raggio_schema.ex
- [X] T029 [P] [US1] Implement record/2 for typed maps with dynamic keys in apps/raggio_schema/lib/raggio_schema.ex

#### Field Descriptors

- [X] T030 [P] [US1] Implement optional/1 wrapper function to mark field as optional in apps/raggio_schema/lib/raggio_schema.ex
- [X] T031 [P] [US1] Implement nullable/1 wrapper function to allow nil values in apps/raggio_schema/lib/raggio_schema.ex

#### Convenience Helpers

- [X] T032 [P] [US1] Implement email/0 returning email regex pattern in apps/raggio_schema/lib/raggio_schema.ex
- [X] T033 [P] [US1] Implement url/0 returning URL regex pattern in apps/raggio_schema/lib/raggio_schema.ex
- [X] T034 [P] [US1] Implement uuid/0 returning UUID regex pattern in apps/raggio_schema/lib/raggio_schema.ex

#### Validation Engine

- [X] T035 [US1] Implement validate/2 returning {:ok, data} | {:error, errors} in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T036 [US1] Implement validate/3 with options (mode: :fail_fast | :all_errors, partial: boolean) in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T037 [US1] Implement validate!/2 that raises on error in apps/raggio_schema/lib/raggio_schema.ex
- [X] T038 [US1] Implement type validation for all primitive types in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T039 [US1] Implement polymorphic min constraint validation (numbers, strings, lists) in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T040 [US1] Implement polymorphic max constraint validation (numbers, strings, lists) in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T041 [US1] Implement pattern constraint validation for strings in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T042 [US1] Implement unique constraint validation for lists in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T043 [US1] Implement nested struct validation with path accumulation in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T044 [US1] Implement list validation with index-based error paths in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T045 [US1] Implement union type validation (try each alternative) in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T046 [US1] Implement literal type validation in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T047 [US1] Implement record type validation in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T048 [US1] Implement optional field handling in struct validation in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T049 [US1] Implement nullable field handling in validation in apps/raggio_schema/lib/raggio_schema/validator.ex
- [X] T050 [US1] Implement default value application in validation in apps/raggio_schema/lib/raggio_schema/validator.ex

**Checkpoint**: User Story 1 complete - schema definition and validation functional

---

## Phase 4: User Story 3 - Developer learns through working examples (Priority: P1) MVP

**Goal**: Provide working, compilable examples that serve as primary documentation

**Independent Test**: Navigate to examples/, run any example with mix run, verify output

### Implementation for User Story 3

#### Raggio.Schema Examples

- [X] T051 [P] [US3] Update examples/raggio_schema/basic_validation/simple_schema.exs with new API syntax
- [X] T052 [P] [US3] Update examples/raggio_schema/basic_validation/validation_error.exs with new API syntax
- [X] T053 [P] [US3] Update examples/raggio_schema/basic_validation/nested_schema.exs with new API syntax
- [X] T054 [P] [US3] Update examples/raggio_schema/basic_validation/array_validation.exs with new API syntax (use list())
- [X] T055 [P] [US3] Update examples/raggio_schema/basic_validation/enum_union.exs with new API syntax (use literal())
- [X] T056 [P] [US3] Update examples/raggio_schema/basic_validation/optional_default.exs with new API syntax
- [X] T057 [P] [US3] Update examples/raggio_schema/composition/reusable_schema.exs with new API syntax
- [X] T058 [P] [US3] Update examples/raggio_schema/composition/custom_type.exs with new API syntax
- [X] T059 [P] [US3] Update examples/raggio_schema/composition/combine_validator.exs with new API syntax

#### Example Test Suite

- [X] T060 [US3] Update test/example_test.exs to verify all examples compile and run

**Checkpoint**: MVP complete - User Stories 1 and 3 deliver core value

---

## Phase 5: User Story 2 - Developer uses Raggio.Syntax for syntax manipulation (Priority: P2)

**Goal**: Enable developers to construct, traverse, and transform syntax trees

**Independent Test**: Create syntax nodes, traverse them, transform them successfully

### Implementation for User Story 2

#### Node Structs (apps/raggio_syntax/lib/raggio_syntax/node/)

- [ ] T061 [P] [US2] Implement SchemaNode struct with type, name, schema_type, fields, metadata in apps/raggio_syntax/lib/raggio_syntax/node/schema.ex
- [ ] T062 [P] [US2] Implement FieldNode struct with type, name, field_type, required, default, metadata in apps/raggio_syntax/lib/raggio_syntax/node/field.ex
- [ ] T063 [P] [US2] Implement TypeNode struct with type, name, parameters, metadata in apps/raggio_syntax/lib/raggio_syntax/node/type.ex

#### Node Protocol Implementations

- [ ] T064 [P] [US2] Implement Node protocol for SchemaNode in apps/raggio_syntax/lib/raggio_syntax/node/schema.ex
- [ ] T065 [P] [US2] Implement Node protocol for FieldNode in apps/raggio_syntax/lib/raggio_syntax/node/field.ex
- [ ] T066 [P] [US2] Implement Node protocol for TypeNode in apps/raggio_syntax/lib/raggio_syntax/node/type.ex

#### Node Construction (apps/raggio_syntax/lib/raggio_syntax.ex)

- [ ] T067 [P] [US2] Implement schema/1 creating schema node from fields list
- [ ] T068 [P] [US2] Implement schema/2 creating named schema node
- [ ] T069 [P] [US2] Implement field/2 creating field node
- [ ] T070 [P] [US2] Implement field/3 creating field node with options
- [ ] T071 [P] [US2] Implement type/1 creating simple type node
- [ ] T072 [P] [US2] Implement type/2 creating generic type node with parameters
- [ ] T073 [P] [US2] Implement ast/1 wrapping node in SyntaxTree
- [ ] T074 [P] [US2] Implement ast/2 wrapping node with metadata

#### Traversal Functions (apps/raggio_syntax/lib/raggio_syntax/traversal.ex)

- [ ] T075 [US2] Implement traverse/2 for depth-first traversal with visitor
- [ ] T076 [US2] Implement traverse/3 for traversal with accumulator
- [ ] T077 [US2] Implement traverse_breadth_first/2 for breadth-first traversal
- [ ] T078 [US2] Implement find/2 to find first matching node
- [ ] T079 [US2] Implement find_all/2 to find all matching nodes

#### Query Functions

- [ ] T080 [US2] Implement get_fields/1 to extract field nodes in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T081 [US2] Implement get_field/2 to get specific field by name in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T082 [US2] Implement get_children/1 to get immediate children in apps/raggio_syntax/lib/raggio_syntax.ex

**Checkpoint**: User Story 2 complete - syntax manipulation functional

---

## Phase 6: User Story 4 - Developer extends functionality through composition (Priority: P2)

**Goal**: Enable custom validators and transformers through composition

**Independent Test**: Create custom composed function, use alongside built-in functions successfully

### Implementation for User Story 4

#### Transformation Functions (apps/raggio_syntax/lib/raggio_syntax/transformer.ex)

- [ ] T083 [US4] Implement transform/2 to apply transformation to all nodes
- [ ] T084 [US4] Implement filter/2 to remove non-matching nodes
- [ ] T085 [US4] Implement replace/3 to replace specific node

#### Extension Examples

- [ ] T086 [P] [US4] Create examples/raggio_schema/advanced/custom_validator.exs demonstrating custom validation composition
- [ ] T087 [P] [US4] Create examples/raggio_syntax/advanced/custom_transformer.exs demonstrating transformer extension
- [ ] T088 [P] [US4] Create examples/raggio_syntax/node_building/simple_ast.exs demonstrating basic node creation
- [ ] T089 [P] [US4] Create examples/raggio_syntax/traversal/depth_first.exs demonstrating traversal
- [ ] T090 [P] [US4] Create examples/raggio_syntax/transformation/modify_node.exs demonstrating transformation

**Checkpoint**: User Story 4 complete - extensibility through composition verified

---

## Phase 7: User Story 5 - Developer exports schema to BigQuery (Priority: P2)

**Goal**: Convert Raggio.Schema definitions to BigQuery Standard SQL DDL

**Independent Test**: Define schema, call BigQuery exporter, verify valid DDL output

### Implementation for User Story 5

#### BigQuery Exporter (apps/raggio_schema/lib/raggio_schema/adapters/bigquery.ex)

- [ ] T091 [US5] Update to_ddl/2 to use new Schema struct fields
- [ ] T092 [US5] Update to_ddl/3 with options (partition_by, cluster_by, description)
- [ ] T093 [US5] Update type mapping: string -> STRING, integer -> INT64, float -> FLOAT64
- [ ] T094 [US5] Update type mapping: boolean -> BOOL, decimal -> NUMERIC, datetime -> DATETIME
- [ ] T095 [US5] Update nested struct to STRUCT<...> conversion
- [ ] T096 [US5] Update list to ARRAY<type> conversion
- [ ] T097 [US5] Implement literal type handling (map to STRING with comment)
- [ ] T098 [US5] Handle optional/nullable in NOT NULL generation

#### BigQuery Examples

- [ ] T099 [P] [US5] Update examples/raggio_schema/adapters/bigquery_export.exs with new API syntax
- [ ] T100 [P] [US5] Create examples/raggio_schema/adapters/bigquery_nested.exs demonstrating nested struct export

**Checkpoint**: User Story 5 complete - BigQuery export functional

---

## Phase 8: User Story 6 - Developer imports schema from SheetSchema (Priority: P2)

**Goal**: Convert SheetSchema spreadsheet definitions to Raggio.Schema code

**Independent Test**: Provide CSV with field definitions, run importer, verify generated code compiles

### Implementation for User Story 6

#### SheetSchema Importer (apps/raggio_schema/lib/raggio_schema/adapters/sheet_schema.ex)

- [ ] T101 [US6] Update from_csv/1 to generate new API syntax
- [ ] T102 [US6] Update from_csv/2 with options (module_name)
- [ ] T103 [US6] Implement CSV column parsing: field_name, type, required, constraints
- [ ] T104 [US6] Implement type parsing to generate new constructors
- [ ] T105 [US6] Implement constraint parsing to generate keyword options (min:3 -> min: 3)
- [ ] T106 [US6] Implement nesting via parent_path dot notation
- [ ] T107 [US6] Implement validate_format/1 for format validation
- [ ] T108 [US6] Generate structured errors with row numbers

#### SheetSchema Examples

- [ ] T109 [P] [US6] Update examples/raggio_schema/adapters/sheet_import.exs with new API syntax
- [ ] T110 [P] [US6] Create examples/raggio_schema/adapters/sheet_nested.exs demonstrating nested field import

**Checkpoint**: User Story 6 complete - SheetSchema import functional

---

## Phase 9: User Story 7 - Developer parses Excel/CSV data with SheetSchema (Priority: P2)

**Goal**: Parse, validate, and extract structured data from Excel/CSV files

**Independent Test**: Provide Excel/CSV, define SheetSchema, run parser, verify valid rows extracted

### Implementation for User Story 7

#### Raggio.Tabular Package Setup

- [ ] T111 [US7] Create apps/raggio_tabular/mix.exs with raggio_schema dependency
- [ ] T112 [P] [US7] Create apps/raggio_tabular/lib/raggio_tabular.ex main module
- [ ] T113 [P] [US7] Create apps/raggio_tabular/README.md with package documentation
- [ ] T114 Update mix.exs aliases to include raggio_tabular in test.all and format.all

#### SheetSchema DSL (apps/raggio_tabular/lib/raggio_tabular/sheet_schema.ex)

- [ ] T115 [US7] Implement column definition DSL with field_name, type, required, constraints
- [ ] T116 [US7] Implement header detection with multiple variant support
- [ ] T117 [US7] Implement row range filtering (from_row, to_row, skip_rows)
- [ ] T118 [US7] Implement union schemas for format variance

#### Parser Engine (apps/raggio_tabular/lib/raggio_tabular/parser.ex)

- [ ] T119 [US7] Implement CSV parsing with header detection
- [ ] T120 [US7] Implement row-by-row validation against schema
- [ ] T121 [US7] Implement row number tracking for error reporting
- [ ] T122 [US7] Implement valid/invalid row separation

#### Tabular Adapter (apps/raggio_tabular/lib/raggio_tabular/adapter.ex)

- [ ] T123 [US7] Implement batch row parsing with configurable batch size
- [ ] T124 [US7] Implement progress tracking callback
- [ ] T125 [US7] Implement error collection mode (fail-fast vs collect-all)
- [ ] T126 [US7] Return structured result with valid_rows, invalid_rows, error_details

#### Excel Transforms (apps/raggio_tabular/lib/raggio_tabular/transforms/excel.ex)

- [ ] T127 [P] [US7] Implement excel_decimal/1 for currency string cleaning ($1,234.56 -> 1234.56)
- [ ] T128 [P] [US7] Implement excel_integer/1 for float ID conversion (123.0 -> 123)
- [ ] T129 [P] [US7] Implement excel_string/1 for float-to-string ID conversion (123.0 -> "123")
- [ ] T130 [P] [US7] Implement excel_trim/1 for whitespace trimming

#### Raggio.Tabular Examples

- [ ] T131 [P] [US7] Create examples/raggio_tabular/csv_parsing/basic_csv.exs demonstrating CSV parsing
- [ ] T132 [P] [US7] Create examples/raggio_tabular/csv_parsing/header_variants.exs demonstrating header detection
- [ ] T133 [P] [US7] Create examples/raggio_tabular/excel_transforms/cleanup.exs demonstrating Excel transforms
- [ ] T134 [P] [US7] Create examples/raggio_tabular/advanced/union_schemas.exs demonstrating format variance

**Checkpoint**: User Story 7 complete - Tabular parsing functional

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements across all user stories

- [ ] T135 Create feature parity checklist comparing old_code to new packages in specs/001-monorepo-restructure/parity-checklist.md
- [ ] T136 Run mix format to format all code
- [ ] T137 Run mix compile to verify all packages compile
- [ ] T138 Run mix test to verify all tests pass
- [ ] T139 Update test/example_test.exs to verify all examples in examples/ compile and run
- [ ] T140 Run quickstart.md validation - verify all code snippets work
- [ ] T141 [P] Add @type specifications to all public functions in apps/raggio_schema/lib/raggio_schema.ex
- [ ] T142 [P] Add @type specifications to all public functions in apps/raggio_syntax/lib/raggio_syntax.ex
- [ ] T143 [P] Add @type specifications to all public functions in apps/raggio_tabular/lib/raggio_tabular.ex
- [ ] T144 Remove deprecated enum/1 function if present
- [ ] T145 Verify no macros in public API across all packages

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
- **User Story 7 (Phase 9)**: Depends on US1 - Tabular parsing
- **Polish (Phase 10)**: Depends on all desired user stories complete

### User Story Dependencies

- **US1 (P1 MVP)**: Foundation only - Can start first
- **US3 (P1 MVP)**: Depends on US1 - Examples need schemas
- **US2 (P2)**: Foundation only - Can parallel with US1
- **US4 (P2)**: Depends on US1 + US2 - Extensibility
- **US5 (P2)**: Depends on US1 - Export
- **US6 (P2)**: Depends on US1 - Import
- **US7 (P2)**: Depends on US1 - Tabular

### Parallel Opportunities

**Within Phase 3 (US1)**:
- All primitive type constructors (T016-T023) can run in parallel
- All composite type constructors (T024-T029) can run in parallel
- All field descriptors (T030-T031) can run in parallel
- All convenience helpers (T032-T034) can run in parallel

**Within Phase 5 (US2)**:
- All node structs (T061-T063) can run in parallel
- All protocol implementations (T064-T066) can run in parallel
- All node constructors (T067-T074) can run in parallel

**Across Phases**:
- All [P] tasks within a phase can run in parallel
- All example tasks across phases can run in parallel (different files)

---

## Parallel Example: User Story 1 Primitive Types

```bash
# Launch all primitive type constructors together:
T016: string/1 type constructor
T017: integer/1 type constructor
T018: float/1 type constructor
T019: boolean/1 type constructor
T020: date/1 type constructor
T021: datetime/1 type constructor
T022: decimal/1 type constructor
T023: atom/1 type constructor

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

1. Complete Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Test independently -> MVP! (validation works)
3. Add User Story 3 -> Test independently -> MVP! (examples work)
4. Add User Story 2 -> Test independently -> Syntax manipulation
5. Add User Story 4 -> Test independently -> Extensibility
6. Add User Stories 5-7 -> Test independently -> Adapters complete
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
   - Developer C: User Story 7 (tabular)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Many existing files already have partial implementations - update them to match new API spec
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
