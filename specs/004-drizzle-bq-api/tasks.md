# Tasks: Drizzle-like Composable BigQuery API

**Input**: Design documents from `/specs/004-drizzle-bq-api/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included as this is a library requiring robust testing.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- All paths relative to repository root

## Path Conventions

Based on plan.md - single Elixir library:
- **Source**: `lib/raggio/bigquery/`
- **Tests**: `test/raggio/bigquery/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add new dependency and prepare project structure

- [x] T001 Add nimble_parsec dependency to mix.exs
- [x] T002 [P] Create lib/raggio/bigquery/ddl/ directory for parser modules
- [x] T003 [P] Create test/raggio/bigquery/ddl/ directory for parser tests
- [x] T004 Run mix deps.get to install nimble_parsec

---

## Phase 2: Adapter Foundation (FR-011 through FR-017)

**Purpose**: Define the canonical schema adapter architecture that enables bidirectional conversion between raggio.schema.Type and adapter-specific formats

**CRITICAL**: This phase establishes the Adapter behaviour that BigQuery and future adapters implement. Must complete before BigQuery adapter implementation.

**References**: spec.md FR-011-FR-017, research.md Decisions 7-9, contracts/adapter.ex

### Tests for Adapter Behaviour

- [x] T005 [P] Create test file test/raggio/schema/adapter_test.exs with behaviour compliance tests
- [x] T006 [P] Add test verifying Adapter behaviour defines to_schema/1 callback
- [x] T007 [P] Add test verifying Adapter behaviour defines from_schema/1 callback  
- [x] T008 [P] Add test verifying Adapter behaviour defines adapter_namespace/0 callback
- [x] T009 [P] Create test file test/raggio/schema/adapters/bigquery_test.exs
- [x] T010 [P] Add test for BigQuery.to_schema/1 converts TableDef to Type
- [x] T011 [P] Add test for BigQuery.to_schema/1 preserves metadata under :bigquery namespace
- [x] T012 [P] Add test for BigQuery.from_schema/1 converts Type to {:ok, TableDef}
- [x] T013 [P] Add test for BigQuery.from_schema/1 returns {:error, _} for incompatible types
- [x] T014 Add test for BigQuery.from_schema/1 emits warning for foreign adapter metadata (FR-017)
- [x] T015 Add test for round-trip: TableDef -> to_schema -> from_schema -> TableDef preserves structure

### Implementation for Adapter Behaviour

- [x] T016 Create lib/raggio/schema/adapter.ex with @callback definitions for to_schema/1, from_schema/1, adapter_namespace/0
- [x] T017 Add @moduledoc documenting the Adapter behaviour contract and metadata handling
- [x] T018 [P] Create lib/raggio/schema/adapters/ directory for adapter implementations
- [x] T019 Create lib/raggio/schema/adapters/bigquery.ex with @behaviour Raggio.Schema.Adapter
- [x] T020 Implement BigQuery.adapter_namespace/0 returning :bigquery
- [x] T021 Implement BigQuery.to_schema/1 converting TableDef columns to Type fields
- [x] T022 Implement BigQuery.to_schema/1 metadata preservation (partition_by, cluster_by under :bigquery key)
- [x] T023 Implement BigQuery.from_schema/1 converting Type to TableDef
- [x] T024 Implement BigQuery.from_schema/1 foreign metadata warning via Logger.warning
- [x] T025 Add type mapping functions: bigquery_type_to_schema/1 and schema_to_bigquery_type/1

**Checkpoint**: Adapter Foundation complete - bidirectional conversion between Type and BigQuery formats works

---

## Phase 3: Foundational (Blocking Prerequisites)

**Purpose**: Core data structures that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete. Depends on Phase 2 (Adapter Foundation) for type mapping functions.

