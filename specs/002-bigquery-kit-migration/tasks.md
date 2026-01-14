# Tasks: BigQuery Kit Migration

**Input**: Design documents from `/specs/002-bigquery-kit-migration/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are included - the spec requires 95%+ test coverage (SC-007).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Elixir single package**: `lib/raggio/bigquery/`, `lib/mix/tasks/raggio/bigquery/`, `test/raggio/bigquery/`
- **Migration source**: `old/bigquery_kit/lib/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency configuration

- [x] T001 Add `{:telemetry, "~> 1.0"}` dependency to mix.exs
- [x] T002 Create directory structure: `lib/raggio/bigquery/`, `lib/raggio/bigquery/differ/`, `lib/raggio/bigquery/migrator/`
- [x] T003 [P] Create directory structure: `lib/mix/tasks/raggio/bigquery/`
- [x] T004 [P] Create directory structure: `test/raggio/bigquery/`, `test/support/`
- [x] T005 Run `mix deps.get` to fetch telemetry dependency

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core behaviours and infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 [P] Create HTTPClient behaviour in `lib/raggio/bigquery/http_client.ex` with `request/5` callback
- [x] T007 [P] Create Auth behaviour in `lib/raggio/bigquery/auth.ex` with `get_token/1` and optional `refresh_token/2` callbacks
- [x] T008 [P] Create MockHTTPClient in `test/support/mock_http_client.ex` implementing HTTPClient behaviour
- [x] T009 [P] Create MockAuth in `test/support/mock_auth.ex` implementing Auth behaviour
- [x] T010 [P] Create Telemetry helper module in `lib/raggio/bigquery/telemetry.ex` with `span/3` function
- [x] T011 [P] Create Retry module in `lib/raggio/bigquery/retry.ex` with exponential backoff logic
- [x] T012 Create API wrapper module in `lib/raggio/bigquery/api.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/adapter.ex`, replace HTTPoison with HTTPClient behaviour)
- [x] T013 [P] Create tests for HTTPClient behaviour validation in `test/raggio/bigquery/http_client_test.exs`
- [x] T014 [P] Create tests for Auth behaviour validation in `test/raggio/bigquery/auth_test.exs`
- [x] T015 [P] Create tests for Telemetry in `test/raggio/bigquery/telemetry_test.exs`
- [x] T016 [P] Create tests for Retry in `test/raggio/bigquery/retry_test.exs`
- [x] T017 Create tests for API wrapper in `test/raggio/bigquery/api_test.exs`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Define BigQuery Table Schema (Priority: P1) 🎯 MVP

**Goal**: Developers can define BigQuery table schemas using Raggio.Schema with BigQuery-specific metadata

**Independent Test**: Define a schema with Raggio.Schema, implement Table behaviour, call `to_create_table_ddl/0` to verify DDL generation

### Tests for User Story 1

- [x] T018 [P] [US1] Create tests for Table behaviour in `test/raggio/bigquery/table_test.exs`

### Implementation for User Story 1

- [x] T019 [US1] Create Table behaviour in `lib/raggio/bigquery/table.ex` with `__dataset__/0`, `__table__/0`, `__schema__/0` callbacks
- [x] T020 [US1] Add `__using__` macro to Table with default implementations for optional callbacks
- [x] T021 [US1] Add `to_create_table_ddl/0` function delegating to `Raggio.Schema.Adapters.BigQuery.to_ddl/3`
- [x] T022 [US1] Add `__qualified_name__/0` derived function returning `"dataset.table"`
- [x] T023 [US1] Add optional `__time_partitioning__/0` and `__clustering__/0` callbacks

**Checkpoint**: User Story 1 complete - Table schemas can be defined and exported to DDL

---

## Phase 4: User Story 2 - Connect to BigQuery with Custom HTTP/Auth (Priority: P1)

**Goal**: Developers can connect to BigQuery using their organization's preferred HTTP client and auth method

**Independent Test**: Implement mock adapters, configure Repo, call `status/0` to verify connectivity through adapter chain

### Tests for User Story 2

- [x] T024 [P] [US2] Create tests for Repo behaviour in `test/raggio/bigquery/repo_test.exs`

### Implementation for User Story 2

