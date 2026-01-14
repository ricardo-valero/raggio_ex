defmodule Raggio.BigQuery.DDLTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.DDL
  alias Raggio.BigQuery.Differ.Change

  describe "generate_up/2" do
    test "generates CREATE TABLE for create_table change" do
      changes = [
        Change.new(:create_table, "ds.table",
          details: %{
            fields: [
              %{"name" => "id", "type" => "STRING", "mode" => "REQUIRED"},
              %{"name" => "name", "type" => "STRING", "mode" => "NULLABLE"}
            ]
          }
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert String.contains?(sql, "CREATE TABLE IF NOT EXISTS `ds.table`")
      assert String.contains?(sql, "id STRING NOT NULL")
      assert String.contains?(sql, "name STRING")
    end

    test "generates ADD COLUMN for add_column change" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "status",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` ADD COLUMN status STRING"
    end

    test "generates ADD COLUMN with NOT NULL for REQUIRED mode" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "id",
          details: %{bq_type: "INT64", mode: "REQUIRED"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` ADD COLUMN id INT64 NOT NULL"
    end

    test "generates DROP COLUMN for drop_column change" do
      changes = [
        Change.new(:drop_column, "ds.table", column: "old_col")
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` DROP COLUMN old_col"
    end

    test "generates RENAME COLUMN for rename_column change" do
      changes = [
        Change.new(:rename_column, "ds.table",
          column: "new_name",
          details: %{from: "old_name", to: "new_name"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` RENAME COLUMN old_name TO new_name"
    end

    test "generates ALTER COLUMN SET DATA TYPE for change_type change" do
      changes = [
        Change.new(:change_type, "ds.table",
          column: "amount",
          details: %{from: "INT64", to: "FLOAT64"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` ALTER COLUMN amount SET DATA TYPE FLOAT64"
    end

    test "generates SET NOT NULL for change_mode to REQUIRED" do
      changes = [
        Change.new(:change_mode, "ds.table",
          column: "name",
          details: %{from: "NULLABLE", to: "REQUIRED"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` ALTER COLUMN name SET NOT NULL"
    end

    test "generates DROP NOT NULL for change_mode to NULLABLE" do
      changes = [
        Change.new(:change_mode, "ds.table",
          column: "name",
          details: %{from: "REQUIRED", to: "NULLABLE"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes)

      assert sql == "ALTER TABLE `ds.table` ALTER COLUMN name DROP NOT NULL"
    end

    test "qualifies table with project when provided" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "col",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, [sql]} = DDL.generate_up(changes, project: "my-project")

      assert String.contains?(sql, "`my-project.ds.table`")
    end
  end

  describe "generate_down/2" do
    test "generates DROP for add_column change" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "new_col",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, [sql]} = DDL.generate_down(changes)

      assert sql == "ALTER TABLE `ds.table` DROP COLUMN new_col"
    end

    test "generates ADD for drop_column change" do
      changes = [
        Change.new(:drop_column, "ds.table",
          column: "old_col",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, [sql]} = DDL.generate_down(changes)

      assert sql == "ALTER TABLE `ds.table` ADD COLUMN old_col STRING"
    end

    test "generates reverse RENAME for rename_column change" do
      changes = [
        Change.new(:rename_column, "ds.table",
          column: "new_name",
          details: %{from: "old_name", to: "new_name"}
        )
      ]

      {:ok, [sql]} = DDL.generate_down(changes)

      assert sql == "ALTER TABLE `ds.table` RENAME COLUMN new_name TO old_name"
    end

    test "returns error for non-reversible change_type" do
      changes = [
        Change.new(:change_type, "ds.table",
          column: "col",
          details: %{from: "STRING", to: "INT64"}
        )
      ]

      result = DDL.generate_down(changes)

      assert {:error, {:not_reversible, _}} = result
    end

    test "reverses statements in order" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "a",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        ),
        Change.new(:add_column, "ds.table",
          column: "b",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, statements} = DDL.generate_down(changes)

      assert [first, second] = statements
      assert String.contains?(first, "DROP COLUMN b")
      assert String.contains?(second, "DROP COLUMN a")
    end
  end

  describe "join_statements/2" do
    test "joins statements with semicolons" do
      statements = [
        "ALTER TABLE `t` ADD COLUMN a STRING",
        "ALTER TABLE `t` ADD COLUMN b INT64"
      ]

      result = DDL.join_statements(statements)

      assert result ==
               "ALTER TABLE `t` ADD COLUMN a STRING;\n\nALTER TABLE `t` ADD COLUMN b INT64;"
    end

    test "uses custom separator" do
      statements = ["SELECT 1", "SELECT 2"]

      result = DDL.join_statements(statements, separator: "; ")

      assert result == "SELECT 1; SELECT 2;"
    end
  end
end
