defmodule Mix.Tasks.Raggio.Bigquery.Rollback do
  @moduledoc """
  Rolls back migrations for a BigQuery dataset.

  ## Usage

      mix raggio.bigquery.rollback --repo MyApp.Repo --dataset billing

  ## Options

    * `--repo` - The repo module (required)
    * `--dataset` - The dataset to rollback (required)
    * `--path` - Custom migrations path (default: priv/raggio/bigquery)
    * `--step` - Number of migrations to rollback (default: 1)
    * `--all` - Rollback all applied migrations
    * `--to` - Rollback to a specific version (exclusive)
    * `--dry-run` - Print SQL without executing

  ## Examples

      # Rollback the last migration
      mix raggio.bigquery.rollback --repo MyApp.Repo --dataset billing

      # Rollback the last 3 migrations
      mix raggio.bigquery.rollback --repo MyApp.Repo --dataset billing --step 3

      # Rollback all migrations
      mix raggio.bigquery.rollback --repo MyApp.Repo --dataset billing --all

      # Rollback to a specific version
      mix raggio.bigquery.rollback --repo MyApp.Repo --dataset billing --to 20260108120000
  """

  use Mix.Task

  alias Raggio.BigQuery.Migrator.{Executor, Loader, Tracker}

  @shortdoc "Rolls back BigQuery migrations"

  @switches [
    repo: :string,
    dataset: :string,
    path: :string,
    step: :integer,
    all: :boolean,
    to: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    repo = get_repo!(opts)
    dataset = Keyword.fetch!(opts, :dataset)
    path = Keyword.get(opts, :path, Loader.default_path())
    dry_run = Keyword.get(opts, :dry_run, false)

    Mix.Task.run("app.start")

    with {:ok, local} <- Loader.load(path: path, dataset: dataset),
         {:ok, applied} <- Tracker.list_applied(repo, dataset: dataset) do
      to_rollback = select_rollback(local, applied, opts)

      if Enum.empty?(to_rollback) do
        Mix.shell().info("No migrations to rollback")
      else
        run_rollbacks(repo, to_rollback, dataset, dry_run)
      end
    else
      {:error, reason} ->
        Mix.raise("Rollback failed: #{inspect(reason)}")
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

  defp select_rollback(local, applied, opts) do
    cond do
      Keyword.get(opts, :all) ->
        migrations_to_rollback(local, applied, length(applied))

      to = Keyword.get(opts, :to) ->
        count = count_to_version(applied, to)
        migrations_to_rollback(local, applied, count)

      true ->
        step = Keyword.get(opts, :step, 1)
        migrations_to_rollback(local, applied, step)
    end
  end

  defp migrations_to_rollback(local, applied, count) do
    local_by_version = Map.new(local, &{&1.version, &1})

    applied
    |> Enum.reverse()
    |> Enum.take(count)
    |> Enum.map(fn applied_mig ->
      case Map.get(local_by_version, applied_mig.version) do
        nil ->
          Mix.raise("Migration #{applied_mig.version} not found on disk")

        migration ->
          migration
      end
    end)
  end

  defp count_to_version(applied, target_version) do
    applied
    |> Enum.reverse()
    |> Enum.take_while(&(&1.version != target_version))
    |> length()
  end

  defp run_rollbacks(repo, migrations, dataset, dry_run) do
    Enum.each(migrations, fn migration ->
      Mix.shell().info("Rolling back #{migration.version}_#{migration.name}...")

      case Executor.execute_down(repo, migration, dataset: dataset, dry_run: dry_run) do
        {:ok, %{sql: sql, dry_run: true}} ->
          Mix.shell().info("SQL:\n#{sql}")

        {:ok, time_ms} ->
          Mix.shell().info("  -> Completed in #{time_ms}ms")

        {:error, reason} ->
          Mix.raise("Rollback #{migration.version} failed: #{inspect(reason)}")
      end
    end)

    unless dry_run do
      Mix.shell().info("\nRollback complete: #{length(migrations)} rolled back")
    end
  end
end
