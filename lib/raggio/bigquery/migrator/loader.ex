defmodule Raggio.BigQuery.Migrator.Loader do
  @moduledoc """
  Loads migrations from the filesystem.

  Discovers migration directories and reads their SQL files (up.sql, down.sql)
  into Migration structs.

  ## Directory Structure

      priv/raggio/bigquery/
      ├── billing/                           # dataset
      │   ├── 20260108120000_add_status/     # version_name
      │   │   ├── up.sql
      │   │   └── down.sql
      │   └── 20260108130000_add_priority/
      │       ├── up.sql
      │       └── down.sql
      └── procurement/
          └── 20260108140000_add_charges/
              ├── up.sql
              └── down.sql

  ## Usage

      # Load all migrations
      {:ok, migrations} = Loader.load()

      # Load migrations for specific dataset
      {:ok, migrations} = Loader.load(dataset: "billing")

      # Load from custom path
      {:ok, migrations} = Loader.load(path: "custom/migrations")
  """

  alias Raggio.BigQuery.Migration

  @default_path "priv/raggio/bigquery"

  @spec load(keyword()) :: {:ok, [Migration.t()]} | {:error, term()}
  def load(opts \\ []) do
    path = Keyword.get(opts, :path, @default_path)
    dataset_filter = Keyword.get(opts, :dataset)

    if File.dir?(path) do
      migrations = load_from_path(path, dataset_filter)
      {:ok, sort_migrations(migrations)}
    else
      {:ok, []}
    end
  end

  @spec default_path :: String.t()
  def default_path, do: @default_path

  @spec load_from_path(String.t(), String.t() | nil) :: [Migration.t()]
  defp load_from_path(path, dataset_filter) do
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.flat_map(fn entry ->
          entry_path = Path.join(path, entry)

          cond do
            dataset_filter && entry != dataset_filter ->
              []

            File.dir?(entry_path) ->
              load_dataset_or_migration(entry_path, entry, nil)

            true ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp load_dataset_or_migration(path, dir_name, parent_dataset) do
    case Migration.from_filename(dir_name) do
      {:ok, migration} ->
        migration = %{migration | dataset: parent_dataset}
        [load_migration_files(migration, path)]

      {:error, _} ->
        if File.dir?(path) do
          load_dataset_migrations(path, dir_name)
        else
          []
        end
    end
  end

  defp load_dataset_migrations(dataset_path, dataset_name) do
    case File.ls(dataset_path) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&File.dir?(Path.join(dataset_path, &1)))
        |> Enum.flat_map(&load_migration_entry(&1, dataset_path, dataset_name))

      {:error, _} ->
        []
    end
  end

  defp load_migration_entry(migration_dir, dataset_path, dataset_name) do
    migration_path = Path.join(dataset_path, migration_dir)

    case Migration.from_filename(migration_dir) do
      {:ok, migration} ->
        migration = %{migration | dataset: dataset_name}
        [load_migration_files(migration, migration_path)]

      {:error, _} ->
        []
    end
  end

  defp load_migration_files(migration, path) do
    up_path = Path.join(path, "up.sql")
    down_path = Path.join(path, "down.sql")

    up_sql = read_file_if_exists(up_path)
    down_sql = read_file_if_exists(down_path)
    checksum = calculate_checksum(up_sql, down_sql)

    %{migration | up_sql: up_sql, down_sql: down_sql, checksum: checksum}
  end

  defp read_file_if_exists(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> nil
    end
  end

  defp sort_migrations(migrations) do
    Enum.sort(migrations, fn m1, m2 ->
      Migration.compare(m1, m2) != :gt
    end)
  end

  defp calculate_checksum(up_sql, down_sql) do
    content = (up_sql || "") <> "\n---\n" <> (down_sql || "")
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
