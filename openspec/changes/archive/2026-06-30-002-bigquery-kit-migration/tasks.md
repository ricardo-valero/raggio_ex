# Tasks: BigQuery Kit Migration

All tasks shipped. Grouped by the original implementation phases.

## 1. Setup (Shared Infrastructure)

- [x] Add `{:telemetry, "~> 1.0"}` dependency to `mix.exs`
- [x] Create directory structure: `lib/raggio/bigquery/`, `lib/raggio/bigquery/differ/`, `lib/raggio/bigquery/migrator/`
- [x] Create directory structure: `lib/mix/tasks/raggio/bigquery/`
- [x] Create directory structure: `test/raggio/bigquery/`, `test/support/`
- [x] Run `mix deps.get` to fetch the telemetry dependency

## 2. Foundational (Core Behaviours and Infrastructure)

- [x] Create `HTTPClient` behaviour in `lib/raggio/bigquery/http_client.ex` with `request/5` callback
- [x] Create `Auth` behaviour in `lib/raggio/bigquery/auth.ex` with `get_token/1` and optional `refresh_token/2`
- [x] Create `MockHTTPClient` in `test/support/mock_http_client.ex` implementing the HTTPClient behaviour
- [x] Create `MockAuth` in `test/support/mock_auth.ex` implementing the Auth behaviour
- [x] Create `Telemetry` helper in `lib/raggio/bigquery/telemetry.ex` with `span/3`
- [x] Create `Retry` module in `lib/raggio/bigquery/retry.ex` with exponential backoff logic
- [x] Create `API` wrapper in `lib/raggio/bigquery/api.ex` (migrate from `old/bigquery_kit/lib/bigquery_kit/adapter.ex`, replacing HTTPoison with the HTTPClient behaviour)
- [x] Create tests for HTTPClient behaviour validation in `test/raggio/bigquery/http_client_test.exs`
- [x] Create tests for Auth behaviour validation in `test/raggio/bigquery/auth_test.exs`
- [x] Create tests for Telemetry in `test/raggio/bigquery/telemetry_test.exs`
- [x] Create tests for Retry in `test/raggio/bigquery/retry_test.exs`
- [x] Create tests for the API wrapper in `test/raggio/bigquery/api_test.exs`

## 3. User Story 1 - Define BigQuery Table Schema (P1)

- [x] Create tests for the Table behaviour in `test/raggio/bigquery/table_test.exs`
- [x] Create `Table` behaviour in `lib/raggio/bigquery/table.ex` with `__dataset__/0`, `__table__/0`, `__schema__/0`
- [x] Add `__using__` macro to Table with default implementations for optional callbacks
- [x] Add `to_create_table_ddl/0` delegating to `Raggio.Schema.Adapters.BigQuery.to_ddl/3`
- [x] Add `__qualified_name__/0` derived function returning `"dataset.table"`
- [x] Add optional `__time_partitioning__/0` and `__clustering__/0` callbacks

## 4. User Story 2 - Connect with Custom HTTP/Auth (P1)

- [x] Create tests for the Repo behaviour in `test/raggio/bigquery/repo_test.exs`
- [x] Create `Repo` behaviour in `lib/raggio/bigquery/repo.ex` with `config/0`, `status/0` (migrate from `old/bigquery_kit/lib/bigquery_kit/repo.ex`)
- [x] Add `__using__` macro to Repo with `otp_app` option and config resolution
- [x] Implement `status/0` calling the API wrapper through the HTTPClient/Auth adapters
- [x] Add telemetry instrumentation to Repo operations via `Telemetry.span/3`
- [x] Add retry logic to Repo operations for 429 errors via `Retry`
- [x] Create main module `lib/raggio/bigquery/bigquery.ex` with convenience aliases

## 5. User Story 3 - Push Schema Changes (P2)

