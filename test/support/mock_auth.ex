defmodule Raggio.BigQuery.MockAuth do
  @moduledoc false
  @behaviour Raggio.BigQuery.Auth

  @impl true
  def get_token(_config) do
    {:ok, "mock-token-#{System.unique_integer([:positive])}"}
  end

  @impl true
  def refresh_token(_config, _old_token) do
    get_token(%{})
  end
end