- [x] T025 [US2] Create Repo behaviour in `lib/raggio/bigquery/repo.ex` with `config/0`, `status/0` callbacks (migrate from `old/bigquery_kit/lib/bigquery_kit/repo.ex`)
- [x] T026 [US2] Add `__using__` macro to Repo with `otp_app` option and config resolution
- [x] T027 [US2] Implement `status/0` that calls API wrapper through HTTPClient/Auth adapters
- [x] T028 [US2] Add telemetry instrumentation to Repo operations via `Raggio.BigQuery.Telemetry.span/3`
- [x] T029 [US2] Add retry logic to Repo operations for 429 errors via `Raggio.BigQuery.Retry`
- [x] T030 [US2] Create main module `lib/raggio/bigquery/bigquery.ex` with convenience aliases

**Checkpoint**: User Stories 1 AND 2 complete - Core behaviours working, foundation for all other stories

---

## Phase 5: User Story 3 - Push Schema Changes (Priority: P2)

**Goal**: Developers can quickly sync local schema changes to BigQuery during development

**Independent Test**: Define a schema, run push, verify BigQuery table matches (using mock adapters)

### Tests for User Story 3

- [x] T031 [P] [US3] Create tests for Differ in `test/raggio/bigquery/differ_test.exs`
- [x] T032 [P] [US3] Create tests for DDL generator in `test/raggio/bigquery/ddl_test.exs`

### Implementation for User Story 3

- [x] T033 [P] [US3] Create Change struct in `lib/raggio/bigquery/differ/change.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/differ/change.ex`)
- [x] T034 [P] [US3] Create RenameDetector in `lib/raggio/bigquery/differ/rename_detector.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/differ/rename_detector.ex`)
- [x] T035 [US3] Create Differ module in `lib/raggio/bigquery/differ.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/differ.ex`, adapt to use Raggio.Schema.Type)
- [x] T036 [US3] Add unsupported change detection to Differ (DROP COLUMN, narrowing types) with descriptive errors
- [x] T037 [US3] Create DDL module in `lib/raggio/bigquery/ddl.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/ddl.ex`)
- [x] T038 [US3] Create Mix task `mix raggio.bigquery.push` in `lib/mix/tasks/raggio/bigquery/push.ex`
- [x] T039 [US3] Add interactive prompts for rename confirmation in push task
- [x] T040 [US3] Add `--force` flag support to push task for skipping confirmations

**Checkpoint**: User Story 3 complete - Schema push workflow functional

---

## Phase 6: User Story 4 - Generate Migration Files (Priority: P2)

**Goal**: Developers can generate timestamped migration files for version control

**Independent Test**: Change schema, run generate, inspect migration files for valid DDL

### Tests for User Story 4

- [ ] T041 [P] [US4] Create tests for Migrator.Generator in `test/raggio/bigquery/migrator_test.exs`

### Implementation for User Story 4

- [ ] T042 [US4] Create Migration struct in `lib/raggio/bigquery/migration.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/migration.ex`)
- [ ] T043 [US4] Create Migrator.Generator in `lib/raggio/bigquery/migrator/generator.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/migrator/generator.ex`)
- [ ] T044 [US4] Create Mix task `mix raggio.bigquery.generate` in `lib/mix/tasks/raggio/bigquery/generate.ex`
- [ ] T045 [US4] Ensure migration files are created in `priv/raggio/bigquery/{dataset}/{version}_{name}/` with up.sql and down.sql

**Checkpoint**: User Story 4 complete - Migration generation workflow functional

---

## Phase 7: User Story 5 - Apply and Rollback Migrations (Priority: P2)

**Goal**: Developers can apply pending migrations and rollback if issues arise

**Independent Test**: Generate migration, apply it, verify schema changed, rollback, verify revert

### Tests for User Story 5

- [ ] T046 [P] [US5] Create tests for Migrator.Loader in `test/raggio/bigquery/migrator_test.exs`
- [ ] T047 [P] [US5] Create tests for Migrator.Executor in `test/raggio/bigquery/migrator_test.exs`
- [ ] T048 [P] [US5] Create tests for Migrator.Tracker in `test/raggio/bigquery/migrator_test.exs`

### Implementation for User Story 5

