defmodule Raggio.BigQuery.Repo do
  @moduledoc """
  Behaviour for BigQuery repository modules.

  A Repo provides an Ecto-like interface for BigQuery operations, handling
  connection management, credential configuration, and data operations.

  ## Usage

  Define a repo module:

      defmodule MyApp.BigQueryRepo do
        use Raggio.BigQuery.Repo, otp_app: :my_app

        @impl true
        def config do
          %{
            project_id: Application.get_env(:my_app, :gcp_project_id),
            http_client: MyApp.ReqHTTPClient,
            auth: MyApp.GothAuth,
            auth_config: %{goth_name: MyApp.Goth},
            default_dataset: "billing"
          }
        end
      end

  ## Required Configuration

  The `config/0` callback must return a map with:
  - `:project_id` - GCP project ID
  - `:http_client` - Module implementing `Raggio.BigQuery.HTTPClient`
  - `:auth` - Module implementing `Raggio.BigQuery.Auth`

  ## Optional Configuration

  - `:auth_config` - Config passed to Auth.get_token/1
  - `:default_dataset` - Default dataset for operations
  - `:timeout` - HTTP timeout in milliseconds

  ## Generated Functions

  Using this module generates:
  - `status/0` - Verifies connectivity to BigQuery
  - `get_table_schema/2` - Retrieves table schema
  - `insert/2`, `insert/3` - Inserts rows into a table
  - `merge/3` - Upserts rows using MERGE
  - `query/1`, `query/2` - Executes SQL queries
  """

  alias Raggio.BigQuery.{API, Telemetry}

  @callback config() :: map()

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      @behaviour Raggio.BigQuery.Repo

      @otp_app unquote(otp_app)

      alias Raggio.BigQuery.{API, Telemetry}

      @doc """
      Verifies connectivity to BigQuery.

      Returns `:connected` on success, `{:error, reason}` on failure.
      """
      @spec status() :: :connected | {:error, term()}
      def status do
        Telemetry.span([:repo, :status], %{repo: __MODULE__}, fn ->
          cfg = config()
          dataset = Map.get(cfg, :default_dataset, "_default")

          case API.get_dataset(cfg, dataset) do
            {:ok, _} -> :connected
            {:error, :not_found} -> :connected
            {:error, _} = error -> error
          end
        end)
      end

      @doc """
      Retrieves the schema of a BigQuery table.
      """
      @spec get_table_schema(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
      def get_table_schema(dataset, table) do
        API.get_table(config(), dataset, table)
      end

      @doc """
      Inserts rows into a BigQuery table.

      The `table_module` must implement `Raggio.BigQuery.Table`.
      """
      @spec insert(module(), [map()]) :: {:ok, non_neg_integer()} | {:error, term()}
      def insert(table_module, rows) do
        insert(table_module, rows, [])
      end

      @doc """
      Inserts rows with options.

      ## Options
      - `:batch_size` - Rows per batch (default: 5000)
      - `:skip_invalid_rows` - Skip rows with errors (default: false)
      """
      @spec insert(module(), [map()], keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
      def insert(table_module, rows, opts) when is_list(rows) do
        Telemetry.span([:repo, :insert], %{repo: __MODULE__, table: table_module}, fn ->
          cfg = config()
          dataset = table_module.__dataset__()
          table = table_module.__table__()

          formatted_rows = Enum.map(rows, &format_row/1)

          API.insert_all(cfg, dataset, table, formatted_rows, opts)
        end)
      end

      @doc """
      Upserts rows using BigQuery MERGE statement.

      ## Options
      - `:key` - Field to match on for upsert (required)
      - `:batch_size` - Rows per batch (default: 1000)
      """
      @spec merge(module(), [map()], keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
      def merge(table_module, rows, opts) when is_list(rows) do
        Telemetry.span([:repo, :merge], %{repo: __MODULE__, table: table_module}, fn ->
          key_field = Keyword.fetch!(opts, :key) |> to_string()
          cfg = config()
          dataset = table_module.__dataset__()
          table = table_module.__table__()

          merge_opts = Keyword.delete(opts, :key)

          API.merge(cfg, dataset, table, rows, key_field, merge_opts)
        end)
      end

      @doc """
      Executes a SQL query.
      """
      @spec query(String.t()) :: {:ok, [map()]} | {:error, term()}
      def query(sql) do
        query(sql, [])
      end

      @doc """
      Executes a parameterized SQL query.

      ## Parameters
      - `sql` - Standard SQL query string with @param placeholders
      - `params` - Keyword list of parameter values

      ## Example
          query("SELECT * FROM table WHERE status = @status", status: "active")
      """
      @spec query(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
      def query(sql, params) when is_binary(sql) do
        Telemetry.span([:repo, :query], %{repo: __MODULE__}, fn ->
          formatted_params =
            Enum.map(params, fn {k, v} ->
              {to_string(k), to_string(v)}
            end)

          API.query(config(), sql, formatted_params)
        end)
      end

      defp format_row(data) do
        id = Map.get(data, :id) || Map.get(data, "id") || generate_insert_id()

        %{
          "insertId" => to_string(id),
          "json" => stringify_map(data)
        }
      end

      defp generate_insert_id do
        :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      end

      defp stringify_map(map) when is_map(map) do
        Map.new(map, fn
          {k, v} when is_atom(k) -> {Atom.to_string(k), format_value(v)}
          {k, v} -> {k, format_value(v)}
        end)
      end

      defp format_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
      defp format_value(%Date{} = d), do: Date.to_iso8601(d)
      defp format_value(%Decimal{} = d), do: Decimal.to_string(d)
      defp format_value(v) when is_map(v), do: stringify_map(v)
      defp format_value(v) when is_list(v), do: Enum.map(v, &format_value/1)
      defp format_value(v), do: v
    end
  end
end
