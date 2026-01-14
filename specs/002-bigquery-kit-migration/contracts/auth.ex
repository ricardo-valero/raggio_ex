defmodule Raggio.BigQuery.Auth do
  @moduledoc """
  Behaviour for authentication abstraction.

  Implement this behaviour to provide authentication to Raggio.BigQuery.
  The library supports any auth strategy: Goth, service accounts, ADC, OAuth.

  ## Example (using Goth)

      defmodule MyApp.GothAuth do
        @behaviour Raggio.BigQuery.Auth

        @impl true
        def get_token(config) do
          source = Map.fetch!(config, :source)
          case Goth.fetch(source) do
            {:ok, %Goth.Token{token: token}} -> {:ok, token}
            {:error, reason} -> {:error, reason}
          end
        end

        @impl true
        def refresh_token(config, _old_token), do: get_token(config)
      end

  ## Example (static token for testing)

      defmodule MyApp.StaticAuth do
        @behaviour Raggio.BigQuery.Auth

        @impl true
        def get_token(config), do: {:ok, Map.fetch!(config, :token)}

        @impl true  
        def refresh_token(_config, _old), do: {:error, :static_token_no_refresh}
      end
  """

  @type token :: String.t()
  @type config :: map()
  @type error_reason :: atom() | String.t() | Exception.t()

  @doc "Acquire a valid bearer token for BigQuery API requests."
  @callback get_token(config()) :: {:ok, token()} | {:error, error_reason()}

  @doc "Refresh an expired token. Optional - defaults to calling get_token/1."
  @callback refresh_token(config(), old_token :: token()) ::
              {:ok, token()} | {:error, error_reason()}

  @optional_callbacks [refresh_token: 2]
end
