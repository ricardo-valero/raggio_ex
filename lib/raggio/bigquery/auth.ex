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
          goth_name = Map.get(config, :goth_name, MyApp.Goth)
          case Goth.fetch(goth_name) do
            {:ok, %{token: token}} -> {:ok, token}
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
      end
  """

  @type token :: String.t()
  @type config :: map()
  @type error_reason :: atom() | String.t() | Exception.t()

  @doc """
  Acquire a valid bearer token for BigQuery API requests.

  ## Parameters

  - `config` - Configuration map passed from Repo config

  ## Returns

  - `{:ok, token}` - Valid bearer token string
  - `{:error, reason}` - Error acquiring token
  """
  @callback get_token(config()) :: {:ok, token()} | {:error, error_reason()}

  @doc """
  Refresh an expired token.

  This callback is optional. If not implemented, `get_token/1` will be called instead.

  ## Parameters

  - `config` - Configuration map passed from Repo config
  - `old_token` - The expired token

  ## Returns

  - `{:ok, token}` - New valid bearer token
  - `{:error, reason}` - Error refreshing token
  """
  @callback refresh_token(config(), old_token :: token()) ::
              {:ok, token()} | {:error, error_reason()}

  @optional_callbacks [refresh_token: 2]
end