- [ ] T049 [P] [US5] Create Migrator.Loader in `lib/raggio/bigquery/migrator/loader.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/migrator/loader.ex`)
- [ ] T050 [P] [US5] Create Migrator.Tracker in `lib/raggio/bigquery/migrator/tracker.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/migrator/tracker.ex`)
- [ ] T051 [US5] Create Migrator.Executor in `lib/raggio/bigquery/migrator/executor.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/migrator/executor.ex`)
- [ ] T052 [US5] Create main Migrator module in `lib/raggio/bigquery/migrator.ex` coordinating loader, tracker, executor
- [ ] T053 [US5] Add telemetry events to migration operations
- [ ] T054 [US5] Create Mix task `mix raggio.bigquery.migrate` in `lib/mix/tasks/raggio/bigquery/migrate.ex`
- [ ] T055 [US5] Create Mix task `mix raggio.bigquery.rollback` in `lib/mix/tasks/raggio/bigquery/rollback.ex`
- [ ] T056 [US5] Create Mix task `mix raggio.bigquery.status` in `lib/mix/tasks/raggio/bigquery/status.ex`
- [ ] T057 [US5] Ensure `_raggio_migrations` tracking table auto-created on first migrate/status

**Checkpoint**: User Story 5 complete - Full migration workflow functional

---

## Phase 8: User Story 6 - Insert and Merge Data (Priority: P3)

**Goal**: Developers can insert and merge (upsert) data into BigQuery tables

**Independent Test**: Insert rows, query to verify they exist; merge rows, verify upsert behavior

### Tests for User Story 6

- [ ] T058 [P] [US6] Create tests for insert/2 in `test/raggio/bigquery/repo_test.exs`
- [ ] T059 [P] [US6] Create tests for merge/3 in `test/raggio/bigquery/repo_test.exs`

### Implementation for User Story 6

- [ ] T060 [US6] Implement `insert/2` in Repo (migrate insert logic from `old/bigquery_kit/lib/bigquery_kit/adapter.ex`)
- [ ] T061 [US6] Implement `insert/3` with options (batch_size, skip_invalid_rows)
- [ ] T062 [US6] Add auto-batching logic for inserts exceeding 5000 rows
- [ ] T063 [US6] Implement `merge/3` in Repo (migrate merge logic from `old/bigquery_kit/lib/bigquery_kit/adapter.ex`)
- [ ] T064 [US6] Add telemetry events for insert and merge operations

**Checkpoint**: User Story 6 complete - Data write operations functional

---

## Phase 9: User Story 7 - Query Data (Priority: P3)

**Goal**: Developers can query data from BigQuery tables

**Independent Test**: Insert data, query to retrieve it

### Tests for User Story 7

- [ ] T065 [P] [US7] Create tests for query/1 and query/2 in `test/raggio/bigquery/repo_test.exs`

### Implementation for User Story 7

- [ ] T066 [US7] Implement `query/1` in Repo (migrate query logic from `old/bigquery_kit/lib/bigquery_kit/adapter.ex`)
- [ ] T067 [US7] Implement `query/2` with parameterized queries support
- [ ] T068 [US7] Add telemetry events for query operations

**Checkpoint**: User Story 7 complete - All Repo operations functional

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final validation

- [ ] T069 [P] Update `lib/raggio.ex` to add `Raggio.BigQuery` alias
- [ ] T070 [P] Add module documentation to all public modules
- [ ] T071 Verify all tests pass with `mix test`
- [ ] T072 Run `mix format` to ensure consistent formatting
- [ ] T073 Run `mix credo` for static analysis (if configured)
- [ ] T074 Validate quickstart.md scenarios work end-to-end with mock adapters
- [ ] T075 Verify zero dependencies on HTTP clients (Req, Finch, HTTPoison) in mix.exs
- [ ] T076 Verify zero dependencies on auth libraries (Goth) in mix.exs

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational
- **US2 (Phase 4)**: Depends on Foundational
- **US3 (Phase 5)**: Depends on US1, US2 (needs Table for schemas, Repo for API calls)
- **US4 (Phase 6)**: Depends on US3 (needs Differ, DDL)
- **US5 (Phase 7)**: Depends on US4 (needs migration generation)
- **US6 (Phase 8)**: Depends on US2 (needs Repo)
- **US7 (Phase 9)**: Depends on US2 (needs Repo)
- **Polish (Phase 10)**: Depends on all user stories

