# Feature Specification: BigQuery Kit Migration

**Feature Branch**: `002-bigquery-kit-migration`  
**Created**: 2026-01-14  
**Status**: Draft  
**Input**: User description: "Migrate old/ code and spec into a new one using our Raggio.Schema and Raggio.Syntax modules, keeping it HTTP client agnostic and auth agnostic"

## Overview

This feature migrates the existing BigQuery Kit implementation from `old/bigquery_kit/` to integrate with the new Raggio.Schema and Raggio.Syntax modules as `Raggio.BigQuery`. The migration follows the single-package-with-submodules architecture (like Ecto) established in 001-monorepo-restructure.

**Key Design Decisions:**

1. **Single Package Submodule**: BigQuery Kit becomes `Raggio.BigQuery` as a submodule within the Raggio package, NOT a separate umbrella app (per 001-monorepo-restructure decision)
2. **HTTP Client Agnostic**: Define a `Raggio.BigQuery.HTTPClient` behaviour allowing users to plug in their preferred HTTP client (Req, Finch, HTTPoison, Mint, etc.)
3. **Auth Agnostic**: Define a `Raggio.BigQuery.Auth` behaviour allowing users to plug in their preferred auth strategy (Goth, custom OAuth, service account key, ADC, etc.)
4. **Schema Integration**: Leverage existing `Raggio.Schema` for type definitions and `Raggio.Schema.Adapters.BigQuery` for DDL export
5. **Adapter Pattern**: Users implement behaviours for HTTP and Auth; library provides optional default implementations as separate packages

## Clarifications

### Session 2026-01-14

- Q: Should this be an umbrella app? → A: No - follows 001-monorepo-restructure decision for single package with submodules (like Ecto)
- Q: How should HTTP client abstraction work? → A: Behaviour-based adapter pattern - `Raggio.BigQuery.HTTPClient` behaviour with callbacks for request/response handling
- Q: How should authentication abstraction work? → A: Behaviour-based adapter pattern - `Raggio.BigQuery.Auth` behaviour with callbacks for token acquisition
- Q: Where do default adapter implementations live? → A: Optional separate packages (e.g., `raggio_bigquery_req`, `raggio_bigquery_goth`) that users add as dependencies
- Q: Should the consumer app define schemas or the library? → A: Consumer app defines schemas using Raggio.Schema; library provides Raggio.BigQuery.Table behaviour for BigQuery-specific metadata
- Q: Should CLI commands use abbreviation `bq` or full name `bigquery`? → A: Full name `bigquery` (e.g., `mix raggio.bigquery.push`) for consistency and clarity
- Q: Should the library emit Telemetry events for observability? → A: Yes, emit `:telemetry` events for HTTP requests, migrations, inserts, and queries (standard Elixir pattern)
- Q: How should BigQuery API quota exceeded (429) errors be handled? → A: Auto-retry with exponential backoff (configurable retries); future iteration may add optional middleware for custom retry strategies
- Q: How should truly unsupported schema changes (DROP COLUMN, narrowing type changes) be handled? → A: Fail with descriptive error explaining the BigQuery limitation and suggesting manual workaround (export → recreate table)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define BigQuery Table Schema (Priority: P1)

A developer needs to define a BigQuery table schema for their data pipeline. They use Raggio.Schema to define the data structure and Raggio.BigQuery.Table behaviour to add BigQuery-specific metadata (dataset, table name, partitioning, clustering).

**Why this priority**: This is the foundation - developers must be able to define schemas before any other BigQuery operations. Without schema definitions, nothing else works.

**Independent Test**: Can be fully tested by defining a schema with Raggio.Schema, implementing the Table behaviour, and calling `__bigquery_schema__/0` to verify correct DDL generation.

**Acceptance Scenarios**:

1. **Given** a Raggio.Schema definition, **When** developer implements `Raggio.BigQuery.Table` behaviour, **Then** the module provides dataset/table metadata and BigQuery schema export
2. **Given** a table schema with partitioning/clustering options, **When** developer calls `to_create_table_ddl/0`, **Then** valid BigQuery CREATE TABLE DDL is generated
3. **Given** nested struct types in the schema, **When** exporting to BigQuery, **Then** they are converted to STRUCT/RECORD types correctly

---

### User Story 2 - Connect to BigQuery with Custom HTTP/Auth (Priority: P1)

A developer needs to connect to BigQuery using their organization's preferred HTTP client and authentication method. They implement the HTTP and Auth behaviours and configure a Repo with their adapters.

**Why this priority**: Connection is required for any BigQuery operation. Making it pluggable is the core differentiator enabling HTTP/auth agnosticism.

**Independent Test**: Can be fully tested by implementing both behaviours (even with mock adapters), configuring a Repo, and calling `status/0` to verify connectivity works through the adapter chain.

