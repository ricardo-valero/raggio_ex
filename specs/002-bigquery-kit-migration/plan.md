# Implementation Plan: BigQuery Kit Migration

**Branch**: `002-bigquery-kit-migration` | **Date**: 2026-01-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-bigquery-kit-migration/spec.md`

## Summary

Migrate the existing BigQuery Kit implementation from `old/bigquery_kit/` to `Raggio.BigQuery` submodule, making it HTTP client agnostic and auth agnostic through behaviour-based adapter patterns. The migration leverages existing `Raggio.Schema` and `Raggio.Schema.Adapters.BigQuery` for schema definitions and DDL generation, while abstracting HTTP transport and authentication to user-provided implementations.

## Technical Context

**Language/Version**: Elixir 1.14+ (per existing mix.exs)  
**Primary Dependencies**: Decimal ~> 2.0, Jason ~> 1.4, Telemetry ~> 1.0 (to add)  
**Storage**: BigQuery (external service via adapters) - no local storage  
**Testing**: ExUnit with mock adapters (no real BigQuery calls in unit tests)  
**Target Platform**: Elixir library (cross-platform, BEAM VM)  
**Project Type**: Single package with submodules (like Ecto)  
**Performance Goals**: N/A for library - performance determined by user's HTTP/Auth adapters  
**Constraints**: Zero dependencies on specific HTTP clients or auth libraries  
**Scale/Scope**: Migration of ~26 existing modules, 7 new behaviours/modules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Note**: Project constitution is not yet customized (template only). No specific gates defined.

General principles followed:
- [x] Single package architecture (not umbrella) - per 001-monorepo-restructure
- [x] Behaviour-based abstractions for pluggability
- [x] No external service dependencies in core library
- [x] Comprehensive test coverage with mocks

## Project Structure

### Documentation (this feature)

```text
specs/002-bigquery-kit-migration/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (behaviour definitions)
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/
├── raggio.ex                           # Existing - add BigQuery alias
├── raggio/
│   ├── schema.ex                       # Existing
│   ├── schema/
│   │   ├── adapters/
│   │   │   └── bigquery.ex             # Existing - DDL generation
│   │   └── ...
│   ├── syntax.ex                       # Existing
│   ├── syntax/...                      # Existing
│   └── bigquery/                       # NEW - migrated from old/bigquery_kit/
│       ├── bigquery.ex                 # Main module, convenience functions
│       ├── repo.ex                     # Repo behaviour and __using__ macro
│       ├── table.ex                    # Table behaviour for schema metadata
│       ├── http_client.ex              # HTTPClient behaviour (NEW)
│       ├── auth.ex                     # Auth behaviour (NEW)
│       ├── differ.ex                   # Schema diffing (migrated)
│       ├── differ/
│       │   ├── change.ex               # Change struct (migrated)
│       │   └── rename_detector.ex      # Rename detection (migrated)
│       ├── ddl.ex                      # DDL generation from changes (migrated)
│       ├── migrator.ex                 # Migration coordinator (migrated)
│       ├── migrator/
│       │   ├── tracker.ex              # Migration tracking (migrated)
│       │   ├── loader.ex               # Migration file loading (migrated)
│       │   ├── generator.ex            # Migration file generation (migrated)
│       │   └── executor.ex             # Migration execution (migrated)
│       ├── api.ex                      # BigQuery REST API wrapper (NEW)
│       ├── retry.ex                    # Exponential backoff retry (NEW)
│       └── telemetry.ex                # Telemetry event emission (NEW)

lib/mix/tasks/
└── raggio/
    └── bigquery/
        ├── push.ex                     # mix raggio.bigquery.push
        ├── generate.ex                 # mix raggio.bigquery.generate
        ├── migrate.ex                  # mix raggio.bigquery.migrate
        ├── rollback.ex                 # mix raggio.bigquery.rollback
        └── status.ex                   # mix raggio.bigquery.status

test/
├── raggio/
│   └── bigquery/
│       ├── repo_test.exs
│       ├── table_test.exs
│       ├── http_client_test.exs
│       ├── auth_test.exs
│       ├── differ_test.exs
│       ├── ddl_test.exs
│       ├── migrator_test.exs
│       ├── api_test.exs
│       ├── retry_test.exs
│       └── telemetry_test.exs
└── support/
    ├── mock_http_client.ex             # Test mock for HTTPClient behaviour
    └── mock_auth.ex                    # Test mock for Auth behaviour
```

**Structure Decision**: Single package with `Raggio.BigQuery` submodule namespace. All BigQuery-related code lives under `lib/raggio/bigquery/`. Mix tasks follow Elixir convention at `lib/mix/tasks/raggio/bigquery/`.

## Key Module Responsibilities

| Module | Responsibility | Migration Source |
|--------|---------------|------------------|
| `Raggio.BigQuery` | Main entry point, convenience functions | New |
| `Raggio.BigQuery.Repo` | Connection management, data operations | `BigQueryKit.Repo` |
| `Raggio.BigQuery.Table` | Table metadata behaviour | `BigQueryKit.Schema` |
| `Raggio.BigQuery.HTTPClient` | HTTP transport behaviour | New (extracted from `BigQueryKit.Adapter`) |
| `Raggio.BigQuery.Auth` | Authentication behaviour | New (extracted from `BigQueryKit.Credentials`) |
| `Raggio.BigQuery.API` | BigQuery REST API wrapper | `BigQueryKit.Adapter` (refactored) |
| `Raggio.BigQuery.Differ` | Schema comparison | `BigQueryKit.Differ` |
| `Raggio.BigQuery.DDL` | DDL statement generation | `BigQueryKit.DDL` |
| `Raggio.BigQuery.Migrator` | Migration orchestration | `BigQueryKit.Migrator` |
| `Raggio.BigQuery.Retry` | Exponential backoff logic | New |
| `Raggio.BigQuery.Telemetry` | Event emission helpers | New |

## Complexity Tracking

No constitution violations requiring justification.

## Migration Strategy

### Phase 1: Core Behaviours (P1 Stories)
1. Define `Raggio.BigQuery.HTTPClient` behaviour
2. Define `Raggio.BigQuery.Auth` behaviour
3. Define `Raggio.BigQuery.Table` behaviour
4. Implement `Raggio.BigQuery.Repo` with adapter injection
5. Create mock adapters for testing

### Phase 2: Schema Management (P2 Stories)
1. Migrate `BigQueryKit.Differ` → `Raggio.BigQuery.Differ`
2. Migrate `BigQueryKit.DDL` → `Raggio.BigQuery.DDL`
3. Migrate `BigQueryKit.Migrator.*` → `Raggio.BigQuery.Migrator.*`
4. Implement Mix tasks with new naming

### Phase 3: Data Operations (P3 Stories)
1. Migrate insert/merge/query from `BigQueryKit.Adapter`
2. Add auto-batching logic
3. Integrate telemetry events
4. Add retry logic for 429 errors

## Dependencies to Add

```elixir
# mix.exs deps
{:telemetry, "~> 1.0"}  # For observability events
```

No other dependencies - HTTP client and auth are user-provided via behaviours.
