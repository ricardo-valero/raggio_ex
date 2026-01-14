# Contract: Raggio.BigQuery.Auth

**Type**: Elixir Behaviour  
**Module**: `Raggio.BigQuery.Auth`

## Purpose

Abstraction layer for authentication, enabling users to plug in their preferred auth strategy (Goth, manual tokens, workload identity, custom OAuth) without the library depending on any specific implementation.

## Behaviour Definition

```elixir
defmodule Raggio.BigQuery.Auth do
  @moduledoc """
  Behaviour for authentication adapters.
  
  Implement this behaviour to provide GCP authentication for Raggio.BigQuery.
  """

  @type config :: map()
  @type token :: String.t()

  @doc """
  Get a valid access token.
  
  ## Parameters
  
  - `config` - Implementation-specific configuration (credentials path, scopes, etc.)
  
  ## Returns
  
  - `{:ok, token}` - Valid bearer token string
  - `{:error, reason}` - Auth failure with reason
  """
  @callback get_token(config) :: {:ok, token} | {:error, term()}

  @doc """
  Refresh an expired or expiring token.
  
  Called when the library detects a 401 response or proactively before expiry.
  Implementations may return the same token if still valid, or fetch a new one.
  
  ## Parameters
  
  - `config` - Implementation-specific configuration
  - `old_token` - The token that needs refreshing
  
  ## Returns
  
  - `{:ok, token}` - New valid bearer token
  - `{:error, reason}` - Refresh failure
  """
  @callback refresh_token(config, old_token :: token) :: {:ok, token} | {:error, term()}
end
```

## Required Scopes

BigQuery operations require these OAuth2 scopes:
- `https://www.googleapis.com/auth/bigquery` (full access)
- Or `https://www.googleapis.com/auth/bigquery.readonly` (read-only)

## Example Implementation (Goth)

```elixir
defmodule MyApp.GothAuth do
  @behaviour Raggio.BigQuery.Auth

  @bigquery_scope "https://www.googleapis.com/auth/bigquery"

  @impl true
  def get_token(config) do
    source = Map.get(config, :source, {:default, scopes: [@bigquery_scope]})
    
    case Goth.fetch(source) do
      {:ok, %Goth.Token{token: token}} -> {:ok, token}
      {:error, reason} -> {:error, {:goth_error, reason}}
    end
  end

  @impl true
  def refresh_token(config, _old_token) do
    # Goth handles token caching and refresh internally
    get_token(config)
  end
end
```

## Example Implementation (Static Token)

```elixir
defmodule MyApp.StaticAuth do
  @behaviour Raggio.BigQuery.Auth

  @impl true
  def get_token(%{token: token}) when is_binary(token), do: {:ok, token}
  def get_token(_), do: {:error, :token_not_configured}

  @impl true
  def refresh_token(%{token: token}, _old), do: {:ok, token}
  def refresh_token(_, _), do: {:error, :token_not_configured}
end
```

## Example Implementation (Workload Identity)

```elixir
defmodule MyApp.WorkloadIdentityAuth do
  @behaviour Raggio.BigQuery.Auth

  @metadata_url "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"

  @impl true
  def get_token(_config) do
    headers = [{"Metadata-Flavor", "Google"}]
    
    case :httpc.request(:get, {@metadata_url, headers}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        %{"access_token" => token} = Jason.decode!(body)
        {:ok, token}
      
      {:ok, {{_, status, _}, _, body}} ->
        {:error, {:metadata_error, status, body}}
      
      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  @impl true
  def refresh_token(config, _old_token), do: get_token(config)
end
```

## Configuration

```elixir
# config/config.exs
config :my_app, MyApp.BigQueryRepo,
  auth: MyApp.GothAuth,
  auth_config: %{
    source: {:default, scopes: ["https://www.googleapis.com/auth/bigquery"]}
  },
  # ... other options
```

## Error Handling

Implementations should return errors as:
- `{:error, :invalid_credentials}` for bad credentials
- `{:error, :token_expired}` for expired tokens that can't refresh
- `{:error, {:http_error, reason}}` for network issues
- `{:error, term()}` for other errors

The library will retry with `refresh_token/2` on 401 responses before failing.