- [x] T026 [P] Create Column struct in lib/raggio/bigquery/column.ex with name, type, mode, description, metadata fields
- [x] T027 [P] Create TableDef struct in lib/raggio/bigquery/table_def.ex with name, columns, partition_by, cluster_by, description, metadata fields
- [x] T028 [P] Create Dataset struct in lib/raggio/bigquery/dataset.ex with name, tables, location, metadata fields
- [x] T029 [P] Create Project struct in lib/raggio/bigquery/project.ex with project_id, datasets, metadata fields
- [x] T030 [P] Create Error struct in lib/raggio/bigquery/error.ex for validation errors with type, message, path fields
- [x] T031 Create validation functions for Project in lib/raggio/bigquery/project.ex (project_id format, unique datasets)
- [x] T032 Create validation functions for Dataset in lib/raggio/bigquery/dataset.ex (name format, unique tables)
- [x] T033 Create validation functions for TableDef in lib/raggio/bigquery/table_def.ex (name format, unique columns, valid partition/cluster)
- [x] T034 Create validation functions for Column in lib/raggio/bigquery/column.ex (name format, BigQuery-compatible type)
- [x] T035 [P] Create test file test/raggio/bigquery/column_test.exs with struct and validation tests
- [x] T036 [P] Create test file test/raggio/bigquery/table_def_test.exs with struct and validation tests
- [x] T037 [P] Create test file test/raggio/bigquery/dataset_test.exs with struct and validation tests
- [x] T038 [P] Create test file test/raggio/bigquery/project_test.exs with struct and validation tests

**Checkpoint**: Foundation ready - all structs exist and validate correctly

---

## Phase 4: User Story 1 - Define Composable BigQuery Project (Priority: P1)

**Goal**: Enable developers to define BigQuery schemas using composable, declarative API (project -> dataset -> table)

**Independent Test**: Define a project with 2 datasets and 3 tables, verify hierarchy is correct and accessible

### Tests for User Story 1

- [x] T039 [P] [US1] Create test file test/raggio/bigquery/composer_test.exs with project/dataset/table builder tests
- [x] T040 [P] [US1] Add test for project() function creates Context with project_id
- [x] T041 [P] [US1] Add test for dataset() function sets current dataset in Context
- [x] T042 [P] [US1] Add test for table() function adds TableDef to current dataset
- [x] T043 [P] [US1] Add test for build() function returns valid Project struct
- [x] T044 [P] [US1] Add test for column() helper creates Column with correct defaults
- [x] T045 [US1] Add integration test for full pipeline: project -> datasets -> tables -> build

### Implementation for User Story 1

- [x] T046 [P] [US1] Create Composer.Context struct in lib/raggio/bigquery/composer.ex with project_id, current_dataset, datasets, errors fields
- [x] T047 [US1] Implement project/1 and project/2 functions in lib/raggio/bigquery/composer.ex
- [x] T048 [US1] Implement dataset/2 and dataset/3 functions in lib/raggio/bigquery/composer.ex with flush logic
- [x] T049 [US1] Implement table/3 function in lib/raggio/bigquery/composer.ex
- [x] T050 [US1] Implement column/2 and column/3 helper functions in lib/raggio/bigquery/composer.ex
- [x] T051 [US1] Implement flush_current_dataset/1 private function in lib/raggio/bigquery/composer.ex
- [x] T052 [US1] Implement build/1 function in lib/raggio/bigquery/composer.ex returning {:ok, Project} or {:error, errors}
- [x] T053 [US1] Implement build!/1 function in lib/raggio/bigquery/composer.ex that raises on error
- [x] T054 [US1] Implement get_table/3 function in lib/raggio/bigquery/project.ex for table lookup
- [x] T055 [US1] Implement all_tables/1 function in lib/raggio/bigquery/project.ex to list all tables

**Checkpoint**: User Story 1 complete - developers can define project hierarchies with composable API

---

## Phase 5: User Story 4 - Effect-TS/Schema Style Composition (Priority: P2)

**Goal**: Enable functional composition patterns (pipe, transform, refine) for building complex schemas

**Independent Test**: Compose a schema with required(), repeated(), description() pipes and verify metadata is set correctly

### Tests for User Story 4

- [x] T056 [P] [US4] Add test for required/1 sets mode: :required in type metadata in test/raggio/bigquery/composer_test.exs
- [x] T057 [P] [US4] Add test for repeated/1 sets mode: :repeated in type metadata in test/raggio/bigquery/composer_test.exs
- [x] T058 [P] [US4] Add test for description/2 sets description in type metadata in test/raggio/bigquery/composer_test.exs
- [x] T059 [US4] Add test for pipe composition: Schema.string() |> required() |> description("test")

