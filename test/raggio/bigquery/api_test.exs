defmodule Raggio.BigQuery.APITest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{API, MockHTTPClient, MockAuth}

  @valid_config %{
    project_id: "test-project",
    http_client: MockHTTPClient,
    auth: MockAuth
  }

  describe "config validation" do
    test "returns error when project_id is missing" do
      config = Map.delete(@valid_config, :project_id)
      result = API.get_dataset(config, "dataset")

      assert {:error, {:missing_config, [:project_id]}} = result
    end

    test "returns error when http_client is missing" do
      config = Map.delete(@valid_config, :http_client)
      result = API.get_dataset(config, "dataset")

      assert {:error, {:missing_config, [:http_client]}} = result
    end

    test "returns error when auth is missing" do
      config = Map.delete(@valid_config, :auth)
      result = API.get_dataset(config, "dataset")

      assert {:error, {:missing_config, [:auth]}} = result
    end

    test "returns error listing all missing fields" do
      result = API.get_dataset(%{}, "dataset")

      assert {:error, {:missing_config, missing}} = result
      assert :project_id in missing
      assert :http_client in missing
      assert :auth in missing
    end
  end

  describe "get_dataset/2" do
    test "returns dataset metadata on success" do
      result = API.get_dataset(@valid_config, "my_dataset")

      assert {:ok, data} = result
      assert data["kind"] == "bigquery#dataset"
    end
  end

  describe "get_table/3" do
    test "returns table metadata including schema" do
      result = API.get_table(@valid_config, "dataset", "table")

      assert {:ok, data} = result
      assert data["kind"] == "bigquery#table"
      assert data["schema"]["fields"]
    end
  end

  describe "insert_all/5" do
    test "returns error for empty rows" do
      result = API.insert_all(@valid_config, "ds", "tbl", [], [])
      assert {:error, :no_records} = result
    end

    test "inserts rows and returns count" do
      rows = [
        %{"insertId" => "1", "json" => %{"id" => "a", "name" => "Alice"}},
        %{"insertId" => "2", "json" => %{"id" => "b", "name" => "Bob"}}
      ]

      result = API.insert_all(@valid_config, "ds", "tbl", rows, [])

      assert {:ok, 2} = result
    end

    test "respects batch_size option" do
      rows =
        for i <- 1..5 do
          %{"insertId" => "#{i}", "json" => %{"id" => "#{i}"}}
        end

      result = API.insert_all(@valid_config, "ds", "tbl", rows, batch_size: 2)

      assert {:ok, 5} = result
    end
  end

  describe "query/3" do
    test "executes query and returns parsed results" do
      result = API.query(@valid_config, "SELECT COUNT(*) as count FROM table")

      assert {:ok, [row]} = result
      assert row["count"] == "42"
    end
  end

  describe "run_job/2" do
    test "creates and returns job" do
      job_config = %{
        "configuration" => %{
          "query" => %{
            "query" => "SELECT * FROM table",
            "useLegacySql" => false
          }
        }
      }

      result = API.run_job(@valid_config, job_config)

      assert {:ok, job} = result
      assert job["kind"] == "bigquery#job"
    end
  end

  describe "get_job/2" do
    test "returns job status" do
      result = API.get_job(@valid_config, "job-123")

      assert {:ok, job} = result
      assert job["kind"] == "bigquery#job"
    end
  end

  describe "merge/6" do
    test "returns {:ok, 0} for empty rows" do
      result = API.merge(@valid_config, "ds", "tbl", [], "id", [])
      assert {:ok, 0} = result
    end

    test "merges rows using key field" do
      rows = [
        %{"id" => "1", "name" => "Alice", "age" => 30},
        %{"id" => "2", "name" => "Bob", "age" => 25}
      ]

      result = API.merge(@valid_config, "ds", "tbl", rows, "id", [])

      assert {:ok, 2} = result
    end
  end

  describe "error handling" do
    test "returns :not_found for 404 responses" do
      defmodule NotFoundMock do
        @behaviour Raggio.BigQuery.HTTPClient

        @impl true
        def request(_method, _url, _headers, _body, _opts) do
          {:ok, %{status: 404, headers: [], body: ~s({"error": "not found"})}}
        end
      end

      config = %{@valid_config | http_client: NotFoundMock}
      result = API.get_dataset(config, "nonexistent")
      assert {:error, :not_found} = result
    end

    test "returns :authentication_failed for 401 responses" do
      defmodule UnauthorizedMock do
        @behaviour Raggio.BigQuery.HTTPClient

        @impl true
        def request(_method, _url, _headers, _body, _opts) do
          {:ok, %{status: 401, headers: [], body: ~s({"error": "unauthorized"})}}
        end
      end

      config = %{@valid_config | http_client: UnauthorizedMock}
      result = API.get_dataset(config, "dataset")
      assert {:error, :authentication_failed} = result
    end

    test "returns :permission_denied for 403 responses" do
      defmodule ForbiddenMock do
        @behaviour Raggio.BigQuery.HTTPClient

        @impl true
        def request(_method, _url, _headers, _body, _opts) do
          {:ok, %{status: 403, headers: [], body: ~s({"error": "forbidden"})}}
        end
      end

      config = %{@valid_config | http_client: ForbiddenMock}
      result = API.get_dataset(config, "dataset")
      assert {:error, :permission_denied} = result
    end

    test "returns auth error when auth fails" do
      defmodule FailingAuth do
        @behaviour Raggio.BigQuery.Auth

        @impl true
        def get_token(_config), do: {:error, :token_expired}
      end

      config = %{@valid_config | auth: FailingAuth}
      result = API.get_dataset(config, "dataset")
      assert {:error, :token_expired} = result
    end
  end

  describe "telemetry integration" do
    setup do
      test_pid = self()
      handler_id = "api-test-#{System.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [
          [:raggio, :bigquery, :request, :start],
          [:raggio, :bigquery, :request, :stop],
          [:raggio, :bigquery, :insert, :start],
          [:raggio, :bigquery, :insert, :stop],
          [:raggio, :bigquery, :query, :start],
          [:raggio, :bigquery, :query, :stop],
          [:raggio, :bigquery, :merge, :start],
          [:raggio, :bigquery, :merge, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      :ok
    end

    test "emits telemetry events for get_dataset" do
      API.get_dataset(@valid_config, "dataset")

      assert_receive {:telemetry, [:raggio, :bigquery, :request, :start], _, %{method: :get}}
      assert_receive {:telemetry, [:raggio, :bigquery, :request, :stop], _, _}
    end

    test "emits telemetry events for insert_all" do
      rows = [%{"insertId" => "1", "json" => %{"id" => "a"}}]
      API.insert_all(@valid_config, "ds", "tbl", rows, [])

      assert_receive {:telemetry, [:raggio, :bigquery, :insert, :start], _,
                      %{dataset: "ds", table: "tbl", row_count: 1}}

      assert_receive {:telemetry, [:raggio, :bigquery, :insert, :stop], _, _}
    end

    test "emits telemetry events for query" do
      API.query(@valid_config, "SELECT 1")

      assert_receive {:telemetry, [:raggio, :bigquery, :query, :start], _, %{query: "SELECT 1"}}
      assert_receive {:telemetry, [:raggio, :bigquery, :query, :stop], _, _}
    end

    test "emits telemetry events for merge" do
      rows = [%{"id" => "1", "name" => "test"}]
      API.merge(@valid_config, "ds", "tbl", rows, "id", [])

      assert_receive {:telemetry, [:raggio, :bigquery, :merge, :start], _,
                      %{dataset: "ds", table: "tbl", row_count: 1}}

      assert_receive {:telemetry, [:raggio, :bigquery, :merge, :stop], _, _}
    end
  end
end
