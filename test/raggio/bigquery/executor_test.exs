defmodule Raggio.BigQuery.ExecutorTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Migration
  alias Raggio.BigQuery.Migrator.Executor

  defmodule MockRepo do
    def config, do: [project_id: "test-project"]

    def query(_sql, _params \\ []) do
      {:ok, []}
    end
  end

  defmodule FailingRepo do
    def config, do: [project_id: "test-project"]

    def query(_sql, _params \\ []) do
      {:error, :query_failed}
    end
  end

  describe "validate_migration/2" do
    test "returns error for nil up_sql when direction is :up" do
      migration = %Migration{version: "1", name: "test", up_sql: nil}
      assert {:error, :missing_up_sql} = Executor.validate_migration(migration, :up)
    end

    test "returns error for empty up_sql when direction is :up" do
      migration = %Migration{version: "1", name: "test", up_sql: ""}
      assert {:error, :empty_up_sql} = Executor.validate_migration(migration, :up)
    end

    test "returns error for nil down_sql when direction is :down" do
      migration = %Migration{version: "1", name: "test", down_sql: nil}
      assert {:error, :missing_down_sql} = Executor.validate_migration(migration, :down)
    end

    test "returns error for empty down_sql when direction is :down" do
      migration = %Migration{version: "1", name: "test", down_sql: ""}
      assert {:error, :empty_down_sql} = Executor.validate_migration(migration, :down)
    end

    test "returns :ok for valid up migration" do
      migration = %Migration{version: "1", name: "test", up_sql: "ALTER TABLE"}
      assert :ok = Executor.validate_migration(migration, :up)
    end

    test "returns :ok for valid down migration" do
      migration = %Migration{version: "1", name: "test", down_sql: "ALTER TABLE"}
      assert :ok = Executor.validate_migration(migration, :down)
    end
  end

  describe "substitute_variables/3" do
    test "replaces {project} placeholder" do
      sql = "SELECT * FROM `{project}.dataset.table`"
      result = Executor.substitute_variables(sql, MockRepo, "billing")
      assert result == "SELECT * FROM `test-project.dataset.table`"
    end

    test "replaces {dataset} placeholder" do
      sql = "SELECT * FROM `project.{dataset}.table`"
      result = Executor.substitute_variables(sql, MockRepo, "billing")
      assert result == "SELECT * FROM `project.billing.table`"
    end

    test "replaces both placeholders" do
      sql = "SELECT * FROM `{project}.{dataset}.table`"
      result = Executor.substitute_variables(sql, MockRepo, "billing")
      assert result == "SELECT * FROM `test-project.billing.table`"
    end

    test "handles multiple occurrences" do
      sql = "`{project}.{dataset}` and `{project}.{dataset}`"
      result = Executor.substitute_variables(sql, MockRepo, "data")
      assert result == "`test-project.data` and `test-project.data`"
    end
  end

  describe "execute_up/3" do
    test "returns error without dataset" do
      migration = %Migration{version: "1", name: "test", up_sql: "SQL", dataset: nil}
      assert {:error, :dataset_required} = Executor.execute_up(MockRepo, migration, [])
    end

    test "returns error for missing up_sql" do
      migration = %Migration{version: "1", name: "test", up_sql: nil, dataset: "billing"}
      assert {:error, :missing_up_sql} = Executor.execute_up(MockRepo, migration, [])
    end

    test "dry run returns SQL without executing" do
      migration = %Migration{
        version: "1",
        name: "test",
        up_sql: "ALTER TABLE `{project}.{dataset}.t` ADD COLUMN x STRING",
        dataset: "billing"
      }

      assert {:ok, %{sql: sql, dry_run: true}} =
               Executor.execute_up(MockRepo, migration, dry_run: true)

      assert sql =~ "test-project.billing.t"
    end
  end

  describe "execute_down/3" do
    test "returns error without dataset" do
      migration = %Migration{version: "1", name: "test", down_sql: "SQL", dataset: nil}
      assert {:error, :dataset_required} = Executor.execute_down(MockRepo, migration, [])
    end

    test "returns error for missing down_sql" do
      migration = %Migration{version: "1", name: "test", down_sql: nil, dataset: "billing"}
      assert {:error, :missing_down_sql} = Executor.execute_down(MockRepo, migration, [])
    end

    test "dry run returns SQL without executing" do
      migration = %Migration{
        version: "1",
        name: "test",
        down_sql: "ALTER TABLE `{project}.{dataset}.t` DROP COLUMN x",
        dataset: "billing"
      }

      assert {:ok, %{sql: sql, dry_run: true}} =
               Executor.execute_down(MockRepo, migration, dry_run: true)

      assert sql =~ "test-project.billing.t"
    end
  end
end