**Acceptance Scenarios**:

1. **Given** custom HTTP and Auth adapter implementations, **When** developer configures a Repo with these adapters, **Then** all BigQuery API calls use the custom implementations
2. **Given** a Repo with valid adapters, **When** `MyRepo.status/0` is called, **Then** it returns `:connected` after making an API call through the adapter chain
3. **Given** auth that requires token refresh, **When** the token expires, **Then** the Auth adapter's refresh callback is invoked automatically
4. **Given** an HTTP error from the adapter, **When** the error occurs, **Then** it propagates as `{:error, reason}` with adapter-specific details

---

### User Story 3 - Push Schema Changes (Priority: P2)

A developer wants to quickly sync local schema changes to BigQuery during development. They run `mix raggio.bigquery.push` which diffs local vs remote and applies changes.

**Why this priority**: Fast iteration during development is essential. This is the "drizzle push" equivalent for prototyping.

**Independent Test**: Can be tested by defining a schema, calling push, and verifying the BigQuery table matches (requires working HTTP/Auth adapters or mocks).

**Acceptance Scenarios**:

1. **Given** a schema with a new field, **When** `mix raggio.bigquery.push` is run, **Then** the field is added to the BigQuery table
2. **Given** a potential field rename detected, **When** push runs interactively, **Then** CLI prompts "Was `old_name` renamed to `new_name`?" with [Y/n]
3. **Given** a destructive change (column drop), **When** running without `--force`, **Then** CLI aborts requiring `--force` flag
4. **Given** no schema changes, **When** push runs, **Then** it outputs "Schema is up to date"

---

### User Story 4 - Generate Migration Files (Priority: P2)

A developer needs to version-control schema changes for production deployments. They run `mix raggio.bigquery.generate` to create timestamped migration files with up/down SQL.

**Why this priority**: Production-safe deployments require versioned migrations. This enables CI/CD and team collaboration.

**Independent Test**: Can be tested by changing a schema, running generate, and inspecting the created migration files for valid DDL.

**Acceptance Scenarios**:

1. **Given** a schema change, **When** `mix raggio.bigquery.generate "description"` runs, **Then** timestamped migration files are created in `priv/raggio/bigquery/{dataset}/`
2. **Given** a generated migration, **When** inspecting `up.sql`, **Then** it contains valid BigQuery DDL
3. **Given** a generated migration, **When** inspecting `down.sql`, **Then** it contains the inverse operation
4. **Given** multiple changes, **When** generate runs, **Then** all changes are batched into a single migration

---

### User Story 5 - Apply and Rollback Migrations (Priority: P2)

A developer needs to apply pending migrations to staging/production and rollback if issues arise.

**Why this priority**: Completes the migration workflow essential for production deployments.

**Independent Test**: Can be tested by generating a migration, applying it, verifying schema changed, then rolling back and verifying revert.

**Acceptance Scenarios**:

1. **Given** pending migrations, **When** `mix raggio.bigquery.migrate` runs, **Then** all pending migrations are applied in timestamp order
2. **Given** a migration is applied, **When** it completes, **Then** a record is inserted into `{dataset}._raggio_migrations` tracking table
3. **Given** `mix raggio.bigquery.rollback --step 2`, **When** run, **Then** the last 2 migrations are rolled back in reverse order
4. **Given** a migration failure, **When** it occurs, **Then** subsequent migrations are not applied and error is reported

---

### User Story 6 - Insert and Merge Data (Priority: P3)

A developer needs to load data into BigQuery tables. They use Repo functions to insert (streaming) or merge (upsert) rows.

**Why this priority**: Data operations are secondary to schema management but complete the library's utility.

**Independent Test**: Can be tested by inserting rows and querying to verify they exist.

**Acceptance Scenarios**:

1. **Given** a list of maps matching schema, **When** `MyRepo.insert(MyTable, rows)` is called, **Then** rows are inserted via streaming insert API
2. **Given** more than 5000 rows, **When** inserting, **Then** rows are auto-batched to stay under BigQuery limits
3. **Given** rows with a key field, **When** `MyRepo.merge(MyTable, rows, key: :tracking)` is called, **Then** existing rows are updated, new rows are inserted

---

### User Story 7 - Query Data (Priority: P3)

A developer needs to read data from BigQuery for their application.

**Why this priority**: Read operations complete the data API.

**Independent Test**: Can be tested by inserting data and querying to retrieve it.

**Acceptance Scenarios**:

1. **Given** a SQL query, **When** `MyRepo.query("SELECT * FROM ...")` is called, **Then** results are returned as list of maps
2. **Given** parameterized query, **When** `MyRepo.query(sql, params)` is called, **Then** parameters are safely interpolated

