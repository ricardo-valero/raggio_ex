defmodule Raggio.BigQuery.LoaderTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Migrator.Loader
  alias Raggio.BigQuery.Migration

  @test_path "test/fixtures/migrations"

  setup do
    File.rm_rf!(@test_path)
    on_exit(fn -> File.rm_rf!(@test_path) end)
    :ok
  end

  describe "load/1" do
    test "returns empty list when path doesn't exist" do
      assert {:ok, []} = Loader.load(path: "nonexistent/path")
    end

    test "returns empty list when path is empty" do
      File.mkdir_p!(@test_path)
      assert {:ok, []} = Loader.load(path: @test_path)
    end

    test "loads migrations from dataset directory" do
      setup_migration(@test_path, "billing", "20260108120000", "add_status", "UP SQL", "DOWN SQL")

      assert {:ok, [migration]} = Loader.load(path: @test_path)

      assert %Migration{} = migration
      assert migration.version == "20260108120000"
      assert migration.name == "add_status"
      assert migration.dataset == "billing"
      assert migration.up_sql == "UP SQL"
      assert migration.down_sql == "DOWN SQL"
      assert is_binary(migration.checksum)
    end

    test "loads multiple migrations sorted by version" do
      setup_migration(@test_path, "billing", "20260108130000", "second", "UP2", "DOWN2")
      setup_migration(@test_path, "billing", "20260108120000", "first", "UP1", "DOWN1")
      setup_migration(@test_path, "billing", "20260108140000", "third", "UP3", "DOWN3")

      assert {:ok, migrations} = Loader.load(path: @test_path)
      assert length(migrations) == 3

      versions = Enum.map(migrations, & &1.version)
      assert versions == ["20260108120000", "20260108130000", "20260108140000"]
    end

    test "filters by dataset" do
      setup_migration(@test_path, "billing", "20260108120000", "billing_mig", "UP1", "DOWN1")
      setup_migration(@test_path, "procurement", "20260108120000", "proc_mig", "UP2", "DOWN2")

      assert {:ok, migrations} = Loader.load(path: @test_path, dataset: "billing")
      assert length(migrations) == 1
      assert hd(migrations).dataset == "billing"
    end

    test "loads migrations from multiple datasets" do
      setup_migration(@test_path, "billing", "20260108120000", "billing_mig", "UP1", "DOWN1")
      setup_migration(@test_path, "procurement", "20260108130000", "proc_mig", "UP2", "DOWN2")

      assert {:ok, migrations} = Loader.load(path: @test_path)
      assert length(migrations) == 2
    end

    test "handles missing up.sql gracefully" do
      dir = Path.join([@test_path, "billing", "20260108120000_missing_up"])
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "down.sql"), "DOWN SQL")

      assert {:ok, [migration]} = Loader.load(path: @test_path)
      assert migration.up_sql == nil
      assert migration.down_sql == "DOWN SQL"
    end

    test "handles missing down.sql gracefully" do
      dir = Path.join([@test_path, "billing", "20260108120000_missing_down"])
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "up.sql"), "UP SQL")

      assert {:ok, [migration]} = Loader.load(path: @test_path)
      assert migration.up_sql == "UP SQL"
      assert migration.down_sql == nil
    end

    test "ignores invalid directory names" do
      File.mkdir_p!(Path.join([@test_path, "billing", "invalid_name"]))
      setup_migration(@test_path, "billing", "20260108120000", "valid", "UP", "DOWN")

      assert {:ok, [migration]} = Loader.load(path: @test_path)
      assert migration.name == "valid"
    end

    test "calculates consistent checksum" do
      setup_migration(@test_path, "billing", "20260108120000", "test", "UP SQL", "DOWN SQL")

      {:ok, [migration1]} = Loader.load(path: @test_path)
      {:ok, [migration2]} = Loader.load(path: @test_path)

      assert migration1.checksum == migration2.checksum
    end

    test "checksum changes when content changes" do
      dir = Path.join([@test_path, "billing", "20260108120000_test"])
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "up.sql"), "ORIGINAL")
      File.write!(Path.join(dir, "down.sql"), "DOWN")

      {:ok, [migration1]} = Loader.load(path: @test_path)

      File.write!(Path.join(dir, "up.sql"), "MODIFIED")

      {:ok, [migration2]} = Loader.load(path: @test_path)

      assert migration1.checksum != migration2.checksum
    end
  end

  describe "default_path/0" do
    test "returns the default migrations path" do
      assert Loader.default_path() == "priv/raggio/bigquery"
    end
  end

  defp setup_migration(base_path, dataset, version, name, up_sql, down_sql) do
    dir = Path.join([base_path, dataset, "#{version}_#{name}"])
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "up.sql"), up_sql)
    File.write!(Path.join(dir, "down.sql"), down_sql)
    dir
  end
end
