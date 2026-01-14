defmodule Mix.Tasks.Raggio.Bigquery.Push do
  @moduledoc """
  Push schema changes to BigQuery.

  Compares local table definitions to remote BigQuery tables and applies changes.

  ## Usage

      mix raggio.bigquery.push --repo MyApp.BigQueryRepo --table MyApp.Tables.Events

  ## Options

    * `--repo` - The BigQuery Repo module (required)
    * `--table` - The Table module to push (required)
    * `--force` - Skip confirmation prompts for destructive changes
    * `--dry-run` - Show changes without applying them
    * `--no-detect-renames` - Disable rename detection

  ## Examples

      # Push a single table
      mix raggio.bigquery.push --repo MyApp.Repo --table MyApp.Tables.Events

      # Force push without confirmation
      mix raggio.bigquery.push --repo MyApp.Repo --table MyApp.Tables.Events --force

      # Preview changes without applying
      mix raggio.bigquery.push --repo MyApp.Repo --table MyApp.Tables.Events --dry-run
  """

  use Mix.Task

  alias Raggio.BigQuery.{Differ, DDL}
  alias Raggio.BigQuery.Differ.Change

  @shortdoc "Push schema changes to BigQuery"

  @switches [
    repo: :string,
    table: :string,
    force: :boolean,
    dry_run: :boolean,
    no_detect_renames: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    repo = get_required_opt!(opts, :repo, "Missing --repo option")
    table = get_required_opt!(opts, :table, "Missing --table option")
    force = Keyword.get(opts, :force, false)
    dry_run = Keyword.get(opts, :dry_run, false)
    detect_renames = not Keyword.get(opts, :no_detect_renames, false)

    repo_module = Module.concat([repo])
    table_module = Module.concat([table])

    diff_opts = [detect_renames: detect_renames]

    case Differ.diff(repo_module, table_module, diff_opts) do
      {:ok, []} ->
        Mix.shell().info("No changes detected. Schema is up to date.")

      {:ok, changes} ->
        display_changes(changes)

        if dry_run do
          display_dry_run_sql(changes)
        else
          maybe_apply_changes(repo_module, changes, force)
        end

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

  defp display_dry_run_sql(changes) do
    Mix.shell().info("Generated SQL (dry run):\n")

    {:ok, statements} = DDL.generate_up(changes)

    Enum.each(statements, fn sql ->
      Mix.shell().info("  #{sql};")
    end)
  end

  defp maybe_apply_changes(repo_module, changes, force) do
    if Differ.has_destructive?(changes) and not force do
      destructive = Differ.destructive_changes(changes)

      Mix.shell().info("The following destructive changes require confirmation:\n")

      Enum.each(destructive, fn change ->
        Mix.shell().info("  - #{Change.describe(change)}")
      end)

      Mix.shell().info("")

      if confirm_destructive?() do
        apply_changes(repo_module, changes)
      else
        Mix.shell().info("Aborted.")
      end
    else
      apply_changes(repo_module, changes)
    end
  end

  defp confirm_destructive? do
    Mix.shell().yes?("Proceed with destructive changes?")
  end

  defp apply_changes(repo_module, changes) do
    config = repo_module.config()
    {:ok, statements} = DDL.generate_up(changes)

    Mix.shell().info("Applying #{length(statements)} statement(s)...")

    results =
      Enum.map(statements, fn sql ->
        case Raggio.BigQuery.API.query(config, sql) do
          {:ok, _} ->
            Mix.shell().info("  OK: #{truncate(sql, 60)}")
            :ok

          {:error, reason} ->
            Mix.shell().error("  FAILED: #{truncate(sql, 60)}")
            Mix.shell().error("    Error: #{inspect(reason)}")
            {:error, reason}
        end
      end)

    failures = Enum.filter(results, &match?({:error, _}, &1))

    if failures == [] do
      Mix.shell().info("\nAll changes applied successfully.")
    else
      Mix.raise("#{length(failures)} statement(s) failed.")
    end
  end

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length) <> "..."
  end
end
