# BigQuery Specification

## Purpose

`Raggio.BigQuery` provides a dependency-light BigQuery integration built on pluggable HTTP and Auth behaviours, with a configurable Repo, schema-driven table definitions and DDL export, schema diffing with rename detection, and a full migration toolchain. It also covers data insert/merge/query operations, telemetry instrumentation, and rate-limit retry, all within a single-package submodule namespace driven by `Raggio.Schema`.

## Requirements

### Requirement: HTTP Client Abstraction

The library SHALL define a `Raggio.BigQuery.HTTPClient` behaviour for HTTP transport and
MUST NOT depend on any specific HTTP client library (Req, Finch, HTTPoison, Mint). The
behaviour MUST declare `request(method, url, headers, body, opts)` returning
`{:ok, %{status, headers, body}}` or `{:error, reason}`. The library MUST always include
`Authorization: Bearer <token>` and, for POST/PUT/PATCH, `Content-Type: application/json`
on requests it makes through the adapter. Default HTTP adapter implementations MAY be
provided as separate optional packages.

#### Scenario: Custom HTTP adapter is invoked for API calls

- **WHEN** a Repo is configured with a module implementing the `HTTPClient` behaviour
- **THEN** every BigQuery API call is dispatched through that module's `request/5`
- **AND** the request carries the bearer token from the Auth adapter and the JSON content type

#### Scenario: HTTP error propagates

- **WHEN** the HTTP adapter returns `{:error, reason}` (for example `:timeout` or `:econnrefused`)
- **THEN** the operation returns `{:error, reason}` wrapped in a `Raggio.BigQuery.Error`

#### Scenario: No HTTP client dependency

- **WHEN** the library is compiled
- **THEN** it has zero dependencies on Req, Finch, HTTPoison, or Mint

### Requirement: Auth Abstraction and Token Acquisition

The library SHALL define a `Raggio.BigQuery.Auth` behaviour for authentication and MUST NOT
depend on Goth or any specific auth library. The behaviour MUST declare
`get_token(config) :: {:ok, token} | {:error, reason}` and an optional
`refresh_token(config, old_token)`. The library SHALL request a bearer token before making
API calls and MUST invoke `refresh_token/2` when it detects a 401 response before failing.
The required OAuth2 scope is `https://www.googleapis.com/auth/bigquery`.

#### Scenario: Token acquired before request

- **WHEN** the Repo performs any BigQuery operation
- **THEN** it calls the Auth adapter's `get_token/1` with the configured `auth_config`
- **AND** uses the returned token as the bearer credential

#### Scenario: Token refreshed on 401

- **WHEN** a request returns HTTP 401 and the Auth adapter implements `refresh_token/2`
- **THEN** the library calls `refresh_token/2` with the old token and retries with the new token

#### Scenario: Auth failure surfaces

- **WHEN** `get_token/1` returns `{:error, reason}`
- **THEN** the operation fails with `{:error, %Raggio.BigQuery.Error{type: :auth_error}}`

#### Scenario: No auth library dependency

- **WHEN** the library is compiled
- **THEN** it has zero dependencies on Goth or other specific auth libraries

### Requirement: Repo Connection and Configuration

The library SHALL provide `Raggio.BigQuery.Repo` as a behaviour plus a `__using__` macro
that resolves configuration from the `otp_app` application environment (`project_id`,
`http_client`, `auth`, `auth_config`, optional `default_dataset`). The Repo MUST provide
`config/0` returning the resolved configuration and `status/0` verifying connectivity through
the adapter chain.

#### Scenario: Status returns connected

- **WHEN** a Repo with valid HTTP and Auth adapters calls `status/0`
- **THEN** it makes an API call through the adapter chain and returns `:connected`

#### Scenario: Status returns error when adapters fail

- **WHEN** `status/0` is called and the auth or HTTP adapter returns an error
- **THEN** it returns `{:error, %Raggio.BigQuery.Error{}}`

