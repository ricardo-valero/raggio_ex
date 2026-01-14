# Data Model: BigQuery Kit Migration

**Feature**: 002-bigquery-kit-migration  
**Date**: 2026-01-14

## Entities

### 1. Raggio.BigQuery.Repo (Runtime Entity)

**Purpose**: Connection manager holding adapters and providing data operations

**Configuration** (not stored; provided at compile/runtime):
```elixir
%{
  project_id: String.t(),          # GCP project ID
  http_client: module(),           # HTTPClient behaviour implementation
  auth: module(),                  # Auth behaviour implementation  
  auth_config: map(),              # Passed to auth adapter
  default_dataset: String.t() | nil # Optional default dataset
}
```

**State**: Stateless GenServer-style module; adapters invoked per-request

**Relationships**:
- Uses HTTPClient for all API calls
- Uses Auth to get bearer tokens
- Operates on Tables

---

### 2. Raggio.BigQuery.Table (Compile-time Behaviour)

**Purpose**: Define BigQuery table schema with metadata

**Callbacks**:
| Callback | Return Type | Required |
|----------|-------------|----------|
| `__dataset__/0` | `String.t()` | Yes |
| `__table__/0` | `String.t()` | Yes |
| `__schema__/0` | `Raggio.Schema.Type.t()` | Yes |
| `time_partitioning/0` | `{field, granularity}` | No |
| `clustering/0` | `[field]` | No |

**Derived Functions** (provided by `use Raggio.BigQuery.Table`):
- `__qualified_name__/0` → `"dataset.table"`
- `to_create_table_ddl/0` → BigQuery CREATE TABLE SQL
- `to_bigquery_schema/0` → BigQuery JSON schema

**Relationships**:
- References `Raggio.Schema.Type` for field definitions
- Used by Repo for data operations

---

### 3. Raggio.BigQuery.Change (Data Struct)

**Purpose**: Represent a single schema change detected by Differ

**Fields**:
```elixir
%Raggio.BigQuery.Change{
  type: :add | :remove | :modify | :rename,
  field: String.t(),
  old_field: String.t() | nil,    # For renames
  old_type: atom() | nil,
  new_type: atom() | nil,
  old_mode: :required | :nullable | nil,
  new_mode: :required | :nullable | nil
}
```

**Validation Rules**:
- `:rename` requires `old_field` to be set
- `:add` requires `new_type` only
- `:remove` requires `old_type` only
- `:modify` requires both old and new values

---

### 4. Raggio.BigQuery.Diff (Data Struct)

**Purpose**: Collection of changes between local and remote schema

**Fields**:
```elixir
%Raggio.BigQuery.Diff{
  table: module(),                # Table module
  changes: [Change.t()],          # List of detected changes
  has_destructive: boolean(),     # Any column drops?
  has_renames: boolean()          # Any potential renames?
}
```

---

### 5. Raggio.BigQuery.Migration (Data Struct)

**Purpose**: Represent a migration (file-based, not stored in DB)

**Fields**:
```elixir
%Raggio.BigQuery.Migration{
  version: String.t(),            # Timestamp: "20260114120000"
  name: String.t(),               # Human name: "add_status_field"
  dataset: String.t(),            # Target dataset
  path: Path.t(),                 # Directory path
  up_sql: String.t() | nil,       # Loaded SQL content
  down_sql: String.t() | nil      # Loaded SQL content
}
```

**File System Layout**:
```
priv/raggio/bigquery/{dataset}/{version}_{name}/
  up.sql
  down.sql
```

---

### 6. Raggio.BigQuery.AppliedMigration (Tracked in BigQuery)

**Purpose**: Track which migrations have been applied to a dataset

**BigQuery Table**: `{dataset}._raggio_migrations`

**Columns**:
| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| version | STRING | NOT NULL | Migration version (primary identifier) |
| name | STRING | NOT NULL | Migration name |
| applied_at | TIMESTAMP | NOT NULL | When migration was applied |
| checksum | STRING | NULL | SHA256 of up.sql content |

**Operations**:
- Insert via MERGE (idempotent)
- Query for status
- Delete on rollback

---

### 7. Raggio.BigQuery.Error (Data Struct)

**Purpose**: Structured error representation

**Variants**:
```elixir
%Raggio.BigQuery.Error{
  type: :http_error | :auth_error | :api_error | :validation_error | :migration_error,
  message: String.t(),
  details: map(),
  cause: Exception.t() | nil
}
```

**Details by Type**:
- `:http_error` → `%{status: integer(), body: String.t()}`
- `:auth_error` → `%{reason: atom()}`
- `:api_error` → `%{error_code: String.t(), error_message: String.t()}`
- `:validation_error` → `%{path: [atom()], message: String.t()}`
- `:migration_error` → `%{migration: String.t(), sql: String.t()}`

---

## Entity Relationships

```
┌─────────────────┐
│      Repo       │ uses ──┬──▶ HTTPClient (behaviour)
│  (connection)   │        └──▶ Auth (behaviour)
└────────┬────────┘
         │ operates on
         ▼
┌─────────────────┐
│     Table       │ ──▶ Raggio.Schema.Type (schema definition)
│  (behaviour)    │
└────────┬────────┘
         │ compared by
         ▼
┌─────────────────┐
│     Differ      │ ──▶ produces Diff (with Changes)
└────────┬────────┘
         │ generates
         ▼
┌─────────────────┐
│   Migration     │ ──▶ executed by Migrator
│   (file-based)  │
└────────┬────────┘
         │ tracked in
         ▼
┌─────────────────┐
│AppliedMigration │ (BigQuery table: _raggio_migrations)
└─────────────────┘
```

---

## State Transitions

### Migration Lifecycle

```
PENDING ──apply──▶ APPLIED
   ▲                  │
   └───rollback───────┘
```

### Diff to DDL Pipeline

```
Local Schema ──┐
               ├──▶ Differ ──▶ Diff ──▶ DDL Generator ──▶ SQL
Remote Schema ─┘
```
