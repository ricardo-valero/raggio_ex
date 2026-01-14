defmodule Raggio.BigQuery.Telemetry do
  @moduledoc """
  Telemetry event helpers for Raggio.BigQuery.

  All events are prefixed with `[:raggio, :bigquery, ...]`.

  ## Events

  ### HTTP Requests
  - `[:raggio, :bigquery, :request, :start]` - Before HTTP request
  - `[:raggio, :bigquery, :request, :stop]` - After successful HTTP request
  - `[:raggio, :bigquery, :request, :exception]` - HTTP request failed

  ### Data Operations
  - `[:raggio, :bigquery, :insert, :start | :stop | :exception]`
  - `[:raggio, :bigquery, :merge, :start | :stop | :exception]`
  - `[:raggio, :bigquery, :query, :start | :stop | :exception]`

  ### Migrations
  - `[:raggio, :bigquery, :migration, :start | :stop | :exception]`

  ### Retry
  - `[:raggio, :bigquery, :retry]` - Retry attempt

  ## Usage

      Raggio.BigQuery.Telemetry.span([:request], %{method: :get, url: url}, fn ->
        HTTPClient.request(:get, url, headers, nil, [])
      end)
  """

  @doc """
  Execute a function within a telemetry span.

  Emits `:start`, `:stop`, and `:exception` events automatically.

  ## Parameters

  - `event` - Event name suffix (will be prefixed with `[:raggio, :bigquery]`)
  - `metadata` - Metadata map for the event
  - `fun` - Function to execute

  ## Returns

  The result of the function.
  """
  @spec span(list(atom()), map(), (-> result)) :: result when result: any()
  def span(event, metadata, fun)
      when is_list(event) and is_map(metadata) and is_function(fun, 0) do
    :telemetry.span(
      [:raggio, :bigquery | event],
      metadata,
      fn ->
        result = fun.()
        {result, %{}}
      end
    )
  end

  @doc """
  Emit a single telemetry event.

  ## Parameters

  - `event` - Event name suffix (will be prefixed with `[:raggio, :bigquery]`)
  - `measurements` - Measurements map
  - `metadata` - Metadata map
  """
  @spec emit(list(atom()), map(), map()) :: :ok
  def emit(event, measurements \\ %{}, metadata \\ %{}) when is_list(event) do
    :telemetry.execute([:raggio, :bigquery | event], measurements, metadata)
  end
end
