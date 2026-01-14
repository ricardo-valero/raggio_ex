# Contract: Raggio.BigQuery.HTTPClient

**Type**: Elixir Behaviour  
**Module**: `Raggio.BigQuery.HTTPClient`

## Purpose

Abstraction layer for HTTP transport, enabling users to plug in their preferred HTTP client (Req, Finch, HTTPoison, Mint, etc.) without the library depending on any specific implementation.

## Behaviour Definition

```elixir
defmodule Raggio.BigQuery.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client adapters.
  
  Implement this behaviour to use your preferred HTTP client with Raggio.BigQuery.
  """

  @type method :: :get | :post | :put | :patch | :delete
  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t() | nil
  @type opts :: keyword()
  
  @type response :: %{
    status: pos_integer(),
    headers: headers(),
    body: String.t()
  }

  @doc """
  Execute an HTTP request.
  
  ## Parameters
  
  - `method` - HTTP method (:get, :post, :put, :patch, :delete)
  - `url` - Full URL including query parameters
  - `headers` - List of {name, value} header tuples
  - `body` - Request body as string (nil for bodyless requests)
  - `opts` - Implementation-specific options (timeout, etc.)
  
  ## Returns
  
  - `{:ok, response}` - Successful response with status, headers, body
  - `{:error, reason}` - Error with implementation-specific reason
  """
  @callback request(method, url, headers, body, opts) :: {:ok, response} | {:error, term()}
end
```

## Required Headers

The library will always include these headers in requests:
- `Authorization: Bearer {token}` (obtained from Auth adapter)
- `Content-Type: application/json` (for POST/PUT/PATCH)

## Example Implementation (Req)

```elixir
defmodule MyApp.ReqHTTPClient do
  @behaviour Raggio.BigQuery.HTTPClient

  @impl true
  def request(method, url, headers, body, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    req_opts = [
      method: method,
      url: url,
      headers: headers,
      body: body,
      receive_timeout: timeout
    ]
    
    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status: status, headers: resp_headers, body: resp_body}}
      
      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport_error, reason}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Example Implementation (HTTPoison)

```elixir
defmodule MyApp.HTTPoisonClient do
  @behaviour Raggio.BigQuery.HTTPClient

  @impl true
  def request(method, url, headers, body, opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    http_opts = [timeout: timeout, recv_timeout: timeout]
    
    case HTTPoison.request(method, url, body || "", headers, http_opts) do
      {:ok, %HTTPoison.Response{status_code: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status: status, headers: resp_headers, body: resp_body}}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
```

## Configuration

```elixir
# config/config.exs
config :my_app, MyApp.BigQueryRepo,
  http_client: MyApp.ReqHTTPClient,
  # ... other options
```

## Error Handling

Implementations should return errors as:
- `{:error, :timeout}` for request timeouts
- `{:error, :econnrefused}` for connection failures
- `{:error, {:ssl_error, reason}}` for TLS issues
- `{:error, term()}` for other errors

The library will wrap these in `Raggio.BigQuery.Error` structs for consistent handling.
