# Contract: Raggio.BigQuery.Repo

**Type**: Elixir Behaviour + `__using__` macro  
**Module**: `Raggio.BigQuery.Repo`

## Purpose

Connection manager that orchestrates HTTP and Auth adapters, provides data operations (insert, merge, query), and schema management operations.

## Behaviour Definition

```elixir
defmodule Raggio.BigQuery.Repo do
  @moduledoc """
  Behaviour and macro for defining BigQuery repositories.
  
  A Repo is the main interface for BigQuery operations. It holds configuration
  for HTTP client, authentication, and project settings.
  """

  @type table :: module()
  @type rows :: [map()]
  @type query :: String.t()
  @type params :: map() | keyword()
  @type opts :: keyword()

  # Connection
  @callback status() :: :connected | {:error, term()}
  @callback config() :: map()

  # Data operations
  @callback insert(table, rows, opts) :: {:ok, count :: non_neg_integer()} | {:error, term()}
  @callback merge(table, rows, opts) :: {:ok, count :: non_neg_integer()} | {:error, term()}
  @callback query(query, params) :: {:ok, [map()]} | {:error, term()}
  @callback query(query) :: {:ok, [map()]} | {:error, term()}

  # Schema operations
  @callback get_table_schema(table) :: {:ok, map()} | {:error, term()}
  @callback diff_schema(table) :: {:ok, Raggio.BigQuery.Diff.t()} | {:error, term()}
  @callback apply_ddl(sql :: String.t()) :: :ok | {:error, term()}
end
```

## Using the Repo

```elixir
defmodule MyApp.BigQueryRepo do
  use Raggio.BigQuery.Repo,
    otp_app: :my_app
end
```

## Configuration

```elixir
# config/config.exs
config :my_app, MyApp.BigQueryRepo,
  project_id: "my-gcp-project",
  http_client: MyApp.ReqHTTPClient,
  auth: MyApp.GothAuth,
  auth_config: %{
    source: {:default, scopes: ["https://www.googleapis.com/auth/bigquery"]}
  },
  default_dataset: "my_dataset"  # optional
```

## API Reference

### Connection

#### `status/0`

Verify connectivity to BigQuery.

```elixir
MyApp.BigQueryRepo.status()
# => :connected
# => {:error, %Raggio.BigQuery.Error{type: :auth_error, ...}}
```

#### `config/0`

Get resolved configuration.

```elixir
MyApp.BigQueryRepo.config()
# => %{project_id: "my-project", http_client: ..., auth: ...}
```

### Data Operations

#### `insert/3`

Insert rows via streaming insert API.

```elixir
rows = [
  %{id: "1", name: "Alice", amount: Decimal.new("100.50")},
  %{id: "2", name: "Bob", amount: Decimal.new("200.00")}
]

MyApp.BigQueryRepo.insert(MyApp.BillingItem, rows)
# => {:ok, 2}

# With options
MyApp.BigQueryRepo.insert(MyApp.BillingItem, rows, skip_invalid_rows: true)
```

**Options**:
- `:skip_invalid_rows` - Continue on invalid rows (default: false)
- `:timeout` - Request timeout in ms (default: 30_000)

**Batching**: Automatically batches rows to stay under 10MB limit.

#### `merge/3`

Upsert rows using MERGE statement.

```elixir
MyApp.BigQueryRepo.merge(MyApp.BillingItem, rows, key: :id)
# => {:ok, 2}

# Multiple key columns
MyApp.BigQueryRepo.merge(MyApp.BillingItem, rows, key: [:dataset_id, :tracking])
```

**Options**:
- `:key` - (Required) Column(s) to match for update vs insert
- `:batch_size` - Rows per batch (default: 1000)
- `:timeout` - Request timeout in ms (default: 60_000)

#### `query/1`, `query/2`

Execute SQL query.

```elixir
MyApp.BigQueryRepo.query("SELECT * FROM billing.items LIMIT 10")
# => {:ok, [%{"id" => "1", "name" => "Alice", ...}, ...]}

# With parameters
MyApp.BigQueryRepo.query(
  "SELECT * FROM billing.items WHERE status = @status",
  %{status: "active"}
)
# => {:ok, [...]}
```

### Schema Operations

#### `get_table_schema/1`

Fetch remote table schema.

```elixir
MyApp.BigQueryRepo.get_table_schema(MyApp.BillingItem)
# => {:ok, %{"fields" => [%{"name" => "id", "type" => "STRING", ...}, ...]}}
```

#### `diff_schema/1`

Compare local schema definition to remote table.

```elixir
MyApp.BigQueryRepo.diff_schema(MyApp.BillingItem)
# => {:ok, %Raggio.BigQuery.Diff{
#      table: MyApp.BillingItem,
#      changes: [%Change{type: :add, field: "status", new_type: :string}],
#      has_destructive: false,
#      has_renames: false
#    }}
```

#### `apply_ddl/1`

Execute DDL statement.

```elixir
sql = "ALTER TABLE billing.items ADD COLUMN status STRING"
MyApp.BigQueryRepo.apply_ddl(sql)
# => :ok
```

## Error Handling

All operations return `{:error, %Raggio.BigQuery.Error{}}` on failure:

```elixir
case MyApp.BigQueryRepo.insert(MyApp.BillingItem, rows) do
  {:ok, count} -> 
    IO.puts("Inserted #{count} rows")
  
  {:error, %Raggio.BigQuery.Error{type: :validation_error} = e} ->
    IO.puts("Invalid data: #{e.message}")
  
  {:error, %Raggio.BigQuery.Error{type: :api_error} = e} ->
    IO.puts("BigQuery error: #{e.details.error_message}")
end
```
