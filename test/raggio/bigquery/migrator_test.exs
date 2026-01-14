defmodule Raggio.BigQuery.MigratorTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Migration
  alias Raggio.BigQuery.Migrator.Generator
  alias Raggio.BigQuery.Differ.Change

  describe "Migration struct" do
    test "new/3 creates migration with required fields" do
      migration = Migration.new("20260108120000", "add_status")

      assert migration.version == "20260108120000"
      assert migration.name == "add_status"
      assert migration.dataset == nil
    end

    test "new/3 accepts optional fields" do
      migration = Migration.new("20260108120000", "add_status", dataset: "billing")

      assert migration.dataset == "billing"
    end

    test "from_filename/1 parses valid filename" do
      {:ok, migration} = Migration.from_filename("20260108120000_add_status_field")

      assert migration.version == "20260108120000"
      assert migration.name == "add_status_field"
    end

    test "from_filename/1 returns error for invalid format" do
      assert {:error, :invalid_format} = Migration.from_filename("invalid")
      assert {:error, :invalid_format} = Migration.from_filename("123_too_short")
    end

    test "full_name/1 combines version and name" do
      migration = Migration.new("20260108120000", "add_status")

      assert Migration.full_name(migration) == "20260108120000_add_status"
    end

    test "compare/2 compares by version" do
      m1 = Migration.new("20260108120000", "first")
      m2 = Migration.new("20260108130000", "second")
      m3 = Migration.new("20260108120000", "same_version")

      assert Migration.compare(m1, m2) == :lt
      assert Migration.compare(m2, m1) == :gt
      assert Migration.compare(m1, m3) == :eq
    end

    test "directory/2 returns base path without dataset" do
      migration = Migration.new("20260108120000", "test")

      assert Migration.directory(migration, "priv/bigquery") == "priv/bigquery"
    end

    test "directory/2 includes dataset in path" do
      migration = Migration.new("20260108120000", "test", dataset: "billing")

      assert Migration.directory(migration, "priv/bigquery") == "priv/bigquery/billing"
    end

    test "migration_dir/2 returns full path" do
      migration = Migration.new("20260108120000", "add_status", dataset: "billing")

      assert Migration.migration_dir(migration, "priv/bigquery") ==
               "priv/bigquery/billing/20260108120000_add_status"
    end

    test "up_path/2 returns up.sql path" do
      migration = Migration.new("20260108120000", "add_status")

      assert Migration.up_path(migration, "priv") == "priv/20260108120000_add_status/up.sql"
    end

    test "down_path/2 returns down.sql path" do
      migration = Migration.new("20260108120000", "add_status")

      assert Migration.down_path(migration, "priv") == "priv/20260108120000_add_status/down.sql"
    end
  end

  describe "Generator.generate_version/0" do
    test "returns 14-digit timestamp string" do
      version = Generator.generate_version()

      assert String.length(version) == 14
      assert String.match?(version, ~r/^\d{14}$/)
    end
  end

  describe "Generator.generate_version/1" do
    test "formats datetime correctly" do
      dt = ~U[2026-01-08 12:30:45Z]
      version = Generator.generate_version(dt)

      assert version == "20260108123045"
    end
  end

  describe "Generator.normalize_name/1" do
    test "lowercases name" do
      assert Generator.normalize_name("Add Status") == "add_status"
    end

    test "replaces special characters with underscores" do
      assert Generator.normalize_name("add-status.field!") == "add_status_field"
    end

    test "collapses multiple underscores" do
      assert Generator.normalize_name("add___status") == "add_status"
    end

    test "trims leading/trailing underscores" do
      assert Generator.normalize_name("_add_status_") == "add_status"
    end
  end

  describe "Generator.create_migration/2" do
    test "creates migration with normalized name" do
      migration = Generator.create_migration("Add Status Field", version: "20260108120000")

      assert migration.name == "add_status_field"
      assert migration.version == "20260108120000"
    end

    test "passes options to migration" do
      migration =
        Generator.create_migration("test", dataset: "billing", version: "20260108120000")

      assert migration.dataset == "billing"
    end
  end

  describe "Generator.generate_sql/2" do
    test "generates up and down SQL from changes" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "status",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, up_sql, down_sql} = Generator.generate_sql(changes)

      assert String.contains?(up_sql, "ADD COLUMN status STRING")
      assert String.contains?(down_sql, "DROP COLUMN status")
    end

    test "returns error for non-reversible changes" do
      changes = [
        Change.new(:change_type, "ds.table",
          column: "col",
          details: %{from: "STRING", to: "INT64"}
        )
      ]

      result = Generator.generate_sql(changes)

      assert {:error, {:not_reversible, _}} = result
    end

    test "includes header comments" do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "col",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, up_sql, down_sql} = Generator.generate_sql(changes)

      assert String.contains?(up_sql, "-- Generated by Raggio.BigQuery")
      assert String.contains?(up_sql, "-- Direction: UP")
      assert String.contains?(down_sql, "-- Direction: DOWN")
    end
  end

  describe "Generator.generate/4" do
    @tag :tmp_dir
    test "returns error for empty changes", %{tmp_dir: tmp_dir} do
      result = Generator.generate("test", [], tmp_dir, [])

      assert {:error, :no_changes} = result
    end

    @tag :tmp_dir
    test "creates migration files", %{tmp_dir: tmp_dir} do
      changes = [
        Change.new(:add_column, "ds.table",
          column: "status",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, migration, paths} =
        Generator.generate("add_status", changes, tmp_dir, version: "20260108120000")

      assert migration.version == "20260108120000"
      assert migration.name == "add_status"
      assert File.exists?(paths.up)
      assert File.exists?(paths.down)
    end

    @tag :tmp_dir
    test "creates files in dataset subdirectory", %{tmp_dir: tmp_dir} do
      changes = [
        Change.new(:add_column, "billing.charges",
          column: "status",
          details: %{bq_type: "STRING", mode: "NULLABLE"}
        )
      ]

      {:ok, _migration, paths} =
        Generator.generate("add_status", changes, tmp_dir,
          dataset: "billing",
          version: "20260108120000"
        )

      assert String.contains?(paths.dir, "/billing/")
    end
  end
end
