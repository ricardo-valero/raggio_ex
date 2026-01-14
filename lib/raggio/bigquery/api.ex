defmodule Raggio.BigQuery.API do
  @moduledoc """
  BigQuery REST API wrapper.

  This module wraps the BigQuery REST API using pluggable HTTPClient and Auth
  behaviours, enabling users to bring their own HTTP client and authentication.

  ## Configuration

  All functions accept a `config` map with:
  - `:project_id` - GCP project ID (required)
  - `:http_client` - Module implementing `Raggio.BigQuery.HTTPClient` (required)
  - `:auth` - Module implementing `Raggio.BigQuery.Auth` (required)
  - `:auth_config` - Config passed to Auth.get_token/1 (optional, defaults to %{})
  - `:timeout` - HTTP timeout in ms (optional, default 30_000)

  ## Batch Sizes

  - Insert: 5000 rows (BigQuery streaming has 10MB/request limit)
  - Merge: 1000 rows (MERGE queries are more complex)

  ## Usage

      config = %{
        project_id: "my-project",
        http_client: MyApp.ReqHTTPClient,
        auth: MyApp.GothAuth,
        auth_config: %{goth_name: MyApp.Goth}
      }

      {:ok, dataset} = Raggio.BigQuery.API.get_dataset(config, "my_dataset")
  """

  alias Raggio.BigQuery.{Telemetry, Retry}

  require Logger

  @bigquery_base_url "https://bigquery.googleapis.com/bigquery/v2"
  @default_batch_size 5000
  @default_merge_batch_size 1000

  @type config :: %{
          required(:project_id) => String.t(),
          required(:http_client) => module(),
          required(:auth) => module(),
          optional(:auth_config) => map(),
          optional(:timeout) => non_neg_integer()
        }

  @type api_result(t) :: {:ok, t} | {:error, error_reason()}
  @type error_reason ::
          :authentication_failed
          | :permission_denied
          | :not_found
          | :rate_limit_exceeded
          | {:http_error, non_neg_integer(), binary()}
          | {:missing_config, list(atom())}
          | term()

  @doc """
  Get dataset metadata to verify connectivity.
  """
  @spec get_dataset(config(), String.t()) :: api_result(map())
  def get_dataset(config, dataset) do
    with {:ok, validated} <- validate_config(config) do
      url = "#{@bigquery_base_url}/projects/#{validated.project_id}/datasets/#{dataset}"

      Telemetry.span([:request], %{method: :get, resource: :dataset}, fn ->
        Retry.with_retry(fn ->
          do_get(validated, url)
        end)
      end)
    end
  end

  @doc """
  Get table metadata including schema.
  """
  @spec get_table(config(), String.t(), String.t()) :: api_result(map())
  def get_table(config, dataset, table) do
    with {:ok, validated} <- validate_config(config) do
      url =
        "#{@bigquery_base_url}/projects/#{validated.project_id}/datasets/#{dataset}/tables/#{table}"

      Telemetry.span([:request], %{method: :get, resource: :table}, fn ->
        Retry.with_retry(fn ->
          do_get(validated, url)
        end)
      end)
    end
  end

  @doc """
  Create a new table with the given schema.
  """
  @spec create_table(config(), String.t(), String.t(), map()) :: api_result(map())
  def create_table(config, dataset, table_name, table_resource) do
    with {:ok, validated} <- validate_config(config) do
      url = "#{@bigquery_base_url}/projects/#{validated.project_id}/datasets/#{dataset}/tables"

      body =
        table_resource
        |> Map.put("tableReference", %{
          "projectId" => validated.project_id,
          "datasetId" => dataset,
          "tableId" => table_name
        })

      Telemetry.span([:request], %{method: :post, resource: :table}, fn ->
        Retry.with_retry(fn ->
          do_post(validated, url, body)
        end)
      end)
    end
  end

  @doc """
  Update table schema (PATCH - adds fields, cannot remove).
  """
  @spec patch_table(config(), String.t(), String.t(), map()) :: api_result(map())
  def patch_table(config, dataset, table, table_resource) do
    with {:ok, validated} <- validate_config(config) do
      url =
        "#{@bigquery_base_url}/projects/#{validated.project_id}/datasets/#{dataset}/tables/#{table}"

      Telemetry.span([:request], %{method: :patch, resource: :table}, fn ->
        Retry.with_retry(fn ->
          do_patch(validated, url, table_resource)
        end)
      end)
    end
  end

  @doc """
  Insert rows using BigQuery streaming insert.

  Accepts pre-formatted rows where each row is a map with:
  - `"insertId"` - Unique identifier for idempotency
  - `"json"` - Map of column name to value

  ## Options
  - `:batch_size` - Rows per batch (default: 5000)
  - `:skip_invalid_rows` - Skip rows with errors (default: false)
  """
  @spec insert_all(config(), String.t(), String.t(), [map()], keyword()) ::
          api_result(non_neg_integer())
  def insert_all(_config, _dataset, _table, [], _opts), do: {:error, :no_records}

  def insert_all(config, dataset, table, rows, opts) when is_list(rows) do
    with {:ok, validated} <- validate_config(config) do
      batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
      skip_invalid = Keyword.get(opts, :skip_invalid_rows, false)

      Telemetry.span([:insert], %{dataset: dataset, table: table, row_count: length(rows)}, fn ->
        insert_in_batches(validated, dataset, table, rows, batch_size, skip_invalid)
      end)
    end
  end

  defp insert_in_batches(config, dataset, table, rows, batch_size, skip_invalid) do
    total_records = length(rows)
    batches = Enum.chunk_every(rows, batch_size)
    total_batches = length(batches)

    Logger.info(
      "[Raggio.BigQuery.API] Inserting #{total_records} records in #{total_batches} batches"
    )

    results =
      batches
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, 0}, fn {batch, batch_num}, {:ok, acc} ->
        Logger.debug(
          "[Raggio.BigQuery.API] Processing batch #{batch_num}/#{total_batches} (#{length(batch)} records)"
        )

        case insert_single_batch(config, dataset, table, batch, skip_invalid) do
          {:ok, count} -> {:cont, {:ok, acc + count}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case results do
      {:ok, total_inserted} ->
        Logger.info("[Raggio.BigQuery.API] Successfully inserted #{total_inserted} total records")
        {:ok, total_inserted}

      error ->
        error
    end
  end

  defp insert_single_batch(config, dataset, table, batch, skip_invalid) do
    url =
      "#{@bigquery_base_url}/projects/#{config.project_id}/datasets/#{dataset}/tables/#{table}/insertAll"

    body = %{
      "rows" => batch,
      "skipInvalidRows" => skip_invalid,
      "ignoreUnknownValues" => false
    }

    Retry.with_retry(fn ->
      case do_post(config, url, body) do
        {:ok, %{"insertErrors" => errors}} when errors != [] ->
          Logger.error("[Raggio.BigQuery.API] Insert errors: #{inspect(errors)}")
          {:error, {:insert_errors, errors}}

        {:ok, _response} ->
          {:ok, length(batch)}

        {:error, _} = error ->
          error
      end
    end)
  end

  @doc """
  Execute a query and return results.

  ## Parameters
  - `query_string` - SQL query (Standard SQL)
  - `params` - List of {name, value} tuples for named parameters

  ## Returns
  - `{:ok, [map()]}` - List of result rows as maps
  """
  @spec query(config(), String.t(), [{String.t(), String.t()}]) :: api_result([map()])
  def query(config, query_string, params \\ []) do
    with {:ok, validated} <- validate_config(config) do
      Telemetry.span([:query], %{query: truncate_query(query_string)}, fn ->
        Retry.with_retry(fn ->
          run_query(validated, query_string, params)
        end)
      end)
    end
  end

  defp run_query(config, query_string, params) do
    url = "#{@bigquery_base_url}/projects/#{config.project_id}/queries"

    query_params =
      Enum.map(params, fn {name, value} ->
        %{
          "name" => name,
          "parameterType" => %{"type" => "STRING"},
          "parameterValue" => %{"value" => value}
        }
      end)

    body = %{
      "query" => query_string,
      "useLegacySql" => false,
      "parameterMode" => "NAMED",
      "queryParameters" => query_params
    }

    case do_post(config, url, body) do
      {:ok, %{"rows" => rows, "schema" => %{"fields" => fields}}} ->
        field_names = Enum.map(fields, & &1["name"])
        parsed_rows = Enum.map(rows, &parse_row(&1, field_names))
        {:ok, parsed_rows}

      {:ok, %{"schema" => _}} ->
        {:ok, []}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  defp parse_row(%{"f" => fields}, field_names) do
    fields
    |> Enum.zip(field_names)
    |> Enum.into(%{}, fn {%{"v" => value}, name} -> {name, value} end)
  end

  defp truncate_query(query) when byte_size(query) > 100 do
    String.slice(query, 0, 100) <> "..."
  end

  defp truncate_query(query), do: query

  @doc """
  Create and run a query job (for long-running queries or DDL).
  """
  @spec run_job(config(), map()) :: api_result(map())
  def run_job(config, job_config) do
    with {:ok, validated} <- validate_config(config) do
      url = "#{@bigquery_base_url}/projects/#{validated.project_id}/jobs"

      Telemetry.span([:request], %{method: :post, resource: :job}, fn ->
        Retry.with_retry(fn ->
          do_post(validated, url, job_config)
        end)
      end)
    end
  end

  @doc """
  Get job status.
  """
  @spec get_job(config(), String.t()) :: api_result(map())
  def get_job(config, job_id) do
    with {:ok, validated} <- validate_config(config) do
      url = "#{@bigquery_base_url}/projects/#{validated.project_id}/jobs/#{job_id}"

      Telemetry.span([:request], %{method: :get, resource: :job}, fn ->
        Retry.with_retry(fn ->
          do_get(validated, url)
        end)
      end)
    end
  end

  @doc """
  Upsert rows using MERGE statement for true idempotency.

  Unlike streaming inserts (which only deduplicate within ~1 minute),
  MERGE provides guaranteed idempotency by checking the target table
  before inserting.

  ## Parameters
  - `rows` - List of maps representing row data (column name -> value)
  - `key_field` - The field to use as the unique key for matching

  ## Options
  - `:batch_size` - Rows per batch (default: 1000)
  """
  @spec merge(config(), String.t(), String.t(), [map()], String.t(), keyword()) ::
          api_result(non_neg_integer())
  def merge(config, dataset, table, rows, key_field, opts \\ [])
  def merge(_config, _dataset, _table, [], _key_field, _opts), do: {:ok, 0}

  def merge(config, dataset, table, rows, key_field, opts) when is_list(rows) do
    with {:ok, validated} <- validate_config(config) do
      batch_size = Keyword.get(opts, :batch_size, @default_merge_batch_size)

      Telemetry.span([:merge], %{dataset: dataset, table: table, row_count: length(rows)}, fn ->
        merge_in_batches(validated, dataset, table, rows, key_field, batch_size)
      end)
    end
  end

  defp merge_in_batches(config, dataset, table, rows, key_field, batch_size) do
    total_records = length(rows)
    batches = Enum.chunk_every(rows, batch_size)
    total_batches = length(batches)

    Logger.info(
      "[Raggio.BigQuery.API] Merging #{total_records} records in #{total_batches} batches"
    )

    results =
      batches
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, 0}, fn {batch, batch_num}, {:ok, acc} ->
        Logger.debug(
          "[Raggio.BigQuery.API] Processing merge batch #{batch_num}/#{total_batches} (#{length(batch)} records)"
        )

        case merge_single_batch(config, dataset, table, batch, key_field) do
          {:ok, count} -> {:cont, {:ok, acc + count}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case results do
      {:ok, total} ->
        Logger.info("[Raggio.BigQuery.API] Successfully merged #{total} total records")
        {:ok, total}

      error ->
        error
    end
  end

  defp merge_single_batch(config, dataset, table, rows, key_field) do
    columns = rows |> List.first() |> Map.keys() |> Enum.sort()

    source_rows = build_merge_source_rows(rows, columns)
    column_list = Enum.join(columns, ", ")
    update_set = build_update_set(columns, key_field)
    insert_values = Enum.map_join(columns, ", ", &"source.#{&1}")

    query = """
    MERGE `#{config.project_id}.#{dataset}.#{table}` AS target
    USING (#{source_rows}) AS source
    ON target.#{key_field} = source.#{key_field}
    WHEN MATCHED THEN
      UPDATE SET #{update_set}
    WHEN NOT MATCHED THEN
      INSERT (#{column_list})
      VALUES (#{insert_values})
    """

    Retry.with_retry(fn ->
      case run_query(config, query, []) do
        {:ok, _rows} ->
          {:ok, length(rows)}

        {:error, _} = error ->
          error
      end
    end)
  end

  defp build_merge_source_rows(rows, columns) do
    values =
      Enum.map_join(rows, ",\n    ", fn row ->
        column_values =
          Enum.map_join(columns, ", ", fn col ->
            format_value_for_merge(Map.get(row, col))
          end)

        "STRUCT(#{column_values})"
      end)

    column_aliases = Enum.join(columns, ", ")

    "SELECT #{column_aliases} FROM UNNEST([#{values}])"
  end

  defp format_value_for_merge(nil), do: "NULL"
  defp format_value_for_merge(value) when is_binary(value), do: "'#{escape_string(value)}'"
  defp format_value_for_merge(value) when is_integer(value), do: Integer.to_string(value)
  defp format_value_for_merge(value) when is_float(value), do: Float.to_string(value)
  defp format_value_for_merge(true), do: "TRUE"
  defp format_value_for_merge(false), do: "FALSE"

  defp format_value_for_merge(%Decimal{} = value) do
    Decimal.to_string(value)
  end

  defp format_value_for_merge(%DateTime{} = dt) do
    "TIMESTAMP '#{DateTime.to_iso8601(dt)}'"
  end

  defp format_value_for_merge(%Date{} = d) do
    "DATE '#{Date.to_iso8601(d)}'"
  end

  defp format_value_for_merge(value), do: "'#{escape_string(inspect(value))}'"

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp build_update_set(columns, key_field) do
    columns
    |> Enum.reject(&(&1 == key_field))
    |> Enum.map_join(", ", &"#{&1} = source.#{&1}")
  end

  defp validate_config(config) do
    required = [:project_id, :http_client, :auth]
    missing = Enum.filter(required, &(not Map.has_key?(config, &1)))

    if missing != [] do
      {:error, {:missing_config, missing}}
    else
      {:ok, config}
    end
  end

  defp get_token(config) do
    auth_config = Map.get(config, :auth_config, %{})
    config.auth.get_token(auth_config)
  end

  defp do_get(config, url) do
    with {:ok, token} <- get_token(config) do
      headers = build_headers(token)
      opts = [timeout: Map.get(config, :timeout, 30_000)]

      case config.http_client.request(:get, url, headers, nil, opts) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, Jason.decode!(body)}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: 401}} ->
          {:error, :authentication_failed}

        {:ok, %{status: 403}} ->
          {:error, :permission_denied}

        {:ok, %{status: 429, body: body}} ->
          {:error, {:http_error, 429, body}}

        {:ok, %{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_post(config, url, body) do
    with {:ok, token} <- get_token(config) do
      headers = build_headers(token)
      opts = [timeout: Map.get(config, :timeout, 30_000)]
      encoded_body = Jason.encode!(body)

      case config.http_client.request(:post, url, headers, encoded_body, opts) do
        {:ok, %{status: status, body: resp_body}} when status in [200, 201] ->
          {:ok, Jason.decode!(resp_body)}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: 401}} ->
          {:error, :authentication_failed}

        {:ok, %{status: 403}} ->
          {:error, :permission_denied}

        {:ok, %{status: 429, body: resp_body}} ->
          {:error, {:http_error, 429, resp_body}}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, {:http_error, status, resp_body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_patch(config, url, body) do
    with {:ok, token} <- get_token(config) do
      headers = build_headers(token)
      opts = [timeout: Map.get(config, :timeout, 30_000)]
      encoded_body = Jason.encode!(body)

      case config.http_client.request(:patch, url, headers, encoded_body, opts) do
        {:ok, %{status: 200, body: resp_body}} ->
          {:ok, Jason.decode!(resp_body)}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: 401}} ->
          {:error, :authentication_failed}

        {:ok, %{status: 403}} ->
          {:error, :permission_denied}

        {:ok, %{status: 429, body: resp_body}} ->
          {:error, {:http_error, 429, resp_body}}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, {:http_error, status, resp_body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end
end
