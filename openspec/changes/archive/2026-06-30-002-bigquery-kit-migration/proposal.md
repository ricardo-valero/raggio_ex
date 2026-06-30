# Proposal: BigQuery Kit Migration

## Why

The existing BigQuery Kit lived in `old/bigquery_kit/` with hard dependencies on
HTTPoison (HTTP transport) and bespoke credential handling (auth). This coupled the
library to specific HTTP and auth implementations and kept it outside the new single
package architecture established in 001-monorepo-restructure. We need a `Raggio.BigQuery`
submodule that reuses `Raggio.Schema` for type definitions and DDL export, while
staying HTTP-client agnostic and auth agnostic so any consumer can plug in Req, Finch,
HTTPoison, Goth, ADC, workload identity, etc., without the library taking a dependency
on any of them.

## What Changes

- Migrate `old/bigquery_kit/` into the `Raggio.BigQuery` submodule namespace under
  `lib/raggio/bigquery/` (single package, not an umbrella app).
- Extract HTTP transport behind a new `Raggio.BigQuery.HTTPClient` behaviour and
  authentication behind a new `Raggio.BigQuery.Auth` behaviour. Drop the old
  `BigQueryKit.Adapter` (HTTPoison) and `BigQueryKit.Credentials`.
- Define table schemas via the new `Raggio.BigQuery.Table` behaviour, which combines
  `Raggio.Schema` type definitions with BigQuery metadata (dataset, table, partitioning,
  clustering) and delegates DDL/JSON-schema generation to `Raggio.Schema.Adapters.BigQuery`.
- Provide `Raggio.BigQuery.Repo` (behaviour + `__using__` macro) for connection management
  and data operations (`status/0`, `insert`, `merge`, `query`, schema operations).
- Port schema diffing (`Differ`, `Change`, `RenameDetector`), DDL generation (`DDL`), and
  the migrator stack (`Migrator`, `Loader`, `Generator`, `Executor`, `Tracker`) to use
  `Raggio.Schema.Type`, and add unsupported-change detection (DROP COLUMN, narrowing types).
- Rename the Mix tasks from `bq_kit.*` to `mix raggio.bigquery.{push,generate,migrate,rollback,status}`.
- Add new cross-cutting infrastructure: `Raggio.BigQuery.API` (REST v2 wrapper),
  `Raggio.BigQuery.Retry` (exponential backoff with jitter for 429s), and
  `Raggio.BigQuery.Telemetry` (telemetry span helpers).
- Add the `{:telemetry, "~> 1.0"}` dependency. Keep zero dependencies on HTTP clients or
  auth libraries.

## Capabilities

### New Capabilities

- `bigquery`: A BigQuery repo/migration/DDL kit for Elixir built on `Raggio.Schema`.
  Provides HTTP-agnostic and auth-agnostic adapters (HTTPClient/Auth behaviours), a Repo
  for connection and data operations, a Table behaviour for schema-backed table metadata
  and DDL export, schema diffing with rename detection, file-based up/down migrations with
  applied-migration tracking, Mix tasks for the push/migrate workflow, automatic retry on
  rate limits, and telemetry instrumentation.

### Modified Capabilities

- `schema`: None. This change consumes the existing `Raggio.Schema` type system and the
  existing `Raggio.Schema.Adapters.BigQuery` DDL adapter (delivered in 001-monorepo-restructure)
  without modifying their behaviour.

## Impact

- New: `lib/raggio/bigquery/*` (bigquery, repo, table, http_client, auth, api, retry,
  telemetry, differ + differ/change + differ/rename_detector, ddl, migration, migrator +
  migrator/{loader,generator,executor,tracker}).
- New Mix tasks: `lib/mix/tasks/raggio/bigquery/{push,generate,migrate,rollback,status}.ex`.
- Consumes existing `lib/raggio/schema/adapters/bigquery.ex` for type mapping and DDL.
- Migration artifacts written to `priv/raggio/bigquery/{dataset}/{version}_{name}/{up,down}.sql`.
- Applied-migration tracking table `{dataset}._raggio_migrations` created in BigQuery.
- New dependency: `{:telemetry, "~> 1.0"}`. No HTTP client or auth library dependencies added.
- Tests: `test/raggio/bigquery/*` plus mock adapters in `test/support/{mock_http_client,mock_auth}.ex`.
- Removed from scope: `old/bigquery_kit/` modules `Adapter`, `Credentials`, `Schema`,
  `Dataset`, `Exporter` (dropped/replaced).
