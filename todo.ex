defmodule Manuable.Adapters.BigQueryAdapter do
  @moduledoc """
  **DEPRECATED**: Use `BigQueryKit.Adapter` instead.

  This module is deprecated and will be removed in a future release.
  Please migrate to `BigQueryKit.Adapter` for all BigQuery operations.

  ---

  Domain-agnostic BigQuery adapter.

  Uses the BigQuery REST API directly via HTTPoison to avoid
  dependency conflicts with the google_api_big_query library.

  This adapter is agnostic of domain logic - it accepts plain maps
  and handles only BigQuery-specific concerns (batching, streaming inserts,
  authentication, error handling).

  ## Authentication

  Uses `Manuable.Adapters.GCPCredentials` for centralized credential management.
  ## Required Parameters

  All functions require `opts` map with:
  - `:dataset` - BigQuery dataset name (required)
  - `:table` - BigQuery table name (required)
  - `:project_id` - GCP project ID (optional, defaults to extracted from credentials)
  """

  @behaviour Manuable.Adapters.BigQueryBehaviour

  alias Manuable.Adapters.GCPCredentials

  require Logger

  @bigquery_base_url "https://bigquery.googleapis.com/bigquery/v2"

  # BigQuery streaming insert has a 10MB limit per request
  # 5000 records is a safe batch size to stay under the limit
  @batch_size 5000

  @doc """
  Inserts rows into BigQuery using streaming insert.

  Accepts pre-formatted rows where each row is a map with:
  - `"insertId"` - Unique identifier for idempotency
  - `"json"` - Map of column name to value

  If there are more than #{@batch_size} rows, they are inserted in batches
  to avoid the 10MB request size limit.
  """
  @impl true
  @spec insert([map()], map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def insert([], _opts), do: {:error, :no_records}

  def insert(rows, opts) when is_list(rows) do
    with {:ok, config} <- validate_config(opts),
         {:ok, token} <- get_access_token() do
      insert_in_batches(rows, config, token)
    end
  end

  # Insert rows in batches to avoid BigQuery's 10MB request limit
  defp insert_in_batches(rows, config, token) do
    total_records = length(rows)
    batches = Enum.chunk_every(rows, @batch_size)
    total_batches = length(batches)

    Logger.info(
      "[BigQueryAdapter] Inserting #{total_records} records in #{total_batches} batches"
    )

    results =
      batches
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, 0}, fn {batch, batch_num}, {:ok, acc} ->
        Logger.debug(
          "[BigQueryAdapter] Processing batch #{batch_num}/#{total_batches} (#{length(batch)} records)"
        )

        case insert_single_batch(batch, config, token) do
          {:ok, count} -> {:cont, {:ok, acc + count}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    handle_batch_results(results)
  end

  defp insert_single_batch(batch, config, token) do
    request_body = build_insert_request(batch)

    case do_streaming_insert(config, token, request_body) do
      {:ok, response} -> handle_insert_response(response, length(batch))
      {:error, _} = error -> error
    end
  end

  defp handle_batch_results({:ok, total_inserted}) do
    Logger.info("[BigQueryAdapter] Successfully inserted #{total_inserted} total records")
    {:ok, total_inserted}
  end

  defp handle_batch_results({:error, _} = error), do: error

  @doc """
  Checks if records already exist (idempotency check).

  ## Parameters
  - `filters` - Map of field names to values for WHERE clause
  - `return_field` - Field name to return
  - `opts` - Options map containing project, dataset, table

  ## Examples

      # Check existing by file_hash, return row_numbers
      check_existing(%{"file_hash" => "abc123"}, "row_number", opts)

      # Check existing by provider and tracking
      check_existing(%{"provider" => "t1", "tracking" => "12345"}, "id", opts)
  """
  @impl true
  @spec check_existing(map(), String.t(), map()) :: {:ok, [any()]} | {:error, term()}
  def check_existing(filters, return_field, opts)
      when is_map(filters) and map_size(filters) > 0 do
    with {:ok, config} <- validate_config(opts),
         {:ok, token} <- get_access_token() do
      {where_clause, params} = build_where_clause(filters)

      query = """
      SELECT #{return_field}
      FROM `#{config.project_id}.#{config.dataset}.#{config.table}`
      WHERE #{where_clause}
      """

      case run_query(config, token, query, params) do
        {:ok, %{"rows" => rows}} ->
          values =
            Enum.map(rows, fn %{"f" => [%{"v" => v}]} ->
              parse_value(v, return_field)
            end)

          {:ok, values}

        {:ok, _} ->
          {:ok, []}

        {:error, _} = error ->
          error
      end
    end
  end

  def check_existing(_filters, _return_field, _opts), do: {:error, :invalid_filters}

  # Builds WHERE clause and params from filters map
  defp build_where_clause(filters) do
    {clauses, params} =
      filters
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{field, value}, _idx}, {clauses_acc, params_acc} ->
        param_name = field
        clause = "#{field} = @#{param_name}"
        {[clause | clauses_acc], [{param_name, to_string(value)} | params_acc]}
      end)

    where_clause = clauses |> Enum.reverse() |> Enum.join(" AND ")
    params = Enum.reverse(params)

    {where_clause, params}
  end

  # Parse value based on common field types
  defp parse_value(nil, _field), do: nil

  defp parse_value(value, field) when field in ["row_number", "id", "count"] do
    String.to_integer(value)
  end

  defp parse_value(value, _field), do: value

  @doc """
  Gets the connection status.
  """
  @impl true
  @spec status(map()) :: :connected | {:error, term()}
  def status(opts) do
    with {:ok, config} <- validate_config(opts),
         {:ok, token} <- get_access_token() do
      url = "#{@bigquery_base_url}/projects/#{config.project_id}/datasets/#{config.dataset}"

      case http_get(url, token) do
        {:ok, %{status: 200}} -> :connected
        {:ok, %{status: status}} -> {:error, {:http_error, status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Executes a query and returns the results.

  ## Parameters
  - `query` - SQL query string (Standard SQL, not Legacy SQL)
  - `params` - List of {name, value} tuples for parameterized queries
  - `opts` - Options map containing:
    - `:dataset` - BigQuery dataset name
    - `:table` - BigQuery table name (optional)

  ## Returns
  - `{:ok, [map()]}` - List of result rows as maps
  - `{:error, term()}` - Query failed

  ## Examples

      # Query failed files
      query = "SELECT * FROM `project.dataset.s3_file` WHERE status = @status"
      query(query, [{"status", "failed"}], opts)
  """
  @impl true
  @spec query(String.t(), [{String.t(), String.t()}], map()) :: {:ok, [map()]} | {:error, term()}
  def query(query_string, params, opts) do
    with {:ok, config} <- validate_config(opts),
         {:ok, token} <- get_access_token() do
      case run_query(config, token, query_string, params) do
        {:ok, %{"rows" => rows, "schema" => %{"fields" => fields}}} ->
          field_names = Enum.map(fields, & &1["name"])
          parsed_rows = Enum.map(rows, &parse_row(&1, field_names))
          {:ok, parsed_rows}

        {:ok, %{"schema" => _}} ->
          # Query returned no rows
          {:ok, []}

        {:ok, _} ->
          {:ok, []}

        {:error, _} = error ->
          error
      end
    end
  end

  # Parses a single BigQuery row into a map
  defp parse_row(%{"f" => fields}, field_names) do
    fields
    |> Enum.zip(field_names)
    |> Enum.into(%{}, fn {%{"v" => value}, name} -> {name, value} end)
  end

  # Builds the streaming insert request body from pre-formatted rows
  defp build_insert_request(rows) do
    %{
      "rows" => rows,
      "skipInvalidRows" => false,
      "ignoreUnknownValues" => false
    }
  end

  defp validate_config(opts) do
    dataset = Map.get(opts, :dataset)
    table = Map.get(opts, :table)

    # dataset and table are required parameters
    if is_nil(dataset) or is_nil(table) do
      {:error, {:missing_required_params, [:dataset, :table]}}
    else
      # project_id can be passed explicitly or derived from credentials
      case Map.get(opts, :project_id) || GCPCredentials.project_id() do
        {:ok, project_id} ->
          {:ok, %{project_id: project_id, dataset: dataset, table: table}}

        {:error, _} = error ->
          error

        project_id when is_binary(project_id) ->
          {:ok, %{project_id: project_id, dataset: dataset, table: table}}
      end
    end
  end

  defp get_access_token do
    GCPCredentials.get_token()
  end

  defp do_streaming_insert(config, token, request_body) do
    url =
      "#{@bigquery_base_url}/projects/#{config.project_id}/datasets/#{config.dataset}/tables/#{config.table}/insertAll"

    body = Jason.encode!(request_body)

    case http_post(url, token, body) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[BigQueryAdapter] Insert failed: status=#{status} body=#{body}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("[BigQueryAdapter] Insert request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_insert_response(%{"insertErrors" => errors}, _count) when errors != [] do
    Logger.error("[BigQueryAdapter] Insert errors: #{inspect(errors)}")
    {:error, {:insert_errors, errors}}
  end

  defp handle_insert_response(_response, count) do
    Logger.info("[BigQueryAdapter] Successfully inserted #{count} records")
    {:ok, count}
  end

  defp run_query(config, token, query, params) do
    url = "#{@bigquery_base_url}/projects/#{config.project_id}/queries"

    query_params =
      Enum.map(params, fn {name, value} ->
        %{
          "name" => name,
          "parameterType" => %{"type" => "STRING"},
          "parameterValue" => %{"value" => value}
        }
      end)

    body =
      Jason.encode!(%{
        "query" => query,
        "useLegacySql" => false,
        "parameterMode" => "NAMED",
        "queryParameters" => query_params
      })

    case http_post(url, token, body) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp http_get(url, token) do
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp http_post(url, token, body) do
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Upserts rows into BigQuery using MERGE statement for true idempotency.

  Unlike streaming inserts (which only deduplicate within ~1 minute),
  MERGE provides guaranteed idempotency by checking the target table
  before inserting.

  Processes rows in batches to handle large datasets.
  """
  @impl true
  @spec merge([map()], String.t(), map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def merge([], _key_field, _opts), do: {:ok, 0}

  def merge(rows, key_field, opts) when is_list(rows) do
    with {:ok, config} <- validate_config(opts),
         {:ok, token} <- get_access_token() do
      merge_in_batches(rows, key_field, config, token)
    end
  end

  # Process merge in batches (smaller than insert due to query complexity)
  @merge_batch_size 1000
  defp merge_in_batches(rows, key_field, config, token) do
    total_records = length(rows)
    batches = Enum.chunk_every(rows, @merge_batch_size)
    total_batches = length(batches)

    Logger.info("[BigQueryAdapter] Merging #{total_records} records in #{total_batches} batches")

    results =
      batches
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, 0}, fn {batch, batch_num}, {:ok, acc} ->
        Logger.debug(
          "[BigQueryAdapter] Processing merge batch #{batch_num}/#{total_batches} (#{length(batch)} records)"
        )

        case merge_single_batch(batch, key_field, config, token) do
          {:ok, count} -> {:cont, {:ok, acc + count}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case results do
      {:ok, total} ->
        Logger.info("[BigQueryAdapter] Successfully merged #{total} total records")
        {:ok, total}

      error ->
        error
    end
  end

  defp merge_single_batch(rows, key_field, config, token) do
    # Get all column names from the first row
    columns = rows |> List.first() |> Map.keys() |> Enum.sort()

    # Build the MERGE query with UNNEST for the source data
    source_rows = build_merge_source_rows(rows, columns)
    column_list = Enum.join(columns, ", ")
    update_set = build_update_set(columns, key_field)
    insert_values = Enum.map(columns, &"source.#{&1}") |> Enum.join(", ")

    query = """
    MERGE `#{config.project_id}.#{config.dataset}.#{config.table}` AS target
    USING (#{source_rows}) AS source
    ON target.#{key_field} = source.#{key_field}
    WHEN MATCHED THEN
      UPDATE SET #{update_set}
    WHEN NOT MATCHED THEN
      INSERT (#{column_list})
      VALUES (#{insert_values})
    """

    case run_query(config, token, query, []) do
      {:ok, response} ->
        # BigQuery returns numDmlAffectedRows for DML statements
        affected = get_in(response, ["numDmlAffectedRows"]) || "0"
        {:ok, String.to_integer(affected)}

      {:error, _} = error ->
        error
    end
  end

  # Build source rows as a SELECT with UNNEST for array of structs
  defp build_merge_source_rows(rows, columns) do
    values =
      rows
      |> Enum.map(fn row ->
        column_values =
          columns
          |> Enum.map(fn col -> format_value_for_merge(Map.get(row, col)) end)
          |> Enum.join(", ")

        "STRUCT(#{column_values})"
      end)
      |> Enum.join(",\n    ")

    column_aliases =
      columns
      |> Enum.map(&"#{&1}")
      |> Enum.join(", ")

    "SELECT #{column_aliases} FROM UNNEST([#{values}])"
  end

  # Format value for MERGE query
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

  # Build UPDATE SET clause, excluding the key field
  defp build_update_set(columns, key_field) do
    columns
    |> Enum.reject(&(&1 == key_field))
    |> Enum.map(&"#{&1} = source.#{&1}")
    |> Enum.join(", ")
  end
end