### Implementation for User Story 4

- [x] T060 [US4] Implement required/1 function in lib/raggio/bigquery/composer.ex that sets metadata.mode to :required
- [x] T061 [US4] Implement repeated/1 function in lib/raggio/bigquery/composer.ex that sets metadata.mode to :repeated
- [x] T062 [US4] Implement description/2 function in lib/raggio/bigquery/composer.ex that sets metadata.description
- [x] T063 [US4] Ensure Type struct metadata field is initialized to empty map in lib/raggio/schema/type.ex if not already
- [x] T064 [US4] Update column/3 to extract mode and description from type metadata in lib/raggio/bigquery/composer.ex

**Checkpoint**: User Story 4 complete - schemas can be composed with pipe operators

---

## Phase 6: User Story 2 - Generate DDL from Composed Schema (Priority: P2)

**Goal**: Generate valid BigQuery DDL statements (CREATE TABLE, CREATE SCHEMA) from composed Project

**Independent Test**: Generate DDL from a Project with partitioning/clustering, validate SQL syntax

### Tests for User Story 2

- [x] T065 [P] [US2] Create test file test/raggio/bigquery/ddl_generator_test.exs
- [x] T066 [P] [US2] Add test for TableDef.to_ddl/2 generates valid CREATE TABLE DDL
- [x] T067 [P] [US2] Add test for DDL includes PARTITION BY clause when partition_by is set
- [x] T068 [P] [US2] Add test for DDL includes CLUSTER BY clause when cluster_by is set
- [x] T069 [P] [US2] Add test for nested STRUCT types render correctly in DDL
- [x] T070 [P] [US2] Add test for ARRAY types render correctly in DDL
- [x] T071 [US2] Add test for Project.to_ddl/2 generates DDL for all tables across datasets

### Implementation for User Story 2

- [x] T072 [US2] Implement to_ddl/2 function in lib/raggio/bigquery/table_def.ex for single table DDL generation
- [x] T073 [US2] Implement column_to_ddl/1 private function in lib/raggio/bigquery/table_def.ex
- [x] T074 [US2] Implement type_to_ddl/1 private function in lib/raggio/bigquery/table_def.ex handling all raggio.schema types
- [x] T075 [US2] Implement partition_clause/1 private function in lib/raggio/bigquery/table_def.ex for PARTITION BY
- [x] T076 [US2] Implement cluster_clause/1 private function in lib/raggio/bigquery/table_def.ex for CLUSTER BY
- [x] T077 [US2] Implement to_create_schema_ddl/2 in lib/raggio/bigquery/dataset.ex for CREATE SCHEMA
- [x] T078 [US2] Implement to_ddl/2 in lib/raggio/bigquery/project.ex that generates DDL for entire project
- [x] T079 [US2] Implement to_bigquery_schema/1 in lib/raggio/bigquery/table_def.ex for REST API format

**Checkpoint**: User Story 2 complete - DDL can be generated from any composed Project

---

## Phase 7: User Story 3 - Parse DDL into Schema Definitions (Priority: P3)

**Goal**: Parse BigQuery CREATE TABLE DDL into raggio schema definitions using NimbleParsec

**Independent Test**: Parse a DDL with nested STRUCT and ARRAY types, verify schema matches

### Tests for User Story 3

- [x] T080 [P] [US3] Create test file test/raggio/bigquery/ddl/parser_test.exs
- [x] T081 [P] [US3] Add test for parse_type/1 parses simple types (STRING, INT64, BOOL, etc.)
- [x] T082 [P] [US3] Add test for parse_type/1 parses ARRAY<element_type>
- [x] T083 [P] [US3] Add test for parse_type/1 parses STRUCT<field1 type1, field2 type2>
- [x] T084 [P] [US3] Add test for parse_type/1 parses nested STRUCT<ARRAY<STRUCT<...>>>
- [x] T085 [P] [US3] Add test for parse_create_table/1 parses full CREATE TABLE statement
- [x] T086 [P] [US3] Add test for parse_create_table/1 extracts PARTITION BY and CLUSTER BY
- [x] T087 [P] [US3] Add test for parse error includes line and column position
- [x] T088 [US3] Add test for to_table_def/1 converts parsed DDL to TableDef struct
- [x] T089 [US3] Add test for round-trip: TableDef -> DDL -> parse -> TableDef preserves structure

