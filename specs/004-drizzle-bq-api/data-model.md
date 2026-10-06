# Data Model: Drizzle-like Composable BigQuery API

**Feature**: 004-drizzle-bq-api  
**Date**: 2026-01-17 (Updated with Adapter Architecture)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Raggio.Schema.Type (CANONICAL)                           │
│  The portable schema format - all adapters convert to/from this             │
│  metadata: %{bigquery: %{...}, api: %{...}, description: "..."}            │
└─────────────────────────────────────────────────────────────────────────────┘
                    ▲                               ▲
                    │ to_schema/1                   │ to_schema/1 (future)
                    │ from_schema/1                 │ from_schema/1
                    │                               │
┌───────────────────┴───────────────┐   ┌──────────┴──────────────────────────┐
│  Raggio.Schema.Adapters.BigQuery  │   │  Future: OpenAPI, JSON-Schema, etc. │
│  @behaviour Raggio.Schema.Adapter │   │  @behaviour Raggio.Schema.Adapter   │
└───────────────────────────────────┘   └─────────────────────────────────────┘
                    ▲
                    │
┌───────────────────┴───────────────────────────────────────────────────────┐
│                    BigQuery Structs (Adapter-Specific)                     │
│  Project → Dataset → TableDef → Column                                     │
└───────────────────────────────────────────────────────────────────────────┘
```

## Entity Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Project                                 │
│  project_id: "my-gcp-project"                                  │
│  datasets: [Dataset, ...]                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│    Dataset      │  │    Dataset      │  │    Dataset      │
│  name: "raw"    │  │  name: "staging"│  │  name: "prod"   │
│  tables: [...]  │  │  tables: [...]  │  │  tables: [...]  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                         TableDef                                │
│  name: "events"                                                 │
│  columns: [Column, ...]                                         │
│  partition_by: {:field, :created_at, :day}                     │
│  cluster_by: [:user_id, :event_type]                           │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Column                                  │
│  name: :id                                                      │
│  type: %Raggio.Schema.Type{kind: :string}                      │
│  mode: :required                                                │
│  description: "Unique event identifier"                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entity Definitions

### Project

**Purpose**: Top-level container representing a BigQuery project.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| project_id | String | Yes | GCP project identifier |
| datasets | [Dataset] | Yes | List of datasets in project |
| metadata | map | No | Custom metadata (labels, etc.) |

**Validation Rules**:
- `project_id` must match pattern `^[a-z][a-z0-9-]{4,28}[a-z0-9]$`
- `datasets` names must be unique within project

**State Transitions**: N/A (immutable data structure)

---

### Dataset

**Purpose**: Container grouping related tables within a project.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | String | Yes | Dataset identifier |
| tables | [TableDef] | Yes | List of tables in dataset |
| location | String | No | Geographic location (e.g., "US", "EU") |
| default_partition_expiration_ms | integer | No | Auto-delete partitions after N ms |
| metadata | map | No | Custom metadata |

**Validation Rules**:
- `name` must match `^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$`
- `tables` names must be unique within dataset
- `location` if provided must be valid BigQuery region

---

### TableDef

**Purpose**: Schema definition for a BigQuery table.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | String | Yes | Table identifier |
| columns | [Column] | Yes | Column definitions |
| partition_by | PartitionConfig | No | Time or range partitioning |
| cluster_by | [atom] | No | Clustering columns (max 4) |
| description | String | No | Table description |
| expiration_time | DateTime | No | Table expiration |
| metadata | map | No | Custom metadata |

**Validation Rules**:
- `name` must match `^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$`
- `columns` names must be unique within table
- `cluster_by` max 4 columns, must reference valid column names
- `partition_by` field must reference valid column or use pseudo-column

**PartitionConfig Type**:
```
{:field, column_name, granularity}  # TIME partitioning
{:range, column_name, start, end, interval}  # RANGE partitioning
{:ingestion_time, granularity}  # _PARTITIONTIME
```

Where `granularity` is `:hour | :day | :month | :year`

---

### Column

**Purpose**: Individual field definition within a table.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | atom | Yes | Column identifier |
| type | Raggio.Schema.Type | Yes | Column data type |
| mode | :nullable \| :required \| :repeated | No | Column mode (default: :nullable) |
| description | String | No | Column description |
| default_value | any | No | Default value expression |
| metadata | map | No | Custom metadata |

**Validation Rules**:
- `name` must be valid identifier (starts with letter/underscore)
- `type.kind` must be BigQuery-compatible
- `mode` :repeated only valid for non-RECORD types at top level
- Nested STRUCT fields inherit parent validation

**BigQuery Type Mapping**:

| raggio.schema kind | BigQuery Type |
|-------------------|---------------|
| :string | STRING |
| :integer | INT64 |
| :float | FLOAT64 |
| :boolean | BOOL |
| :decimal | NUMERIC / BIGNUMERIC |
| :datetime | DATETIME |
| :date | DATE |
| :struct | STRUCT / RECORD |
| :list | ARRAY |

---

### ParsedDDL

**Purpose**: Intermediate representation from DDL parsing.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| statement_type | atom | Yes | :create_table, :create_schema, etc. |
| qualified_name | {project, dataset, table} | Yes | Full table reference |
| columns | [ParsedColumn] | Yes | Parsed column definitions |
| options | map | No | Table options (partition, cluster, etc.) |
| source_position | {line, column} | Yes | Position in source for errors |

**ParsedColumn Type**:
```elixir
%{
  name: String.t(),
  type: parsed_type(),
  mode: :nullable | :required | :repeated,
  options: map()
}
```

**parsed_type()**:
```elixir
:string | :int64 | :float64 | :bool | :bytes | 
:date | :datetime | :time | :timestamp |
{:numeric, precision, scale} |
{:string, max_length} |
{:array, inner_type} |
{:struct, [parsed_field]}
```

---

### Adapter (Behaviour)

**Purpose**: Contract for bidirectional conversion between raggio.schema.Type and adapter-specific formats.

| Callback | Signature | Description |
|----------|-----------|-------------|
| to_schema/1 | `adapter_format → Type.t()` | Convert adapter format to canonical schema |
| from_schema/1 | `Type.t() → {:ok, adapter_format} \| {:error, term()}` | Convert canonical schema to adapter format |
| adapter_namespace/0 | `→ atom()` | Namespace key for metadata (e.g., `:bigquery`) |

**Implementation Notes**:
- BigQuery adapter is the reference implementation
- Future adapters (API, JSON-Schema) implement same behaviour
- `to_schema/1` preserves adapter-specific metadata under namespaced key
- `from_schema/1` warns about incompatible foreign metadata

**Metadata Structure** (in Type.metadata):
```elixir
%{
  bigquery: %{                    # BigQuery-specific (from BigQuery adapter)
    partition_by: {:field, :created_at, :day},
    cluster_by: [:user_id],
    table_name: "events"
  },
  api: %{...},                    # Future: API adapter metadata
  description: "Shared metadata"  # Portable, used by all adapters
}
```

**Warning Behavior**:
When `from_schema/1` encounters foreign adapter metadata:
- Log warning: "BigQuery adapter ignoring api metadata: [:endpoint]"
- Continue conversion with only relevant metadata

---

## Relationships

```
                    Raggio.Schema.Type (CANONICAL)
                              ▲
                              │ bidirectional via Adapter
                              │
