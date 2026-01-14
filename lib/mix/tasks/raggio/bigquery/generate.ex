defmodule Mix.Tasks.Raggio.Bigquery.Generate do
  @moduledoc """
  Generate migration files from schema changes.

  ## Usage

      mix raggio.bigquery.generate --repo MyApp.BigQueryRepo --table MyApp.Tables.Events --name add_status

  ## Options

    * `--repo` - The BigQuery Repo module (required)
    * `--table` - The Table module to diff (required)
    * `--name` - Migration name (required)
    * `--path` - Base migrations path (default: priv/raggio/bigquery)
    * `--no-detect-renames` - Disable rename detection

  ## Examples

      mix raggio.bigquery.generate --repo MyApp.Repo --table MyApp.Tables.Events --name add_status_field
  """

  use Mix.Task

  alias Raggio.BigQuery.{Differ, Migrator.Generator}
  alias Raggio.BigQuery.Differ.Change

  @shortdoc "Generate BigQuery migration files"

  @switches [
    repo: :string,
    table: :string,
    name: :string,
    path: :string,
    no_detect_renames: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    repo = get_required_opt!(opts, :repo, "Missing --repo option")
    table = get_required_opt!(opts, :table, "Missing --table option")
    name = get_required_opt!(opts, :name, "Missing --name option")
    base_path = Keyword.get(opts, :path, "priv/raggio/bigquery")
    detect_renames = not Keyword.get(opts, :no_detect_renames, false)

    repo_module = Module.concat([repo])
    table_module = Module.concat([table])

    diff_opts = [detect_renames: detect_renames]

    case Differ.diff(repo_module, table_module, diff_opts) do
      {:ok, []} ->
        Mix.shell().info("No changes detected. Schema is up to date.")

      {:ok, changes} ->
        display_changes(changes)
        generate_migration(name, changes, base_path, table_module)

      {:error, reason} ->
        Mix.raise("Failed to diff schemas: #{inspect(reason)}")
    end
  end

  defp get_required_opt!(opts, key, error_message) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise(error_message)
      value -> value
    end
  end

  defp display_changes(changes) do
    Mix.shell().info("\nDetected #{length(changes)} change(s):\n")

    Enum.each(changes, fn change ->
      prefix = if change.destructive, do: "  [DESTRUCTIVE] ", else: "  "
      Mix.shell().info("#{prefix}#{Change.describe(change)}")
    end)

    Mix.shell().info("")
  end

  defp generate_migration(name, changes, base_path, table_module) do
    dataset = table_module.__dataset__()

    case Generator.generate(name, changes, base_path, dataset: dataset) do
      {:ok, migration, paths} ->
        Mix.shell().info("Generated migration: #{Raggio.BigQuery.Migration.full_name(migration)}")
        Mix.shell().info("  Created: #{paths.dir}")
        Mix.shell().info("    - up.sql")
        Mix.shell().info("    - down.sql")

      {:error, {:not_reversible, change}} ->
        Mix.raise("Cannot generate down migration: #{Change.describe(change)} is not reversible")

      {:error, reason} ->
        Mix.raise("Failed to generate migration: #{inspect(reason)}")
    end
  end
end
