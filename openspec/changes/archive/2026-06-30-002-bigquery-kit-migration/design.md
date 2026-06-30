# Design: BigQuery Kit Migration

## Context

The legacy BigQuery Kit (`old/bigquery_kit/`) was a working schema-migration and data
toolkit for BigQuery, but it baked in HTTPoison for transport and a custom credentials
module for auth, and it predated the single-package architecture adopted in
001-monorepo-restructure. At the same time, `Raggio.Schema` and
`Raggio.Schema.Adapters.BigQuery` now provide a composable type system and BigQuery DDL
export. This change re-homes the kit as the `Raggio.BigQuery` submodule, swaps the baked-in
transport/auth for pluggable behaviours, and reuses `Raggio.Schema` for all type and DDL
concerns. The target is functional parity with the old kit plus agnosticism, observability,
and rate-limit resilience.

## Goals / Non-Goals

**Goals:**

- HTTP-client agnostic: the library compiles and runs with zero dependency on Req, Finch,
  HTTPoison, Mint, or any HTTP client.
- Auth agnostic: zero dependency on Goth or any specific auth/OAuth library.
- Reuse `Raggio.Schema` for type definitions and `Raggio.Schema.Adapters.BigQuery` for DDL
  and BigQuery JSON-schema export.
- Single package with submodules (like Ecto), not an umbrella app.
- Preserve the proven migration workflow from the old kit: file-based up/down migrations,
  applied-migration tracking, push/generate/migrate/rollback/status.
- Add observability (telemetry) and automatic retry on rate limiting.
- High unit-test coverage using mock HTTP/Auth adapters (no real BigQuery calls in unit tests).

**Non-Goals:**

- Shipping default HTTP adapters (`raggio_bigquery_req`) or auth adapters
  (`raggio_bigquery_goth`) — those are separate optional packages.
- Publishing to Hex.pm as part of this change.
- Tabular data parsing features (those belong to `Raggio.Tabular`).
- Real BigQuery integration testing infrastructure (unit tests use mocks only).
- Supporting destructive schema changes natively (DROP COLUMN / narrowing types) — these
  fail with guidance rather than being auto-applied.

## Decisions

### HTTP transport abstraction via behaviour

Use a `Raggio.BigQuery.HTTPClient` behaviour with a single
`request(method, url, headers, body, opts) :: {:ok, %{status, headers, body}} | {:error, reason}`
callback. Behaviours give compile-time verification (unlike MFA tuples) and no runtime
penalty, mirroring Tesla/Ecto adapter patterns. Protocols (data polymorphism) and optional
dependencies (still transitive) were rejected. The library always injects
`Authorization: Bearer <token>` and `Content-Type: application/json`; implementations only
translate to their client and normalize the response shape.

### Auth abstraction via behaviour

Use a `Raggio.BigQuery.Auth` behaviour with `get_token(config) :: {:ok, token} | {:error, reason}`
and an optional `refresh_token(config, old_token)` (default delegates to `get_token/1`). The
library only needs "give me a valid bearer token"; token lifecycle/caching is the adapter's
concern, accommodating service accounts, ADC, workload identity, static tokens, and custom
OAuth. The library calls `refresh_token/2` on a 401 before failing. Required scope:
`https://www.googleapis.com/auth/bigquery`.

### Repo as behaviour + `__using__` macro

`Raggio.BigQuery.Repo` resolves config from `otp_app` application env (`project_id`,
`http_client`, `auth`, `auth_config`, optional `default_dataset`). It exposes connection
(`status/0`, `config/0`), data operations (`insert/3`, `merge/3`, `query/1`, `query/2`), and
schema operations (`get_table_schema/1`, `diff_schema/1`, `apply_ddl/1`). The Repo is
stateless; adapters are invoked per request.

### BigQuery REST API v2 wrapper

