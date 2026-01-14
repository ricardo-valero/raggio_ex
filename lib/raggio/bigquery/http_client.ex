defmodule Raggio.BigQuery.HTTPClient do
  @moduledoc """
  Behaviour for HTTP transport abstraction.

  Implement this behaviour to provide HTTP capabilities to Raggio.BigQuery.
  The library makes no assumptions about the underlying HTTP client.

  ## Example Implementation (using Req)

      defmodule MyApp.ReqHTTPClient do
        @behaviour Raggio.BigQuery.HTTPClient

        @impl true
        def request(method, url, headers, body, opts) do
          timeout = Keyword.get(opts, :timeout, 30_000)

          case Req.request(method: method, url: url, headers: headers, body: body, receive_timeout: timeout) do
            {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
              {:ok, %{status: status, headers: resp_headers, body: resp_body}}
            {:error, exception} ->
              {:error, exception}
          end
        end
      end
  """

  @type method :: :get | :post | :put | :patch | :delete
  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: binary() | nil
  @type opts :: keyword()

  @type response :: %{
          status: non_neg_integer(),
          headers: headers(),
          body: binary()
        }

  @type error_reason :: Exception.t() | atom() | String.t()

  @doc """
  Execute an HTTP request.

  ## Parameters

  - `method` - HTTP method (:get, :post, :put, :patch, :delete)
  - `url` - Full URL including query parameters
  - `headers` - List of {name, value} header tuples
  - `body` - Request body (nil for GET/DELETE, binary for POST/PUT/PATCH)
  - `opts` - Implementation-specific options

  ## Options (suggested, implementation-dependent)

  - `:timeout` - Request timeout in milliseconds (default: 30_000)

  ## Returns

  - `{:ok, response}` - Response map with status, headers, body
  - `{:error, reason}` - Error with implementation-specific reason
  """
  @callback request(method(), url(), headers(), body(), opts()) ::
              {:ok, response()} | {:error, error_reason()}
end