---

### Edge Cases

- What happens when HTTP client returns timeout? → Error propagates as `{:error, :timeout}` from HTTPClient adapter
- What happens when auth token refresh fails? → Auth adapter returns `{:error, reason}`, operation fails with auth error
- What happens when DDL contains unsupported types? → `to_create_table_ddl/0` returns `{:error, {:unsupported_type, type}}`
- What happens when migration tracking table doesn't exist? → Auto-created on first migrate/status call
- What happens during concurrent migrations? → Tracking table uses MERGE for idempotent writes
- What happens when schema diff detects DROP COLUMN? → Fails with `{:error, {:unsupported_change, :drop_column, "BigQuery does not support DROP COLUMN. Workaround: export data, recreate table with new schema, reload data."}}`
- What happens when schema diff detects narrowing type change? → Fails with `{:error, {:unsupported_change, :narrowing_type, "BigQuery only supports widening type conversions. Workaround: export data, recreate table, reload data."}}`

## Requirements *(mandatory)*

### Functional Requirements

**HTTP Client Abstraction:**
- **FR-001**: Library MUST define `Raggio.BigQuery.HTTPClient` behaviour with callbacks for request execution
- **FR-002**: HTTPClient behaviour MUST support `request(method, url, headers, body, opts)` returning `{:ok, response}` or `{:error, reason}`
- **FR-003**: Library MUST NOT depend on any specific HTTP client library (Req, Finch, HTTPoison, etc.)
- **FR-004**: Default HTTP adapter implementations MAY be provided as separate optional packages

**Auth Abstraction:**
- **FR-005**: Library MUST define `Raggio.BigQuery.Auth` behaviour with callbacks for token acquisition
- **FR-006**: Auth behaviour MUST support `get_token(config)` returning `{:ok, token}` or `{:error, reason}`
- **FR-007**: Auth behaviour MUST support `refresh_token(config, old_token)` for token refresh flows
- **FR-008**: Library MUST NOT depend on Goth or any specific auth library
- **FR-009**: Default auth adapter implementations MAY be provided as separate optional packages

**Repo Pattern:**
- **FR-010**: Library MUST provide `Raggio.BigQuery.Repo` behaviour for connection management
- **FR-011**: Repo MUST accept HTTP and Auth adapter modules via configuration
- **FR-012**: Repo MUST provide `status/0` to verify connectivity through adapter chain
- **FR-013**: Repo MUST provide `insert/2`, `merge/3`, `query/1`, `query/2` for data operations

**Table Definition:**
- **FR-014**: Library MUST provide `Raggio.BigQuery.Table` behaviour for BigQuery table metadata
- **FR-015**: Table behaviour MUST require `__dataset__/0` and `__table__/0` callbacks
- **FR-016**: Table behaviour MUST require `__schema__/0` returning a `Raggio.Schema.Type.t()`
- **FR-017**: Table behaviour MUST provide `to_create_table_ddl/0` generating BigQuery CREATE TABLE DDL
- **FR-018**: Table behaviour SHOULD support `time_partitioning/0` and `clustering/0` optional callbacks

**Schema Diffing:**
- **FR-019**: Library MUST provide `Raggio.BigQuery.Differ` to compare local schema to remote table
- **FR-020**: Differ MUST detect: added fields, removed fields, type changes, nullable changes
- **FR-021**: Differ MUST detect potential renames using similarity heuristics
- **FR-022**: Differ MUST generate appropriate DDL for each supported change type
- **FR-044**: Differ MUST fail with descriptive error for unsupported changes (DROP COLUMN, narrowing type changes) explaining BigQuery limitation and manual workaround (export → recreate table)

**Migration Management:**
- **FR-023**: Migrations MUST be stored as timestamped directories with `up.sql` and `down.sql` files
- **FR-024**: Library MUST track applied migrations in `{dataset}._raggio_migrations` table
- **FR-025**: Library MUST apply migrations in timestamp order
- **FR-026**: Library MUST support rollback by executing `down.sql` in reverse order

**CLI Commands:**
- **FR-027**: Library MUST provide `mix raggio.bigquery.push` for direct schema sync
- **FR-028**: Library MUST provide `mix raggio.bigquery.generate` for migration generation
- **FR-029**: Library MUST provide `mix raggio.bigquery.migrate` for applying migrations
- **FR-030**: Library MUST provide `mix raggio.bigquery.rollback` for reverting migrations
- **FR-031**: Library MUST provide `mix raggio.bigquery.status` for viewing migration status
- **FR-032**: CLI MUST support interactive prompts for renames and destructive changes
- **FR-033**: CLI MUST support `--force` flag to skip confirmations

