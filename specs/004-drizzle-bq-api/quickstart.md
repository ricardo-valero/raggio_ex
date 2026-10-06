# Quickstart: Drizzle-like Composable BigQuery API

**Feature**: 004-drizzle-bq-api

## Overview

This feature adds a Drizzle-inspired composable API for defining BigQuery schemas. Define your entire project hierarchy (project -> dataset -> table) in a single, pipeable expression.

**Key Architecture**: `raggio.schema.Type` is THE canonical, portable schema format. BigQuery (and future adapters like API, JSON-Schema) convert to/from this format, enabling "define once, deploy anywhere" workflows.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:raggio, "~> 0.2.0"}
  ]
end
```

## Basic Usage

### Define a Project with Datasets and Tables

```elixir
import Raggio.BigQuery.Composer
alias Raggio.Schema

# Build a complete project schema
{:ok, project} = 
  project("my-analytics-project")
  |> dataset("events")
  |> table("page_views",
       columns: [
         column(:id, Schema.string() |> required()),
         column(:user_id, Schema.string()),
         column(:page_url, Schema.string()),
         column(:referrer, Schema.string() |> Schema.nullable()),
         column(:created_at, Schema.datetime() |> required())
       ],
       partition_by: {:field, :created_at, :day},
       cluster_by: [:user_id]
     )
  |> table("clicks",
       columns: [
         column(:id, Schema.string() |> required()),
         column(:page_view_id, Schema.string()),
         column(:element_id, Schema.string()),
         column(:created_at, Schema.datetime())
       ]
     )
  |> dataset("users")
  |> table("profiles",
       columns: [
         column(:id, Schema.string() |> required()),
         column(:email, Schema.string(pattern: Schema.email())),
         column(:preferences, Schema.struct([
           {:theme, Schema.literal(:light, :dark)},
           {:notifications, Schema.boolean()}
         ])),
         column(:created_at, Schema.datetime())
       ]
     )
  |> build()
```

### Generate DDL

```elixir
# Generate all CREATE TABLE statements
ddl_statements = Raggio.BigQuery.Project.to_ddl(project)

Enum.each(ddl_statements, &IO.puts/1)
# CREATE TABLE `my-analytics-project.events.page_views` (
#   id STRING NOT NULL,
#   user_id STRING,
#   page_url STRING,
#   referrer STRING,
#   created_at DATETIME NOT NULL
# )
# PARTITION BY DATE(created_at)
# CLUSTER BY user_id;
# ...
```

### Parse Existing DDL

```elixir
alias Raggio.BigQuery.DDL.Parser

ddl = """
CREATE TABLE myproject.analytics.events (
  id STRING NOT NULL,
  user_id STRING,
  payload STRUCT<
    action STRING,
    metadata STRUCT<key STRING, value STRING>
  >,
  tags ARRAY<STRING>,
  created_at DATETIME NOT NULL
)
PARTITION BY DATE(created_at)
CLUSTER BY user_id, payload.action
"""

{:ok, parsed} = Parser.parse_create_table(ddl)

# Convert to TableDef
{:ok, table_def} = Parser.to_table_def(parsed)

# Or convert to raggio.schema Type
schema_type = Parser.to_schema_type(parsed.columns)
```

### Use with Existing Table Modules

If you have existing tables defined with `use Raggio.BigQuery.Table`:

```elixir
# Existing module-based tables
defmodule MyApp.Tables.Events do
  use Raggio.BigQuery.Table
  
  @impl true
  def __dataset__, do: "analytics"
  
  @impl true
  def __table__, do: "events"
  
  @impl true
  def __schema__ do
    Schema.struct([{:id, Schema.string()}])
  end
end

# Convert to composable Project
{:ok, project} = Raggio.BigQuery.Composer.from_modules([
  MyApp.Tables.Events,
  MyApp.Tables.Users,
  MyApp.Tables.Invoices
], project_id: "my-project")
```

## Nested Types (STRUCT and ARRAY)

```elixir
# Nested STRUCT
column(:address, Schema.struct([
  {:street, Schema.string()},
  {:city, Schema.string()},
  {:country, Schema.string()},
  {:location, Schema.struct([
    {:lat, Schema.float()},
    {:lng, Schema.float()}
  ])}
]))

# ARRAY types
column(:tags, Schema.list(Schema.string()) |> repeated())

# ARRAY of STRUCT
column(:items, Schema.list(Schema.struct([
  {:sku, Schema.string()},
  {:quantity, Schema.integer()},
  {:price, Schema.decimal()}
])))
```

## Partitioning and Clustering

```elixir
# Time partitioning by field
table("events",
  columns: [...],
  partition_by: {:field, :created_at, :day}  # :hour, :day, :month, :year
)

# Ingestion time partitioning
table("logs",
  columns: [...],
  partition_by: {:ingestion_time, :day}
)

