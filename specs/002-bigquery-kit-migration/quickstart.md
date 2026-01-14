# Quickstart: Raggio.BigQuery

Get started with Raggio.BigQuery in 5 minutes.

## Prerequisites

- Elixir 1.14+
- A GCP project with BigQuery enabled
- Service account credentials (or ADC configured)

## Step 1: Add Dependencies

```elixir
# mix.exs
def deps do
  [
    {:raggio, "~> 0.1.0"},
    # Add your preferred HTTP client
    {:req, "~> 0.4"},
    # Add your preferred auth library (optional)
    {:goth, "~> 1.4"}
  ]
end
```

## Step 2: Implement HTTP Client Adapter

```elixir
# lib/my_app/bigquery/req_http_client.ex
defmodule MyApp.BigQuery.ReqHTTPClient do
  @behaviour Raggio.BigQuery.HTTPClient

  @impl true
  def request(method, url, headers, body, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case Req.request(method: method, url: url, headers: headers, body: body, receive_timeout: timeout) do
      {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status: status, headers: resp_headers, body: resp_body}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Step 3: Implement Auth Adapter

```elixir
# lib/my_app/bigquery/goth_auth.ex
defmodule MyApp.BigQuery.GothAuth do
  @behaviour Raggio.BigQuery.Auth

  @impl true
  def get_token(config) do
    source = Map.get(config, :source, {:default, scopes: ["https://www.googleapis.com/auth/bigquery"]})
    
    case Goth.fetch(source) do
      {:ok, %Goth.Token{token: token}} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def refresh_token(config, _old_token), do: get_token(config)
end
```

## Step 4: Define Your Repo

```elixir
# lib/my_app/bigquery_repo.ex
defmodule MyApp.BigQueryRepo do
  use Raggio.BigQuery.Repo,
    otp_app: :my_app
end
```

Configure in `config/config.exs`:

```elixir
config :my_app, MyApp.BigQueryRepo,
  project_id: System.get_env("GCP_PROJECT_ID"),
  http_client: MyApp.BigQuery.ReqHTTPClient,
  auth: MyApp.BigQuery.GothAuth,
  auth_config: %{}
```

## Step 5: Define a Table

```elixir
# lib/my_app/tables/billing_item.ex
defmodule MyApp.Tables.BillingItem do
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

  @impl true
  def time_partitioning, do: {:created_at, :day}

  @impl true
  def clustering, do: [:tracking]
end
```

## Step 6: Use It!

### Check Connection

```elixir
iex> MyApp.BigQueryRepo.status()
:connected
```

### Push Schema to BigQuery

```bash
mix raggio.bigquery.push
# Creates table billing.items in BigQuery
```

### Insert Data

```elixir
iex> rows = [
...>   %{id: "001", tracking: "TRK123", amount: Decimal.new("99.99"), created_at: DateTime.utc_now()},
...>   %{id: "002", tracking: "TRK456", amount: Decimal.new("149.50"), created_at: DateTime.utc_now()}
...> ]
iex> MyApp.BigQueryRepo.insert(MyApp.Tables.BillingItem, rows)
{:ok, 2}
```

### Query Data

```elixir
iex> MyApp.BigQueryRepo.query("SELECT * FROM billing.items WHERE status = 'pending' LIMIT 10")
{:ok, [%{"id" => "001", "tracking" => "TRK123", ...}, ...]}
```

### Generate Migrations

When you change your schema:

```bash
# Generate migration files
mix raggio.bigquery.generate "add_notes_field"

# Apply migrations
mix raggio.bigquery.migrate

# Check status
mix raggio.bigquery.status

# Rollback if needed
mix raggio.bigquery.rollback
```

## What's Next?

- See [contracts/table.md](./contracts/table.md) for advanced table options
- See [contracts/repo.md](./contracts/repo.md) for all Repo operations
- See [contracts/http_client.md](./contracts/http_client.md) for custom HTTP clients
- See [contracts/auth.md](./contracts/auth.md) for authentication options
