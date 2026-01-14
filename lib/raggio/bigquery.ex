defmodule Raggio.BigQuery do
  @moduledoc """
  BigQuery integration for Raggio.

  This module provides a unified interface for BigQuery operations with
  pluggable HTTP client and authentication adapters.

  ## Architecture

  Raggio.BigQuery is HTTP/Auth agnostic - you bring your own:
  - HTTP client (Req, Finch, HTTPoison, etc.)
  - Authentication (Goth, static tokens, custom OAuth, etc.)

  ## Quick Start

  1. Implement the behaviours:

      defmodule MyApp.ReqHTTPClient do
        @behaviour Raggio.BigQuery.HTTPClient

        @impl true
        def request(method, url, headers, body, opts) do
          # Your HTTP implementation
        end
      end

      defmodule MyApp.GothAuth do
        @behaviour Raggio.BigQuery.Auth

        @impl true
        def get_token(config) do
          case Goth.fetch(config[:goth_name]) do
            {:ok, %{token: token}} -> {:ok, token}
            error -> error
          end
        end
      end

  2. Define a Repo:

      defmodule MyApp.BigQueryRepo do
        use Raggio.BigQuery.Repo, otp_app: :my_app

        @impl true
        def config do
          %{
            project_id: "my-project",
            http_client: MyApp.ReqHTTPClient,
            auth: MyApp.GothAuth,
            auth_config: %{goth_name: MyApp.Goth}
          }
        end
      end

  3. Define tables:

      defmodule MyApp.Tables.Events do
        use Raggio.BigQuery.Table
        alias Raggio.Schema

        @impl true
        def __dataset__, do: "analytics"

        @impl true
        def __table__, do: "events"

        @impl true
        def __schema__ do
          Schema.struct([
            {:id, Schema.string()},
            {:event_type, Schema.string()},
            {:payload, Schema.string() |> Schema.optional()},
            {:created_at, Schema.datetime()}
          ])
        end

        @impl true
        def __time_partitioning__, do: [field: :created_at, type: :day]
      end

  4. Use:

      # Check connectivity
      :connected = MyApp.BigQueryRepo.status()

      # Insert data
      {:ok, 2} = MyApp.BigQueryRepo.insert(MyApp.Tables.Events, [
        %{id: "1", event_type: "click", created_at: DateTime.utc_now()},
        %{id: "2", event_type: "view", created_at: DateTime.utc_now()}
      ])

      # Query data
      {:ok, rows} = MyApp.BigQueryRepo.query("SELECT * FROM analytics.events LIMIT 10")

  ## Modules

  - `Raggio.BigQuery.HTTPClient` - HTTP transport behaviour
  - `Raggio.BigQuery.Auth` - Authentication behaviour
  - `Raggio.BigQuery.Repo` - Repository behaviour (main interface)
  - `Raggio.BigQuery.Table` - Table definition behaviour
  - `Raggio.BigQuery.API` - Low-level BigQuery REST API wrapper
  - `Raggio.BigQuery.Telemetry` - Telemetry instrumentation
  - `Raggio.BigQuery.Retry` - Exponential backoff for rate limits

  ## Telemetry Events

  All events are prefixed with `[:raggio, :bigquery, ...]`:

  - `[:raggio, :bigquery, :request, :start | :stop | :exception]` - HTTP requests
  - `[:raggio, :bigquery, :insert, :start | :stop | :exception]` - Insert operations
  - `[:raggio, :bigquery, :merge, :start | :stop | :exception]` - Merge operations
  - `[:raggio, :bigquery, :query, :start | :stop | :exception]` - Query operations
  - `[:raggio, :bigquery, :repo, :*, :start | :stop | :exception]` - Repo operations
  - `[:raggio, :bigquery, :retry]` - Retry attempts
  """

  defdelegate span(event, metadata, fun), to: Raggio.BigQuery.Telemetry
  defdelegate emit(event, measurements \\ %{}, metadata \\ %{}), to: Raggio.BigQuery.Telemetry
end