- [x] Create tests for the Differ in `test/raggio/bigquery/differ_test.exs`
- [x] Create tests for the DDL generator in `test/raggio/bigquery/ddl_test.exs`
- [x] Create `Change` struct in `lib/raggio/bigquery/differ/change.ex` (migrate from old kit)
- [x] Create `RenameDetector` in `lib/raggio/bigquery/differ/rename_detector.ex` (migrate from old kit)
- [x] Create `Differ` in `lib/raggio/bigquery/differ.ex`, adapted to use `Raggio.Schema.Type`
- [x] Add unsupported-change detection to Differ (DROP COLUMN, narrowing types) with descriptive errors
- [x] Create `DDL` module in `lib/raggio/bigquery/ddl.ex` (migrate from old kit)
- [x] Create Mix task `mix raggio.bigquery.push` in `lib/mix/tasks/raggio/bigquery/push.ex`
- [x] Add interactive prompts for rename confirmation in the push task
- [x] Add `--force` flag support to the push task for skipping confirmations

## 6. User Story 4 - Generate Migration Files (P2)

- [x] Create tests for `Migrator.Generator` in `test/raggio/bigquery/migrator_test.exs`
- [x] Create `Migration` struct in `lib/raggio/bigquery/migration.ex` (migrate from old kit)
- [x] Create `Migrator.Generator` in `lib/raggio/bigquery/migrator/generator.ex` (migrate from old kit)
- [x] Create Mix task `mix raggio.bigquery.generate` in `lib/mix/tasks/raggio/bigquery/generate.ex`
- [x] Ensure migration files are created in `priv/raggio/bigquery/{dataset}/{version}_{name}/` with `up.sql` and `down.sql`

## 7. User Story 5 - Apply and Rollback Migrations (P2)

- [x] Create tests for `Migrator.Loader` in `test/raggio/bigquery/migrator_test.exs`
- [x] Create tests for `Migrator.Executor` in `test/raggio/bigquery/migrator_test.exs`
- [x] Create tests for `Migrator.Tracker` in `test/raggio/bigquery/migrator_test.exs`
- [x] Create `Migrator.Loader` in `lib/raggio/bigquery/migrator/loader.ex` (migrate from old kit)
- [x] Create `Migrator.Tracker` in `lib/raggio/bigquery/migrator/tracker.ex` (migrate from old kit)
- [x] Create `Migrator.Executor` in `lib/raggio/bigquery/migrator/executor.ex` (migrate from old kit)
- [x] Create main `Migrator` in `lib/raggio/bigquery/migrator.ex` coordinating loader, tracker, executor
- [x] Add telemetry events to migration operations
- [x] Create Mix task `mix raggio.bigquery.migrate` in `lib/mix/tasks/raggio/bigquery/migrate.ex`
- [x] Create Mix task `mix raggio.bigquery.rollback` in `lib/mix/tasks/raggio/bigquery/rollback.ex`
- [x] Create Mix task `mix raggio.bigquery.status` in `lib/mix/tasks/raggio/bigquery/status.ex`
- [x] Ensure the `_raggio_migrations` tracking table is auto-created on first migrate/status

## 8. User Story 6 - Insert and Merge Data (P3)

- [x] Create tests for `insert/2` in `test/raggio/bigquery/repo_test.exs`
- [x] Create tests for `merge/3` in `test/raggio/bigquery/repo_test.exs`
- [x] Implement `insert/2` in Repo (migrate insert logic from the old adapter)
- [x] Implement `insert/3` with options (`batch_size`, `skip_invalid_rows`)
- [x] Add auto-batching logic for inserts exceeding BigQuery streaming limits
- [x] Implement `merge/3` in Repo (migrate merge logic from the old adapter)
- [x] Add telemetry events for insert and merge operations

## 9. User Story 7 - Query Data (P3)

- [x] Create tests for `query/1` and `query/2` in `test/raggio/bigquery/repo_test.exs`
- [x] Implement `query/1` in Repo (migrate query logic from the old adapter)
- [x] Implement `query/2` with parameterized query support
- [x] Add telemetry events for query operations

## 10. Polish & Cross-Cutting Concerns

- [x] Update `lib/raggio.ex` to add the `Raggio.BigQuery` alias
- [x] Add module documentation to all public modules
- [x] Verify all tests pass with `mix test`
- [x] Run `mix format` for consistent formatting
- [x] Run `mix credo` for static analysis
- [x] Validate `quickstart.md` scenarios end-to-end with mock adapters
- [x] Verify zero dependencies on HTTP clients (Req, Finch, HTTPoison) in `mix.exs`
- [x] Verify zero dependencies on auth libraries (Goth) in `mix.exs`