#### Scenario: Config resolution

- **WHEN** `config/0` is called on a Repo using `otp_app: :my_app`
- **THEN** it returns the merged configuration map including `project_id`, `http_client`, `auth`, and `auth_config`

### Requirement: Table Definition and DDL Export

The library SHALL provide a `Raggio.BigQuery.Table` behaviour requiring `__dataset__/0`,
`__table__/0`, and `__schema__/0` (returning a `Raggio.Schema.Type.t()`), with optional
`__time_partitioning__/0` and `__clustering__/0`. The `__using__` macro MUST inject default
implementations for the optional callbacks and a `__qualified_name__/0` returning
`"dataset.table"`. The Table MUST provide `to_create_table_ddl/0` and `to_bigquery_schema/0`,
both delegating type mapping to `Raggio.Schema.Adapters.BigQuery`. Nested struct types MUST
map to STRUCT/RECORD and lists to ARRAY/REPEATED.

#### Scenario: Qualified name and DDL generation

- **WHEN** a module uses `Raggio.BigQuery.Table` and defines dataset `"billing"`, table `"items"`, and a schema
- **THEN** `__qualified_name__/0` returns `"billing.items"`
- **AND** `to_create_table_ddl/0` returns valid BigQuery `CREATE TABLE` DDL for the schema

#### Scenario: Partitioning and clustering metadata

- **WHEN** a Table defines `__time_partitioning__/0` and `__clustering__/0`
- **THEN** the generated DDL reflects the partitioning field/granularity and clustering columns

#### Scenario: Nested structs and arrays

- **WHEN** a schema contains a nested `struct([...])` field and a `list(string())` field
- **THEN** the nested struct maps to a `STRUCT<...>` column and the list maps to an `ARRAY<...>` column

#### Scenario: Unsupported type

- **WHEN** the schema contains a type with no BigQuery mapping
- **THEN** DDL generation returns `{:error, {:unsupported_type, type}}`

### Requirement: Schema Diffing and Rename Detection

The library SHALL provide `Raggio.BigQuery.Differ` to compare a local `Raggio.Schema`
definition against the remote BigQuery table schema. The Differ MUST detect added fields,
removed fields, type changes, and nullable changes, emitting `Raggio.BigQuery.Change` structs
collected into a `Raggio.BigQuery.Diff` (with `has_destructive` and `has_renames` flags). The
Differ MUST detect potential renames for removed+added pairs of the same type using name
similarity heuristics (Jaro-Winkler > 0.8). The Differ MUST fail with a descriptive error for
unsupported changes (DROP COLUMN, narrowing type changes), explaining the BigQuery limitation
and the export→recreate→reload workaround.

#### Scenario: Added field detected

- **WHEN** the local schema has a field absent from the remote table
- **THEN** the diff includes a `%Change{type: :add}` for that field

#### Scenario: Potential rename detected

- **WHEN** a removed field and an added field share the same type and have name similarity above 0.8
- **THEN** the diff flags `has_renames: true` and includes a `%Change{type: :rename}` with the old field name

#### Scenario: Unsupported drop column

- **WHEN** the diff would require dropping a column
- **THEN** it returns `{:error, {:unsupported_change, :drop_column, message}}` describing the export→recreate→reload workaround

#### Scenario: Unsupported narrowing type change

- **WHEN** the diff would narrow a column type
- **THEN** it returns `{:error, {:unsupported_change, :narrowing_type, message}}` explaining BigQuery only supports widening conversions

### Requirement: Migration Generation and Files

The library SHALL store migrations as timestamped directories
`priv/raggio/bigquery/{dataset}/{version}_{name}/` containing `up.sql` and `down.sql`. The
`mix raggio.bigquery.generate "<name>"` task MUST diff the schema and write a migration whose
`up.sql` contains valid BigQuery DDL and whose `down.sql` contains the inverse operation,
batching multiple changes into a single migration.

#### Scenario: Generate creates timestamped migration

