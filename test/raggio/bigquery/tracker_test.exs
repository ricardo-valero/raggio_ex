defmodule Raggio.BigQuery.TrackerTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.AppliedMigration
  alias Raggio.BigQuery.Migration
  alias Raggio.BigQuery.Migrator.Tracker

  defmodule MockRepo do
    def config, do: [project_id: "test-project"]

    def query(sql, _params \\ []) do
      cond do
        String.contains?(sql, "CREATE TABLE") -> {:ok, []}
        String.contains?(sql, "INSERT INTO") -> {:ok, []}
        String.contains?(sql, "DELETE FROM") -> {:ok, []}
        String.contains?(sql, "SELECT") -> {:ok, []}
        true -> {:ok, []}
      end
    end
  end

  describe "migrations_table/0" do
    test "returns the table name" do
      assert Tracker.migrations_table() == "_raggio_migrations"
    end
  end

  describe "ensure_table/2" do
    test "creates the tracking table" do
      assert :ok = Tracker.ensure_table(MockRepo, "billing")
    end
  end

  describe "record_applied/3" do
    test "inserts migration record" do
      migration = %Migration{
        version: "20260108120000",
        name: "add_status",
        dataset: "billing",
        up_sql: "ALTER TABLE",
        down_sql: "ALTER TABLE"
      }

      assert {:ok, %AppliedMigration{} = applied} =
               Tracker.record_applied(MockRepo, migration, dataset: "billing")

      assert applied.version == "20260108120000"
      assert applied.name == "add_status"
      assert applied.direction == :up
      assert %DateTime{} = applied.applied_at
    end

    test "requires dataset" do
      migration = %Migration{
        version: "20260108120000",
        name: "test",
        dataset: nil,
        up_sql: "SQL",
        down_sql: "SQL"
      }

      assert {:error, :dataset_required} = Tracker.record_applied(MockRepo, migration, [])
    end

    test "uses migration dataset if not provided in opts" do
      migration = %Migration{
        version: "20260108120000",
        name: "test",
        dataset: "billing",
        up_sql: "SQL",
        down_sql: "SQL"
      }

      assert {:ok, _} = Tracker.record_applied(MockRepo, migration, [])
    end
  end

  describe "remove_applied/3" do
    test "deletes migration record" do
      migration = %Migration{
        version: "20260108120000",
        name: "add_status",
        dataset: "billing",
        up_sql: "SQL",
        down_sql: "SQL"
      }

      assert :ok = Tracker.remove_applied(MockRepo, migration, dataset: "billing")
    end

    test "requires dataset" do
      migration = %Migration{version: "20260108120000", name: "test", dataset: nil}

      assert {:error, :dataset_required} = Tracker.remove_applied(MockRepo, migration, [])
    end
  end

  describe "list_applied/2" do
    test "requires dataset option" do
      assert_raise KeyError, fn ->
        Tracker.list_applied(MockRepo, [])
      end
    end

    test "returns list of applied migrations" do
      assert {:ok, []} = Tracker.list_applied(MockRepo, dataset: "billing")
    end
  end

  describe "applied?/3" do
    test "returns false when migration not applied" do
      refute Tracker.applied?(MockRepo, "20260108120000", dataset: "billing")
    end
  end

  describe "get_latest/2" do
    test "returns nil when no migrations applied" do
      assert {:ok, nil} = Tracker.get_latest(MockRepo, dataset: "billing")
    end
  end
end