### Implementation for User Story 3

- [x] T090 [P] [US3] Create lib/raggio/bigquery/ddl/parser/helpers.ex with whitespace, keyword, identifier combinators
- [x] T091 [US3] Implement simple_types combinator in lib/raggio/bigquery/ddl/parser.ex for STRING, INT64, FLOAT64, BOOL, etc.
- [x] T092 [US3] Implement array_type combinator in lib/raggio/bigquery/ddl/parser.ex using parsec recursion
- [x] T093 [US3] Implement struct_type combinator in lib/raggio/bigquery/ddl/parser.ex with field list
- [x] T094 [US3] Implement data_type combinator in lib/raggio/bigquery/ddl/parser.ex combining simple, array, struct
- [x] T095 [US3] Implement column_definition combinator in lib/raggio/bigquery/ddl/parser.ex
- [x] T096 [US3] Implement partition_clause combinator in lib/raggio/bigquery/ddl/parser.ex
- [x] T097 [US3] Implement cluster_clause combinator in lib/raggio/bigquery/ddl/parser.ex
- [x] T098 [US3] Implement create_table_statement combinator in lib/raggio/bigquery/ddl/parser.ex
- [x] T099 [US3] Implement parse_create_table/1 public function in lib/raggio/bigquery/ddl/parser.ex
- [x] T100 [US3] Implement parse_type/1 public function in lib/raggio/bigquery/ddl/parser.ex
- [x] T101 [US3] Implement parse/1 public function in lib/raggio/bigquery/ddl/parser.ex with auto-detection
- [x] T102 [US3] Create Parser.Error struct in lib/raggio/bigquery/ddl/parser/error.ex with line, column, message
- [x] T103 [US3] Implement Error.format/1 for user-friendly error messages in lib/raggio/bigquery/ddl/parser/error.ex
- [x] T104 [US3] Implement to_table_def/2 in lib/raggio/bigquery/ddl/parser.ex converting parsed DDL to TableDef
- [x] T105 [US3] Implement to_schema_type/1 in lib/raggio/bigquery/ddl/parser.ex converting parsed types to Schema.Type
- [x] T106 [US3] Implement to_syntax_ast/1 in lib/raggio/bigquery/ddl/parser.ex converting to raggio.syntax AST

**Checkpoint**: User Story 3 complete - DDL can be parsed and converted to raggio schemas

---

## Phase 8: Integration & Backward Compatibility

**Purpose**: Ensure new API works with existing Table behaviour

- [x] T107 [P] Add test for from_modules/2 converts Table behaviour modules to Project in test/raggio/bigquery/composer_test.exs
- [x] T108 Implement from_modules/2 function in lib/raggio/bigquery/composer.ex
- [x] T109 Add test verifying existing use Raggio.BigQuery.Table modules still work
- [x] T110 Update lib/raggio/bigquery.ex to export new modules (Project, Dataset, Composer, DDL.Parser)
- [x] T111 Update lib/raggio/bigquery.ex to export Adapter module (Raggio.Schema.Adapters.BigQuery)

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final validation

- [x] T112 [P] Add @moduledoc and @doc to all new modules
- [x] T113 [P] Add typespecs to all public functions
- [x] T114 Run mix format on all new files
- [x] T115 Run mix credo and fix any issues
- [x] T116 Run full test suite: mix test
- [x] T117 Validate quickstart.md examples work correctly
- [x] T118 Update lib/raggio.ex to include Composer and Adapter in main module exports

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Adapter Foundation (Phase 2)**: Depends on Setup - BLOCKS BigQuery structs (defines type mapping)
- **Foundational (Phase 3)**: Depends on Phase 2 (uses type mapping from Adapter)
- **User Story 1 (Phase 4)**: Depends on Phase 3 (Foundational)
- **User Story 4 (Phase 5)**: Depends on Phase 4 (User Story 1, uses column/3)
- **User Story 2 (Phase 6)**: Depends on Phase 4 (User Story 1, needs structs to generate DDL from)
- **User Story 3 (Phase 7)**: Can start after Phase 3 (independent parser, but uses TableDef)
- **Integration (Phase 8)**: Depends on Phases 4-7 (all user stories)
- **Polish (Phase 9)**: Depends on all phases

