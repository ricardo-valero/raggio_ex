# Contract: Raggio.BigQuery.Table

**Type**: Elixir Behaviour + `__using__` macro  
**Module**: `Raggio.BigQuery.Table`

## Purpose

Define BigQuery table schemas combining Raggio.Schema type definitions with BigQuery-specific metadata (dataset, table name, partitioning, clustering).

## Behaviour Definition

```elixir
defmodule Raggio.BigQuery.Table do
  @moduledoc """
  Behaviour for defining BigQuery table schemas.
  
  Implement this behaviour to define tables that can be managed by Raggio.BigQuery.
  """

  alias Raggio.Schema.Type

  # Required callbacks
  @callback __dataset__() :: String.t()
  @callback __table__() :: String.t()
  @callback __schema__() :: Type.t()

  # Optional callbacks
  @callback time_partitioning() :: {field :: atom(), granularity :: :day | :hour | :month | :year}
  @callback clustering() :: [atom()]

  @optional_callbacks [time_partitioning: 0, clustering: 0]
end
```

## Using the Table

### Basic Usage

```elixir
defmodule MyApp.BillingItem do
  use Raggio.BigQuery.Table

  alias Raggio.Schema

  @impl true
  def __dataset__, do: "billing"

  @impl true
  def __table__, do: "items"

  @impl true
  def __schema__ do
    Schema.struct([
      {:id, Schema.string()},
      {:tracking, Schema.string()},
      {:amount, Schema.decimal()},
      {:status, Schema.string("pending")},
      {:created_at, Schema.datetime()}
    ])
  end
end
```

### With Partitioning and Clustering

```elixir
defmodule MyApp.EventLog do
  use Raggio.BigQuery.Table

  alias Raggio.Schema

  @impl true
  def __dataset__, do: "analytics"

  @impl true
  def __table__, do: "events"

  @impl true
  def __schema__ do
    Schema.struct([
      {:event_id, Schema.string()},
      {:event_type, Schema.string()},
      {:user_id, Schema.string()},
      {:timestamp, Schema.datetime()},
      {:payload, Schema.string() |> Schema.nullable()}
    ])
  end

  @impl true
  def time_partitioning, do: {:timestamp, :day}

  @impl true
  def clustering, do: [:event_type, :user_id]
end
```

## Provided Functions

When you `use Raggio.BigQuery.Table`, these functions are injected:

### `__qualified_name__/0`

Returns fully qualified table reference.

```elixir
MyApp.BillingItem.__qualified_name__()
# => "billing.items"
```

### `to_create_table_ddl/0`

Generate BigQuery CREATE TABLE DDL.

```elixir
MyApp.BillingItem.to_create_table_ddl()
# => "CREATE TABLE `billing.items` (\n  id STRING NOT NULL,\n  ..."
```

### `to_bigquery_schema/0`

Generate BigQuery JSON schema format.

```elixir
MyApp.BillingItem.to_bigquery_schema()
# => %{
#      "fields" => [
#        %{"name" => "id", "type" => "STRING", "mode" => "REQUIRED"},
#        ...
#      ]
#    }
```

### `validate/1`

Validate data against the schema.

```elixir
MyApp.BillingItem.validate(%{id: "123", tracking: "TRK001", amount: Decimal.new("50.00")})
# => {:ok, %{id: "123", tracking: "TRK001", amount: #Decimal<50.00>, status: "pending", ...}}

MyApp.BillingItem.validate(%{id: 123})  # Wrong type
# => {:error, [%{path: [:id], message: "expected string, got integer", value: 123}]}
```

## Type Mapping

| Raggio.Schema Type | BigQuery Type |
|-------------------|---------------|
| `string()` | STRING |
| `integer()` | INT64 |
| `float()` | FLOAT64 |
| `boolean()` | BOOL |
| `decimal()` | NUMERIC |
| `datetime()` | DATETIME |
| `date()` | DATE |
| `atom()` | STRING |
| `list(inner)` | ARRAY<...> |
| `struct([...])` | STRUCT<...> |

## Mode Mapping

| Raggio.Schema Modifier | BigQuery Mode |
|------------------------|---------------|
| (default) | REQUIRED |
| `optional()` | NULLABLE |
| `nullable()` | NULLABLE |
| `list()` | REPEATED |

## Nested Structs

```elixir
def __schema__ do
  Schema.struct([
    {:id, Schema.string()},
    {:address, Schema.struct([
      {:street, Schema.string()},
      {:city, Schema.string()},
      {:zip, Schema.string()}
    ])}
  ])
end
```

Generates:
```sql
CREATE TABLE `dataset.table` (
  id STRING NOT NULL,
  address STRUCT<street STRING, city STRING, zip STRING> NOT NULL
)
```

## Arrays

```elixir
def __schema__ do
  Schema.struct([
    {:id, Schema.string()},
    {:tags, Schema.list(Schema.string())}
  ])
end
```

Generates:
```sql
CREATE TABLE `dataset.table` (
  id STRING NOT NULL,
  tags ARRAY<STRING>
)
```