- **WHEN** `mix raggio.bigquery.generate "add_status_field"` runs after a schema change
- **THEN** a directory `priv/raggio/bigquery/{dataset}/{version}_add_status_field/` is created with `up.sql` and `down.sql`

#### Scenario: Up and down contain inverse DDL

- **WHEN** a migration adds a column in `up.sql`
- **THEN** `down.sql` contains the inverse operation (dropping that column)

#### Scenario: Multiple changes batched

- **WHEN** several schema changes exist at generation time
- **THEN** all changes are written into a single migration

### Requirement: Migration Apply, Rollback, and Status

The library SHALL provide `mix raggio.bigquery.migrate`, `mix raggio.bigquery.rollback`, and
`mix raggio.bigquery.status`. Pending migrations MUST be applied in timestamp order; rollback
MUST execute `down.sql` in reverse order and support `--step N`. On a migration failure,
subsequent migrations MUST NOT be applied and the error MUST be reported.

#### Scenario: Apply pending migrations in order

- **WHEN** `mix raggio.bigquery.migrate` runs with pending migrations
- **THEN** all pending migrations are applied in ascending timestamp order

#### Scenario: Rollback by step

- **WHEN** `mix raggio.bigquery.rollback --step 2` runs
- **THEN** the last 2 applied migrations are rolled back in reverse order using their `down.sql`

#### Scenario: Failure halts remaining migrations

- **WHEN** a migration fails during `migrate`
- **THEN** later migrations are not applied and the error is reported

#### Scenario: Status lists applied and pending

- **WHEN** `mix raggio.bigquery.status` runs
- **THEN** it reports which migrations are applied and which are pending

### Requirement: Applied-Migration Tracking

The library SHALL track applied migrations in a `{dataset}._raggio_migrations` table with
columns `version` (STRING, NOT NULL), `name` (STRING, NOT NULL), `applied_at` (TIMESTAMP, NOT
NULL), and `checksum` (STRING, SHA256 of `up.sql`). The table MUST be auto-created on the
first migrate or status call. Records MUST be written via MERGE for idempotency and removed on
rollback.

#### Scenario: Tracking table auto-created

- **WHEN** migrate or status runs and `{dataset}._raggio_migrations` does not exist
- **THEN** the library creates the tracking table before proceeding

#### Scenario: Applied migration recorded

- **WHEN** a migration is applied successfully
- **THEN** a row with its version, name, applied_at, and checksum is upserted via MERGE into `_raggio_migrations`

#### Scenario: Rollback removes record

- **WHEN** a migration is rolled back
- **THEN** its tracking row is deleted from `_raggio_migrations`

### Requirement: Push Schema Sync

The library SHALL provide `mix raggio.bigquery.push` to diff the local schema against the
remote table and apply changes directly. The task MUST prompt interactively to confirm
detected renames, MUST abort destructive changes unless `--force` is given, and MUST report
when the schema is already up to date.

#### Scenario: New field added by push

- **WHEN** `mix raggio.bigquery.push` runs with a schema containing a new field
- **THEN** the field is added to the BigQuery table

#### Scenario: Rename confirmation prompt

- **WHEN** push detects a potential rename interactively
- **THEN** it prompts "Was `old_name` renamed to `new_name`?" with `[Y/n]`

#### Scenario: Destructive change requires force

- **WHEN** push detects a destructive change and `--force` is not provided
- **THEN** it aborts and requires the `--force` flag

#### Scenario: No changes

- **WHEN** push runs and the schema matches the remote table
- **THEN** it outputs "Schema is up to date"

### Requirement: Data Insert and Merge

The Repo SHALL provide `insert/2`/`insert/3` (streaming insert) and `merge/3` (upsert). Insert
MUST auto-batch rows to stay under BigQuery streaming limits. Merge MUST require a `:key`
option (single or multiple columns) to match update vs insert. Both MUST return
`{:ok, count}` or `{:error, term}`.

#### Scenario: Insert rows