Project 1──────* Dataset      │
Dataset 1──────* TableDef ────┘ (TableDef ↔ Type via BigQuery Adapter)
TableDef 1─────* Column
Column 1───────1 Raggio.Schema.Type
```

- One Project contains many Datasets
- One Dataset contains many TableDefs
- One TableDef contains many Columns
- One Column references one Type (which may be nested)
- **TableDef ↔ Type**: Bidirectional conversion via `Raggio.Schema.Adapters.BigQuery`
  - `to_schema(TableDef) → Type` (extract canonical schema)
  - `from_schema(Type) → TableDef` (create BigQuery table from any schema)

---

## Builder Context (Internal)

**Purpose**: Accumulator for fluent API during build process.

| Field | Type | Description |
|-------|------|-------------|
| project_id | String | Project being built |
| current_dataset | String | Active dataset name |
| datasets | map | Accumulated {name => tables} |
| errors | [Error] | Validation errors encountered |

**State Machine**:
```
:initial → project() → :has_project
:has_project → dataset() → :in_dataset  
:in_dataset → table() → :in_dataset
:in_dataset → dataset() → :in_dataset (flush previous)
:in_dataset → build() → :complete
```

---

## Validation Summary

| Entity | Validation | Error Type |
|--------|-----------|------------|
| Project | Valid project_id format | :invalid_project_id |
| Project | Unique dataset names | :duplicate_dataset |
| Dataset | Valid name format | :invalid_dataset_name |
| Dataset | Unique table names | :duplicate_table |
| TableDef | Valid name format | :invalid_table_name |
| TableDef | Unique column names | :duplicate_column |
| TableDef | Valid partition column | :invalid_partition_field |
| TableDef | Valid cluster columns (max 4) | :invalid_clustering |
| Column | Valid name format | :invalid_column_name |
| Column | Compatible type for BigQuery | :unsupported_type |
| Column | REPEATED mode restrictions | :invalid_mode |

---

## Example Instance

```elixir
%Project{
  project_id: "my-analytics-project",
  datasets: [
    %Dataset{
      name: "events",
      location: "US",
      tables: [
        %TableDef{
          name: "page_views",
          columns: [
            %Column{
              name: :id,
              type: %Type{kind: :string},
              mode: :required,
              description: "Unique event ID"
            },
            %Column{
              name: :user_id,
              type: %Type{kind: :string},
              mode: :nullable
            },
            %Column{
              name: :metadata,
              type: %Type{
                kind: :struct,
                fields: [
                  {:page_url, %Type{kind: :string}},
                  {:referrer, %Type{kind: :string, nullable: true}}
                ]
              },
              mode: :nullable
            },
            %Column{
              name: :created_at,
              type: %Type{kind: :datetime},
              mode: :required
            }
          ],
          partition_by: {:field, :created_at, :day},
          cluster_by: [:user_id]
        }
      ]
    }
  ],
  metadata: %{
    environment: "production"
  }
}
```
