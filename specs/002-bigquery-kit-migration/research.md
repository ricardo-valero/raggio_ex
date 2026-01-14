# Research: BigQuery Kit Migration

**Feature**: 002-bigquery-kit-migration  
**Date**: 2026-01-14

## Research Tasks

### 1. HTTP Client Abstraction Pattern in Elixir

**Question**: What is the idiomatic way to make an Elixir library HTTP-client agnostic?

**Decision**: Behaviour-based adapter pattern

**Rationale**:
- Elixir behaviours provide compile-time callback verification
- Pattern used successfully by Tesla (middleware adapters), Ecto (database adapters)
- Users implement a simple behaviour and configure it at startup
- No runtime penalty compared to direct calls

**Alternatives Considered**:
- **Protocol-based**: Rejected - protocols are for polymorphism over data types, not pluggable services
- **MFA tuples**: Rejected - no compile-time verification, error-prone
- **Optional dependencies**: Rejected - still creates transitive dependency; doesn't solve agnosticism

**Implementation Pattern**:
```elixir
defmodule Raggio.BigQuery.HTTPClient do
  @callback request(method, url, headers, body, opts) :: {:ok, response} | {:error, reason}
end

# User implements:
defmodule MyApp.ReqHTTPClient do
  @behaviour Raggio.BigQuery.HTTPClient
  def request(method, url, headers, body, opts), do: ...
end
```

---

### 2. Auth Abstraction Pattern

**Question**: How to abstract authentication without depending on Goth or specific OAuth libraries?

**Decision**: Behaviour with `get_token/1` and `refresh_token/2` callbacks

**Rationale**:
- Authentication strategies vary (service account, ADC, workload identity, user OAuth)
- Token lifecycle (fetch, cache, refresh) is implementation-specific
- Library only needs: "give me a valid bearer token"
- Refresh callback enables proactive token renewal

**Alternatives Considered**:
- **Pass token directly to each operation**: Rejected - burdens user with token management
- **Config callback function**: Rejected - loses compile-time verification
- **GenServer with token cache**: Rejected - implementation detail; varies by auth strategy

**Implementation Pattern**:
```elixir
defmodule Raggio.BigQuery.Auth do
  @callback get_token(config :: map()) :: {:ok, token :: String.t()} | {:error, reason}
  @callback refresh_token(config :: map(), old_token :: String.t()) :: {:ok, token :: String.t()} | {:error, reason}
end
```

---

### 3. BigQuery REST API Endpoints

**Question**: Which BigQuery API endpoints are needed for schema management and data operations?

**Decision**: Target specific REST API v2 endpoints

**Base URL**: `https://bigquery.googleapis.com/bigquery/v2`

**Endpoints**:
| Operation | Method | Endpoint | Success | Common Errors |
|-----------|--------|----------|---------|---------------|
| InsertAll | POST | `/projects/{p}/datasets/{d}/tables/{t}/insertAll` | 200 + insertErrors | 400 invalid, 403 quota, 429 rate |
| Query | POST | `/projects/{p}/queries` | 200 + results | 400 invalid SQL, 403 access |
| Query (async) | POST | `/projects/{p}/jobs` | 200 + jobReference | 400 bad config, 403 quota |
| Get Results | GET | `/projects/{p}/queries/{jobId}` | 200 + rows/pageToken | 404 not found, 403 access |
| Get Table | GET | `/projects/{p}/datasets/{d}/tables/{t}` | 200 + schema | 404 not found, 403 access |
| DDL | POST | `/projects/{p}/jobs` | 200 + jobReference | 400 invalid DDL, 403 access |

**Authentication**: `Authorization: Bearer <ACCESS_TOKEN>` header with OAuth2 scope `https://www.googleapis.com/auth/bigquery`

**Streaming Insert Request**:
```json
{
  "skipInvalidRows": false,
  "ignoreUnknownValues": false,
  "rows": [{"insertId": "id-1", "json": {"field1": "value1"}}]
}
```

**Error Response Format**:
```json
{
  "code": 429,
  "errors": [{"domain": "global", "reason": "rateLimitExceeded", "message": "..."}],
  "message": "Quota exceeded"
}
```

**Key Limits**:
- Streaming insert: 10,000 rows/request, 10MB/request, 10,000 rows/second/table
- Query timeout: configurable via `timeoutMs`

---

### 4. Schema Diffing Algorithm

**Question**: How to compare local Raggio.Schema to remote BigQuery schema?

**Decision**: Field-by-field comparison with rename detection heuristics

**Rationale**:
- BigQuery's `tables.get` returns schema as JSON with field definitions
- Map BigQuery types back to Raggio types for comparison
- Detect renames via Jaro-Winkler similarity on field names + type match

**Algorithm**:
1. Fetch remote schema via API
2. Normalize both schemas to comparable format (list of {name, type, mode} tuples)
3. Build diff: added (local only), removed (remote only), changed (both with differences)
4. For removed+added pairs with same type, check name similarity for potential rename
5. Return structured diff with `Change` structs

**Rename Detection**:
- Same type required
- Name similarity > 0.8 (Jaro-Winkler)
- Interactive confirmation via CLI

---

### 5. Migration File Format

**Question**: What format for migration files? Single SQL vs separate up/down?

**Decision**: Separate `up.sql` and `down.sql` files in timestamped directories

**Rationale**:
- Mirrors old BigQuery Kit format (proven in production)
- Explicit reversibility - no magic reverse detection
- Each migration is self-contained unit
- Consistent with Ecto migrations (separate up/down logic)