- **WHEN** `Repo.insert(MyTable, rows)` is called with a list of maps matching the schema
- **THEN** the rows are inserted via the streaming insert API and `{:ok, count}` is returned

#### Scenario: Auto-batching large inserts

- **WHEN** the number/size of rows exceeds BigQuery's per-request streaming limit
- **THEN** the rows are automatically split into batches under the limit

#### Scenario: Merge upserts by key

- **WHEN** `Repo.merge(MyTable, rows, key: :tracking)` is called
- **THEN** rows matching an existing key are updated and unmatched rows are inserted

### Requirement: Data Query

The Repo SHALL provide `query/1` and `query/2`. `query/1` MUST return results as a list of
maps. `query/2` MUST safely interpolate named parameters into the SQL.

#### Scenario: Run a query

- **WHEN** `Repo.query("SELECT * FROM billing.items LIMIT 10")` is called
- **THEN** it returns `{:ok, [%{...}, ...]}` with results as a list of maps

#### Scenario: Parameterized query

- **WHEN** `Repo.query(sql, %{status: "active"})` is called with a `@status` placeholder
- **THEN** the parameter is safely interpolated and matching rows are returned

### Requirement: Telemetry Instrumentation

The library SHALL emit `:telemetry` events under the `[:raggio, :bigquery, ...]` prefix for
HTTP requests (`:request`), data operations (`:insert`, `:merge`, `:query`), and migrations
(`:migration`), each with `:start | :stop | :exception` suffixes, plus a
`[:raggio, :bigquery, :retry]` event. Event metadata MUST include operation type, duration,
row count where applicable, and error reason on failure.

#### Scenario: Request span emitted

- **WHEN** any BigQuery API request runs
- **THEN** `[:raggio, :bigquery, :request, :start]` and `[:raggio, :bigquery, :request, :stop]` are emitted with timing metadata

#### Scenario: Exception event on failure

- **WHEN** an instrumented operation raises
- **THEN** the corresponding `:exception` event is emitted with `kind` and `reason` metadata

#### Scenario: Zero overhead without handlers

- **WHEN** no telemetry handlers are attached
- **THEN** event emission imposes no runtime penalty on operations

### Requirement: Rate-Limit Retry

The library SHALL auto-retry on HTTP 429 (`rateLimitExceeded`) using exponential backoff with
jitter. Retry behavior MUST be configurable: `max_retries` (default 3), `base_delay_ms`
(default 1000), `max_delay_ms` (default 30000). A telemetry event MUST be emitted on each
retry attempt.

#### Scenario: Retry on 429

- **WHEN** a request returns HTTP 429 with reason `rateLimitExceeded`
- **THEN** the library waits `min(base_delay * 2^attempt + jitter, max_delay)` and retries up to `max_retries` times

#### Scenario: Retry telemetry

- **WHEN** a retry is attempted
- **THEN** a `[:raggio, :bigquery, :retry]` event is emitted with `attempt`, `delay_ms`, and `reason` metadata

#### Scenario: Exhausted retries surface error

- **WHEN** all retries are exhausted on a persistent 429
- **THEN** the operation returns `{:error, %Raggio.BigQuery.Error{}}`

### Requirement: Single-Package Architecture and Schema Integration

The library SHALL live under the `Raggio.BigQuery` submodule namespace within the single
Raggio package (not an umbrella app). Table schemas MUST be defined using `Raggio.Schema` type
constructors, and DDL generation MUST use `Raggio.Schema.Adapters.BigQuery` for type mapping.
The only added runtime dependency is `{:telemetry, "~> 1.0"}`.

#### Scenario: Submodule namespace

- **WHEN** the library is loaded
- **THEN** all BigQuery modules live under `Raggio.BigQuery.*` within the single package

#### Scenario: Schema-driven DDL

- **WHEN** a Table's schema is exported to DDL
- **THEN** type mapping is performed by `Raggio.Schema.Adapters.BigQuery`