### User Story Dependencies

```
Setup → Foundational → US1 (Table) ─────────────────────┐
                    └→ US2 (Repo/Connect) ──┬──→ US3 (Push) → US4 (Generate) → US5 (Migrate)
                                            ├──→ US6 (Insert/Merge)
                                            └──→ US7 (Query)
```

### Within Each User Story

- Tests SHOULD be written before implementation (TDD)
- Data structs before modules using them
- Core implementation before Mix tasks
- Story complete before moving to next priority

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T006, T007, T008, T009, T010, T011 can all run in parallel (different files)
- T013, T014, T015, T016 can all run in parallel (different test files)

**Phase 3-4 (US1 + US2)**:
- US1 and US2 can be worked on in parallel after Foundational

**Phase 5 (US3)**:
- T033, T034 can run in parallel (Change struct, RenameDetector)

**Phase 7 (US5)**:
- T046, T047, T048 can run in parallel (test files)
- T049, T050 can run in parallel (Loader, Tracker)

**Phase 8-9 (US6 + US7)**:
- US6 and US7 can be worked on in parallel (both only depend on US2)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch all behaviours together:
Task: "Create HTTPClient behaviour in lib/raggio/bigquery/http_client.ex"
Task: "Create Auth behaviour in lib/raggio/bigquery/auth.ex"

# Launch all mock adapters together:
Task: "Create MockHTTPClient in test/support/mock_http_client.ex"
Task: "Create MockAuth in test/support/mock_auth.ex"

# Launch all utility modules together:
Task: "Create Telemetry helper in lib/raggio/bigquery/telemetry.ex"
Task: "Create Retry module in lib/raggio/bigquery/retry.ex"

# Launch all tests together:
Task: "Create tests for HTTPClient in test/raggio/bigquery/http_client_test.exs"
Task: "Create tests for Auth in test/raggio/bigquery/auth_test.exs"
Task: "Create tests for Telemetry in test/raggio/bigquery/telemetry_test.exs"
Task: "Create tests for Retry in test/raggio/bigquery/retry_test.exs"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Table behaviour)
4. Complete Phase 4: User Story 2 (Repo/Connection)
5. **STOP and VALIDATE**: Developers can define schemas and connect to BigQuery
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 + US2 → Test independently → **MVP: Schema definition + Connection**
3. Add US3 → Test independently → **Dev workflow: Push**
4. Add US4 + US5 → Test independently → **Production workflow: Migrations**
5. Add US6 + US7 → Test independently → **Data operations: Insert/Query**
6. Each story adds value without breaking previous stories

### Suggested MVP Scope

**MVP = Phase 1 + Phase 2 + Phase 3 + Phase 4** (Setup + Foundational + US1 + US2)

This gives developers:
- Table behaviour for defining schemas
- HTTPClient and Auth behaviours for pluggable adapters
- Repo with status/0 for connection verification
- Full agnostic architecture in place

All subsequent stories build on this foundation.

---

## Summary

| Phase | User Story | Priority | Tasks | Parallel |
|-------|------------|----------|-------|----------|
| 1 | Setup | - | 5 | 3 |
| 2 | Foundational | - | 12 | 10 |
| 3 | US1: Table Schema | P1 | 6 | 1 |
| 4 | US2: Connect | P1 | 7 | 1 |
| 5 | US3: Push | P2 | 10 | 4 |
| 6 | US4: Generate | P2 | 5 | 1 |
| 7 | US5: Migrate/Rollback | P2 | 12 | 6 |
| 8 | US6: Insert/Merge | P3 | 7 | 2 |
| 9 | US7: Query | P3 | 4 | 1 |
| 10 | Polish | - | 8 | 2 |
| **Total** | | | **76** | **31** |

**Independent Test Criteria**:
- US1: Define schema → call `to_create_table_ddl/0` → verify DDL
- US2: Configure Repo → call `status/0` → verify `:connected`
- US3: Change schema → run push → verify table updated (via mock)
- US4: Change schema → run generate → verify files created
- US5: Generate migration → run migrate → run rollback → verify state
- US6: Call insert → call query → verify rows exist
- US7: Call query → verify results returned
