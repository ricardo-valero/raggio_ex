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

  3. Define tables (Traditional approach):

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

  3. Define schemas (Composable API - Drizzle-style):

      import Raggio.BigQuery.Composer
      alias Raggio.Schema

      project("my-analytics-project")
      |> dataset("analytics", location: "US")
      |> table("events", [
        column(:id, Schema.string() |> required()),
        column(:event_type, Schema.string() |> required()),
        column(:payload, Schema.string()),
        column(:created_at, Schema.datetime() |> required())
      ],
        partition_by: {:field, :created_at, :day},
        cluster_by: [:event_type]
      )
      |> build!()

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

  ### Core API
  - `Raggio.BigQuery.HTTPClient` - HTTP transport behaviour
  - `Raggio.BigQuery.Auth` - Authentication behaviour
  - `Raggio.BigQuery.Repo` - Repository behaviour (main interface)
  - `Raggio.BigQuery.Table` - Table definition behaviour
  - `Raggio.BigQuery.API` - Low-level BigQuery REST API wrapper
  - `Raggio.BigQuery.Telemetry` - Telemetry instrumentation
  - `Raggio.BigQuery.Retry` - Exponential backoff for rate limits

  ### Composable Schema API (Drizzle-style)
  - `Raggio.BigQuery.Composer` - Fluent builder API for project hierarchies
  - `Raggio.BigQuery.Project` - Project struct and operations
  - `Raggio.BigQuery.Dataset` - Dataset struct and operations
  - `Raggio.BigQuery.TableDef` - Table definition struct with DDL generation
  - `Raggio.BigQuery.Column` - Column definition struct
  - `Raggio.BigQuery.DDL.Parser` - Parse BigQuery DDL into schema definitions

  ### Schema Adapters
  - `Raggio.Schema.Adapter` - Adapter behaviour for bidirectional schema conversion
  - `Raggio.Schema.Adapters.BigQuery` - BigQuery adapter implementation

  ## Telemetry Events

  All events are prefixed with `[:raggio, :bigquery, ...]`:

  - `[:raggio, :bigquery, :request, :start | :stop | :exception]` - HTTP requests
  - `[:raggio, :bigquery, :insert, :start | :stop | :exception]` - Insert operations
  - `[:raggio, :bigquery, :merge, :start | :stop | :exception]` - Merge operations
  - `[:raggio, :bigquery, :query, :start | :stop | :exception]` - Query operations
  - `[:raggio, :bigquery, :repo, :*, :start | :stop | :exception]` - Repo operations
  - `[:raggio, :bigquery, :retry]` - Retry attempts
  """

  # Telemetry delegations
  defdelegate span(event, metadata, fun), to: Raggio.BigQuery.Telemetry
  defdelegate emit(event, measurements \\ %{}, metadata \\ %{}), to: Raggio.BigQuery.Telemetry

  # Composer API re-exports for convenience
  defdelegate project(project_id, opts \\ []), to: Raggio.BigQuery.Composer
  defdelegate from_modules(modules, project_id, opts \\ []), to: Raggio.BigQuery.Composer
end