### User Story Dependencies

- **Adapter (P0)**: Setup only - foundational for all adapters (FR-011 through FR-017)
- **User Story 1 (P1)**: Adapter + Foundational - can start after Phase 3
- **User Story 4 (P2)**: Depends on US1 (extends Composer)
- **User Story 2 (P2)**: Depends on US1 (generates DDL from structs)
- **User Story 3 (P3)**: Foundational only - can run in parallel with US1/US2/US4

### Within Each User Story

- Tests written FIRST, verified to FAIL
- Structs/modules before functions
- Private helpers before public API
- Integration tests after implementation

### Parallel Opportunities

**Phase 2 (Adapter Foundation)**:
```
T005, T006, T007, T008 (adapter behaviour tests in parallel)
T009, T010, T011, T012, T013 (BigQuery adapter tests in parallel)
```

**Phase 3 (Foundational)**:
```
T026, T027, T028, T029, T030 (all struct files in parallel)
T035, T036, T037, T038 (all test files in parallel)
```

**Phase 4 (US1 Tests)**:
```
T039, T040, T041, T042, T043, T044 (all test cases in parallel)
```

**Phase 7 (US3 Tests)**:
```
T080-T087 (all parser test cases in parallel)
```

---

## Parallel Example: User Story 1 Implementation

```bash
# After T046 (Context struct), launch in parallel:
Task: T047 "Implement project/1 and project/2"
Task: T050 "Implement column/2 and column/3"

# After T047, T048, T049, T050 complete:
Task: T051 "Implement flush_current_dataset/1"
Task: T052 "Implement build/1"
```

---

## Implementation Strategy

### MVP First (Adapter + User Story 1)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Adapter Foundation (T005-T025) - **NEW FOUNDATIONAL PHASE**
3. Complete Phase 3: Foundational (T026-T038)
4. Complete Phase 4: User Story 1 (T039-T055)
5. **STOP and VALIDATE**: Test composable API + bidirectional schema conversion independently
6. Deliverable: Developers can define BigQuery projects with Drizzle-like API AND convert to/from raggio.schema.Type

### Incremental Delivery

1. Setup + Adapter Foundation -> Adapter behaviour + BigQuery adapter exist
2. Foundational -> BigQuery structs exist with validation
3. User Story 1 -> Composable API works -> **MVP Ready**
4. User Story 4 -> Pipe composition (required(), repeated()) works
5. User Story 2 -> DDL generation works
6. User Story 3 -> DDL parsing works -> **Feature Complete**

### Recommended Execution Order

```
Phase 1 (Setup)
    ↓
Phase 2 (Adapter Foundation) ─── NEW: Defines canonical schema contract
    ↓
Phase 3 (Foundational)
    ↓
Phase 4 (US1 - Composable API) ─────────────→ Phase 7 (US3 - Parser) [parallel track]
    ↓                                                ↓
Phase 5 (US4 - Pipe Composition)                     ↓
    ↓                                                ↓
Phase 6 (US2 - DDL Generation)                       ↓
    ↓                                                ↓
    └──────────────→ Phase 8 (Integration) ←─────────┘
                            ↓
                    Phase 9 (Polish)
```

---

## Notes

- **Total Tasks**: 118 (increased from 96 to include Adapter Foundation tasks)
- **New Phase**: Phase 2 (Adapter Foundation) adds 21 tasks (T005-T025) for FR-011 through FR-017
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- NimbleParsec is new dependency - ensure mix deps.get runs first
- Existing `use Raggio.BigQuery.Table` pattern must continue working
- Run tests after each phase checkpoint
- Adapter behaviour is foundational - defines the contract for bidirectional schema conversion between raggio.schema.Type and adapter-specific formats