# Range partitioning
table("orders",
  columns: [...],
  partition_by: {:range, :order_total, 0, 10000, 100}
)

# Clustering (up to 4 columns)
table("events",
  columns: [...],
  cluster_by: [:user_id, :event_type, :region]
)
```

## Schema Composition (Effect-TS Style)

```elixir
# Compose types with pipe operator
email_type = 
  Schema.string()
  |> Schema.constrain(&String.contains?(&1, "@"))
  |> description("Valid email address")

# Reusable column sets
timestamps = [
  column(:created_at, Schema.datetime() |> required()),
  column(:updated_at, Schema.datetime())
]

audit_fields = [
  column(:created_by, Schema.string()),
  column(:updated_by, Schema.string())
]

# Spread into table definitions
table("users",
  columns: [
    column(:id, Schema.string() |> required()),
    column(:email, email_type)
  ] ++ timestamps ++ audit_fields
)
```

## Bidirectional Schema Conversion

The adapter architecture enables converting schemas between formats. `raggio.schema.Type` is the canonical format that all adapters convert to/from.

### BigQuery → Canonical Schema

Extract a portable schema from a BigQuery table definition:

```elixir
alias Raggio.Schema.Adapters.BigQuery, as: BQAdapter

# Start with a BigQuery TableDef
table_def = %Raggio.BigQuery.TableDef{
  name: "events",
  columns: [
    %Column{name: :id, type: Schema.string(), mode: :required},
    %Column{name: :user_id, type: Schema.string()},
    %Column{name: :created_at, type: Schema.datetime(), mode: :required}
  ],
  partition_by: {:field, :created_at, :day},
  cluster_by: [:user_id]
}

# Convert to canonical raggio.schema.Type
canonical_schema = BQAdapter.to_schema(table_def)

# Result: portable schema with BigQuery metadata preserved
# %Type{
#   kind: :struct,
#   fields: [
#     {:id, %Type{kind: :string}},
#     {:user_id, %Type{kind: :string}},
#     {:created_at, %Type{kind: :datetime}}
#   ],
#   metadata: %{
#     bigquery: %{
#       table_name: "events",
#       partition_by: {:field, :created_at, :day},
#       cluster_by: [:user_id]
#     }
#   }
# }
```

### Canonical Schema → BigQuery

Create a BigQuery table from any canonical schema:

```elixir
# Start with a canonical schema (could come from any source)
canonical_schema = Schema.struct([
  {:id, Schema.string()},
  {:name, Schema.string()},
  {:email, Schema.string()}
])

# Convert to BigQuery TableDef
{:ok, table_def} = BQAdapter.from_schema(canonical_schema, name: "users")

# Generate DDL
ddl = Raggio.BigQuery.TableDef.to_ddl(table_def, dataset: "main", project: "my-project")
```

### Cross-Adapter Workflow (Future-Ready)

This pattern enables future adapters to share schemas:

```elixir
# Define schema once using BigQuery
{:ok, project} = 
  project("my-project")
  |> dataset("api")
  |> table("users", columns: [...])
  |> build()

# Extract canonical schema
user_table = project |> get_table("api", "users")
canonical = BQAdapter.to_schema(user_table)

# Future: Use same schema for API endpoints
# {:ok, openapi_schema} = Raggio.Schema.Adapters.OpenAPI.from_schema(canonical)

# Future: Use same schema for JSON validation
# {:ok, json_schema} = Raggio.Schema.Adapters.JSONSchema.from_schema(canonical)
```

### Metadata Preservation and Warnings

Adapter-specific metadata is preserved under namespaced keys:

```elixir
# Schema with BigQuery-specific metadata
schema = %Type{
  kind: :struct,
  fields: [...],
  metadata: %{
    bigquery: %{partition_by: {:field, :created_at, :day}},
    description: "User events table"
  }
}

# When converting to a different adapter (future), warnings are emitted
# for metadata that can't be mapped:
# 
# [warning] OpenAPI adapter ignoring bigquery metadata: [:partition_by]
```

## Error Handling

```elixir
# Build returns {:error, errors} on validation failure
case build(ctx) do
  {:ok, project} -> 
    IO.puts("Project valid!")
    
  {:error, errors} ->
    Enum.each(errors, fn error ->
      IO.puts("#{error.type}: #{error.message} at #{error.path}")
    end)
end

# Or use build! to raise on error
project = build!(ctx)  # Raises Raggio.BigQuery.Error

# Parser errors include position
case Parser.parse_create_table(invalid_ddl) do
  {:ok, parsed} -> 
    parsed
    
  {:error, error} ->
    IO.puts(Parser.Error.format(error))
    # Parse error at line 3, column 15: expected data type
    #       payload STRUCT<action STRING, metadata>
    #                                              ^
end
```

## Next Steps

- See [data-model.md](./data-model.md) for entity definitions
- See [contracts/](./contracts/) for full API contracts
- See [research.md](./research.md) for design decisions