`Raggio.BigQuery.API` centralizes endpoint construction against
`https://bigquery.googleapis.com/bigquery/v2`: `tables.insertAll` (streaming insert),
`jobs.query`/`queries` (query + results), `tables.get` (remote schema), and `jobs` for DDL.
It refactors the old `BigQueryKit.Adapter`, replacing HTTPoison calls with the HTTPClient
behaviour and parsing BigQuery's error response shape (`code`, `errors[].reason`, `message`).

### Migration tracking table

Applied migrations are recorded in `{dataset}._raggio_migrations`
(`version STRING NOT NULL`, `name STRING NOT NULL`, `applied_at TIMESTAMP NOT NULL`,
`checksum STRING` = SHA256 of `up.sql`). The table is auto-created on the first
migrate/status call. Writes use MERGE for idempotency under concurrent migrations; rollback
deletes the row. Migrations are applied in timestamp order and rolled back in reverse.

### File-based up/down migrations

Migrations are timestamped directories
`priv/raggio/bigquery/{dataset}/{version}_{name}/` containing explicit `up.sql` and
`down.sql`. Explicit reversibility (no magic reverse detection) matches the old kit and Ecto
conventions; each migration is a self-contained, atomic-per-file unit.

### Differ and rename detection

`Raggio.BigQuery.Differ` fetches the remote schema via `tables.get`, normalizes both local
(`Raggio.Schema.Type`) and remote schemas to `{name, type, mode}` tuples, and emits
`Change` structs (`:add | :remove | :modify | :rename`) collected into a `Diff`
(`has_destructive`, `has_renames`). Potential renames are detected for removed+added pairs of
the same type with Jaro-Winkler name similarity > 0.8 and confirmed interactively in the CLI.
Unsupported changes (DROP COLUMN, narrowing type changes) fail with a descriptive error
explaining the BigQuery limitation and the export→recreate→reload workaround.

### Telemetry events

`Raggio.BigQuery.Telemetry.span/3` wraps operations with `:telemetry.span/3` under the
`[:raggio, :bigquery, ...]` prefix: `:request`, `:insert`, `:merge`, `:query`, `:migration`
(each with `:start | :stop | :exception`) plus a `[:raggio, :bigquery, :retry]` event.
Metadata carries operation type, duration, row count where applicable, and error reason on
failure. Zero overhead when no handlers are attached; integrates with telemetry_metrics.

### Retry strategy

`Raggio.BigQuery.Retry` auto-retries on HTTP 429 (`rateLimitExceeded`) with exponential
backoff plus jitter: `delay = min(base_delay * 2^attempt + jitter, max_delay)`. Configurable
`max_retries` (3), `base_delay_ms` (1000), `max_delay_ms` (30000). Each attempt emits the
retry telemetry event. Long-term `quotaExceeded` (403) is surfaced rather than retried tightly.

## Risks / Trade-offs

- **Adapter burden on consumers**: Agnosticism requires every consumer to implement (or pull
  in) HTTP and Auth adapters. Mitigated by documented example adapters (Req/Finch/HTTPoison,
  Goth/static/workload-identity) and planned optional default packages.
- **BigQuery schema-change limitations**: BigQuery cannot DROP COLUMN or narrow types. We
  deliberately fail with guidance rather than attempt risky table rewrites; users must do
  export→recreate→reload manually.
- **Rename detection false positives**: Similarity heuristics can mis-pair fields; mitigated
  by interactive confirmation and the `--force` flag being opt-in for destructive changes.
- **Streaming insert constraints**: BigQuery limits (10,000 rows / 10MB per request) require
  auto-batching; very large loads still depend on the consumer's HTTP adapter performance.
- **Eventual consistency of streaming inserts**: Rows inserted via the streaming API may not
  be immediately queryable, which can surprise tests that insert-then-query without delay.
- **Token caching is delegated**: Since the library only asks for tokens, a poorly written
  Auth adapter could fetch a token per request; documented as the adapter's responsibility.
