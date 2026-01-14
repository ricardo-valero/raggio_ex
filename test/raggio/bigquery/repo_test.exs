defmodule Raggio.BigQuery.RepoTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{MockHTTPClient, MockAuth}

  defmodule TestRepo do
    use Raggio.BigQuery.Repo, otp_app: :raggio_test

    @impl true
    def config do
      %{
        project_id: "test-project",
        http_client: MockHTTPClient,
        auth: MockAuth,
        default_dataset: "test_dataset"
      }
    end
  end

  defmodule TestTable do
    use Raggio.BigQuery.Table
    alias Raggio.Schema

    @impl true
    def __dataset__, do: "test_dataset"

    @impl true
    def __table__, do: "test_table"

    @impl true
    def __schema__ do
      Schema.struct([
        {:id, Schema.string()},
        {:name, Schema.string() |> Schema.nullable()},
        {:count, Schema.integer()}
      ])
    end
  end

  describe "behaviour compliance" do
    test "TestRepo implements Repo behaviour" do
      behaviours = TestRepo.__info__(:attributes)[:behaviour] || []
      assert Raggio.BigQuery.Repo in behaviours
    end
  end

  describe "config/0" do
    test "returns configuration map" do
      config = TestRepo.config()

      assert is_map(config)
      assert config[:project_id] == "test-project"
      assert config[:http_client] == MockHTTPClient
      assert config[:auth] == MockAuth
    end
  end

  describe "status/0" do
    test "returns :connected on success" do
      result = TestRepo.status()
      assert result == :connected
    end
  end

  describe "get_table_schema/2" do
    test "returns table schema" do
      result = TestRepo.get_table_schema("dataset", "table")

      assert {:ok, schema} = result
      assert is_map(schema)
      assert schema["kind"] == "bigquery#table"
    end
  end

  describe "insert/2" do
    test "inserts rows into table module" do
      rows = [
        %{id: "1", name: "Alice", count: 10},
        %{id: "2", name: "Bob", count: 20}
      ]

      result = TestRepo.insert(TestTable, rows)

      assert {:ok, 2} = result
    end

    test "returns error for empty rows" do
      result = TestRepo.insert(TestTable, [])
      assert {:error, :no_records} = result
    end
  end

  describe "insert/3" do
    test "accepts options" do
      rows = [%{id: "1", name: "Test", count: 5}]

      result = TestRepo.insert(TestTable, rows, batch_size: 1, skip_invalid_rows: true)

      assert {:ok, 1} = result
    end
  end

  describe "merge/3" do
    test "upserts rows using key field" do
      rows = [
        %{"id" => "1", "name" => "Alice", "count" => 10},
        %{"id" => "2", "name" => "Bob", "count" => 20}
      ]

      result = TestRepo.merge(TestTable, rows, key: :id)

      assert {:ok, 2} = result
    end

    test "returns {:ok, 0} for empty rows" do
      result = TestRepo.merge(TestTable, [], key: :id)
      assert {:ok, 0} = result
    end
  end

  describe "query/1" do
    test "executes SQL query" do
      result = TestRepo.query("SELECT COUNT(*) as count FROM table")

      assert {:ok, [row]} = result
      assert row["count"] == "42"
    end
  end

  describe "query/2" do
    test "executes parameterized query" do
      result = TestRepo.query("SELECT * FROM table WHERE id = @id", id: "123")

      assert {:ok, _rows} = result
    end
  end

  describe "telemetry integration" do
    setup do
      test_pid = self()
      handler_id = "repo-test-#{System.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [
          [:raggio, :bigquery, :repo, :status, :start],
          [:raggio, :bigquery, :repo, :status, :stop],
          [:raggio, :bigquery, :repo, :insert, :start],
          [:raggio, :bigquery, :repo, :insert, :stop],
          [:raggio, :bigquery, :repo, :query, :start],
          [:raggio, :bigquery, :repo, :query, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      :ok
    end

    test "emits telemetry events for status" do
      TestRepo.status()

      assert_receive {:telemetry, [:raggio, :bigquery, :repo, :status, :start], _, _}
      assert_receive {:telemetry, [:raggio, :bigquery, :repo, :status, :stop], _, _}
    end

    test "emits telemetry events for insert" do
      rows = [%{id: "1", name: "Test", count: 5}]
      TestRepo.insert(TestTable, rows)

      assert_receive {:telemetry, [:raggio, :bigquery, :repo, :insert, :start], _,
                      %{table: TestTable}}

      assert_receive {:telemetry, [:raggio, :bigquery, :repo, :insert, :stop], _, _}
    end

    test "emits telemetry events for query" do
      TestRepo.query("SELECT 1")

      assert_receive {:telemetry, [:raggio, :bigquery, :repo, :query, :start], _, _}
      assert_receive {:telemetry, [:raggio, :bigquery, :repo, :query, :stop], _, _}
    end
  end
end
