defmodule Mix.Tasks.Raggio.Bigquery.Migrate do
  @moduledoc """
  Runs pending migrations for a BigQuery dataset.

  ## Usage

      mix raggio.bigquery.migrate --repo MyApp.Repo --dataset billing

  ## Options

    * `--repo` - The repo module (required)
    * `--dataset` - The dataset to migrate (required)
    * `--path` - Custom migrations path (default: priv/raggio/bigquery)
    * `--step` - Number of migrations to run (default: all)
    * `--dry-run` - Print SQL without executing

  ## Examples

      # Run all pending migrations
      mix raggio.bigquery.migrate --repo MyApp.Repo --dataset billing

      # Run only the next 2 migrations
      mix raggio.bigquery.migrate --repo MyApp.Repo --dataset billing --step 2

      # Preview SQL without running
      mix raggio.bigquery.migrate --repo MyApp.Repo --dataset billing --dry-run
  """

  use Mix.Task

  alias Raggio.BigQuery.Migrator.{Executor, Loader, Tracker}

  @shortdoc "Runs pending BigQuery migrations"

  @switches [
    repo: :string,
    dataset: :string,
    path: :string,
    step: :integer,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    repo = get_repo!(opts)
    dataset = Keyword.fetch!(opts, :dataset)
    path = Keyword.get(opts, :path, Loader.default_path())
    step = Keyword.get(opts, :step)
    dry_run = Keyword.get(opts, :dry_run, false)

    Mix.Task.run("app.start")

    with :ok <- Tracker.ensure_table(repo, dataset),
         {:ok, local} <- Loader.load(path: path, dataset: dataset),
         {:ok, applied} <- Tracker.list_applied(repo, dataset: dataset) do
      pending = filter_pending(local, applied)
      pending = if step, do: Enum.take(pending, step), else: pending

      if Enum.empty?(pending) do
        Mix.shell().info("No pending migrations")
      else
        run_migrations(repo, pending, dataset, dry_run)
      end
    else
      {:error, reason} ->
        Mix.raise("Migration failed: #{inspect(reason)}")
    end
  end

  defp get_repo!(opts) do
    case Keyword.fetch(opts, :repo) do
      {:ok, repo_string} ->
        Module.concat([repo_string])

      :error ->
        Mix.raise("--repo is required")
    end
  end

  defp filter_pending(local, applied) do
    applied_versions = MapSet.new(applied, & &1.version)

    local
    |> Enum.reject(&MapSet.member?(applied_versions, &1.version))
    |> Enum.sort_by(& &1.version)
  end

  defp run_migrations(repo, migrations, dataset, dry_run) do
    Enum.each(migrations, fn migration ->
      Mix.shell().info("Running #{migration.version}_#{migration.name}...")

      case Executor.execute_up(repo, migration, dataset: dataset, dry_run: dry_run) do
        {:ok, %{sql: sql, dry_run: true}} ->
          Mix.shell().info("SQL:\n#{sql}")

        {:ok, time_ms} ->
          Mix.shell().info("  -> Completed in #{time_ms}ms")

        {:error, reason} ->
          Mix.raise("Migration #{migration.version} failed: #{inspect(reason)}")
      end
    end)

    unless dry_run do
      Mix.shell().info("\nMigrations complete: #{length(migrations)} applied")
    end
  end
end