**Format**:
```
priv/raggio/bigquery/{dataset}/
  20260114120000_add_status_field/
    up.sql      # ALTER TABLE ... ADD COLUMN status STRING
    down.sql    # ALTER TABLE ... DROP COLUMN status
```

---

### 6. Raggio.Schema Integration Points

**Question**: How does Raggio.BigQuery integrate with existing Raggio.Schema?

**Decision**: Table behaviour requires `__schema__/0` returning `Raggio.Schema.Type.t()`

**Findings**:
- `Raggio.Schema` provides composable type constructors (`string()`, `integer()`, `struct()`, etc.)
- `Raggio.Schema.Adapters.BigQuery` already exports schemas to DDL
- `Raggio.Schema.Type` struct has `:kind`, `:fields`, `:optional`, `:nullable` etc.

**Integration Points**:
1. **Table.`__schema__/0`** → returns `Raggio.Schema.Type.t()` (struct type)
2. **DDL generation** → delegates to `Raggio.Schema.Adapters.BigQuery.to_ddl/3`
3. **Data validation** → uses `Raggio.Schema.validate/2` before insert

---

### 7. Existing Code Reuse Assessment

**Question**: Which old/bigquery_kit modules can be ported vs rewritten?

**Decision**: Port logic, rewrite interfaces to use Raggio.Schema

**Assessment**:

| Module | Action | Notes |
|--------|--------|-------|
| `BigQueryKit.Schema` | DROP | Replaced by `Raggio.BigQuery.Table` behaviour |
| `BigQueryKit.Repo` | PORT | Adapt to use HTTPClient/Auth behaviours |
| `BigQueryKit.Dataset` | DROP | Not needed; dataset is config per Table |
| `BigQueryKit.Differ` | PORT | Adapt to work with Raggio.Schema.Type |
| `BigQueryKit.DDL` | PORT | Delegate to Raggio.Schema.Adapters.BigQuery |
| `BigQueryKit.Migrator` | PORT | Minimal changes needed |
| `BigQueryKit.Migrator.*` | PORT | Generator, Loader, Executor, Tracker all reusable |
| `BigQueryKit.Exporter` | DROP | Replaced by Raggio.Schema.Adapters.BigQuery |
| `BigQueryKit.Credentials` | DROP | Replaced by Auth behaviour |
| `BigQueryKit.Adapter` | DROP | Replaced by HTTPClient behaviour |
| Mix Tasks | PORT | Rename from `bq_kit.*` to `raggio.bq.*` |

---

### 8. Telemetry Events

**Question**: What telemetry events should the library emit for observability?

**Decision**: Follow Elixir ecosystem conventions with `[:raggio, :bigquery, ...]` event prefix

**Rationale**:
- Standard observability pattern in Elixir (Ecto, Phoenix, Finch all use this)
- Zero runtime overhead when no handlers attached
- Integrates with Prometheus, DataDog, etc. via telemetry_metrics

**Events**:
```elixir
# HTTP Request span (wraps all API calls)
[:raggio, :bigquery, :request, :start]     # metadata: %{method, url, system_time}
[:raggio, :bigquery, :request, :stop]      # measurements: %{duration}, metadata: %{status}
[:raggio, :bigquery, :request, :exception] # measurements: %{duration}, metadata: %{kind, reason}

# Data operations
[:raggio, :bigquery, :insert, :start | :stop | :exception]
[:raggio, :bigquery, :merge, :start | :stop | :exception]
[:raggio, :bigquery, :query, :start | :stop | :exception]

# Migrations
[:raggio, :bigquery, :migration, :start | :stop | :exception]

# Retry attempts
[:raggio, :bigquery, :retry]  # metadata: %{attempt, delay_ms, reason}
```

**Implementation**:
```elixir
defmodule Raggio.BigQuery.Telemetry do
  def span(event, metadata, fun) do
    :telemetry.span([:raggio, :bigquery | event], metadata, fn ->
      {fun.(), %{}}
    end)
  end
end
```

---

### 9. Retry Logic for Rate Limiting

**Question**: How to handle BigQuery API rate limiting (429 errors)?

**Decision**: Exponential backoff with jitter, configurable parameters

**Rationale**:
- BigQuery has strict quotas (100 concurrent queries, streaming limits)
- Exponential backoff prevents thundering herd problem
- Jitter randomizes retry times across clients
- Configurable allows tuning for specific workloads

**Configuration**:
- `max_retries`: 3 (default)
- `base_delay_ms`: 1000 (default)
- `max_delay_ms`: 30000 (default)

**Algorithm**:
```elixir
delay = min(base_delay * 2^attempt + random_jitter, max_delay)
```

**Error Reasons**:
- `rateLimitExceeded` (429): Short-term, retry after 1-5s
- `quotaExceeded` (403): Long-term, may need 10+ min wait

---

## Summary

All NEEDS CLARIFICATION items resolved. Key architectural decisions:

1. **Behaviours over dependencies** for HTTP and Auth abstraction
2. **Leverage existing Raggio.Schema** for type system and BigQuery DDL export
3. **Port migrator logic** from old code; significant reuse possible
4. **Separate up/down.sql** migration format (matches old code)
5. **REST API v2** for BigQuery operations
6. **Telemetry events** following Elixir ecosystem patterns
7. **Exponential backoff** with jitter for rate limit handling