**Integration with Raggio:**
- **FR-034**: Table schemas MUST be defined using `Raggio.Schema` type constructors
- **FR-035**: DDL generation MUST use `Raggio.Schema.Adapters.BigQuery` for type mapping
- **FR-036**: Library MUST follow single-package-submodule architecture (not umbrella)

**Observability (Telemetry):**
- **FR-037**: Library MUST emit `:telemetry` events for all HTTP requests (`[:raggio, :bigquery, :request, :start | :stop | :exception]`)
- **FR-038**: Library MUST emit `:telemetry` events for migrations (`[:raggio, :bigquery, :migration, :start | :stop | :exception]`)
- **FR-039**: Library MUST emit `:telemetry` events for data operations (`[:raggio, :bigquery, :insert | :merge | :query, :start | :stop | :exception]`)
- **FR-040**: Telemetry events MUST include metadata: operation type, duration, row count (where applicable), error reason (on failure)

**Rate Limiting & Retry:**
- **FR-041**: Library MUST auto-retry on quota exceeded (HTTP 429) errors with exponential backoff
- **FR-042**: Retry behavior MUST be configurable: max retries (default: 3), base delay (default: 1s), max delay (default: 30s)
- **FR-043**: Library MUST emit telemetry event on each retry attempt (`[:raggio, :bigquery, :retry]`)

### Key Entities

- **Raggio.BigQuery.Repo**: Connection manager holding HTTP/Auth adapters; provides data operations (insert, merge, query)
- **Raggio.BigQuery.Table**: Behaviour for table definitions; combines Raggio.Schema with BigQuery metadata (dataset, table, partitioning)
- **Raggio.BigQuery.HTTPClient**: Behaviour for HTTP transport abstraction; users implement for their preferred client
- **Raggio.BigQuery.Auth**: Behaviour for authentication abstraction; users implement for their auth strategy
- **Raggio.BigQuery.Differ**: Component comparing local Raggio.Schema to remote BigQuery table schema
- **Raggio.BigQuery.DDL**: Component generating BigQuery DDL statements from schema and diff results
- **Raggio.BigQuery.Migrator**: Component managing migration file operations and execution
- **Migration**: Timestamped directory pair (up.sql, down.sql) representing a schema change

### Security & Data Integrity

- **Authentication**: Delegated entirely to Auth behaviour implementation; library is auth-agnostic
- **Authorization**: Consumer app responsible for ensuring adapters have appropriate BigQuery permissions
- **Credentials**: Never stored by library; passed through config to Auth adapter
- **Data Validation**: Schemas validate data before insert via Raggio.Schema
- **Migration Tracking**: `_raggio_migrations` table records all schema changes with timestamps
- **Transaction Integrity**: Migrations are atomic per-file; failure prevents partial apply

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can define a BigQuery table schema using Raggio.Schema in under 5 minutes
- **SC-002**: Library compiles with zero dependencies on specific HTTP clients (Req, Finch, HTTPoison, etc.)
- **SC-003**: Library compiles with zero dependencies on Goth or specific auth libraries
- **SC-004**: Mock HTTP/Auth adapters can be implemented and used in tests within 30 minutes
- **SC-005**: Migration generation produces valid BigQuery DDL for all supported Raggio.Schema types
- **SC-006**: All Mix tasks function correctly when configured with valid HTTP/Auth adapters
- **SC-007**: 95%+ test coverage using mock adapters (no real BigQuery calls in unit tests)
- **SC-008**: Old BigQuery Kit test coverage is maintained or improved in migrated code

## Assumptions & Constraints

### Assumptions

- Raggio.Schema and Raggio.Syntax from 001-monorepo-restructure are stable and complete
- Raggio.Schema.Adapters.BigQuery provides correct type mapping for DDL generation
- Users are comfortable implementing simple behaviours for HTTP/Auth
- Real BigQuery testing will be done via integration tests with real adapters, not unit tests

### Constraints

- Must NOT add dependencies on HTTP clients (Req, Finch, HTTPoison, etc.)
- Must NOT add dependencies on auth libraries (Goth, etc.)
- Must follow single-package-submodule architecture (not umbrella)
- Must maintain Elixir 1.14+ compatibility
- Must preserve functional parity with old/bigquery_kit for migrated features

## Out of Scope

- Default HTTP adapter implementations (separate package: `raggio_bigquery_req`)
- Default Auth adapter implementations (separate package: `raggio_bigquery_goth`)
- BigQuery-specific testing infrastructure (mocks for unit tests only)
- Publishing to Hex.pm
- Tabular data parsing features (those go to Raggio.Tabular per 001-monorepo-restructure)

## Future Considerations

- **Configurable retry middleware**: Allow users to plug in custom retry strategies beyond the built-in exponential backoff (e.g., circuit breaker patterns, custom backoff algorithms)
