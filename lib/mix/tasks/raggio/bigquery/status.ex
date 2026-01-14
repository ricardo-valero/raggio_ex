defmodule Mix.Tasks.Raggio.Bigquery.Status do
  @moduledoc """
  Shows migration status for a BigQuery dataset.

  ## Usage

      mix raggio.bigquery.status --repo MyApp.Repo --dataset billing

  ## Options

    * `--repo` - The repo module (required)
    * `--dataset` - The dataset to check (required)
    * `--path` - Custom migrations path (default: priv/raggio/bigquery)

  ## Output

  Shows a table with:
    * Status (up/down)
    * Version (timestamp)
    * Name
    * Applied at (if up)

  ## Examples

      mix raggio.bigquery.status --repo MyApp.Repo --dataset billing

      # Status  | Version        | Name              | Applied
      # --------|----------------|-------------------|------------------
      #   up    | 20260108120000 | add_status_field  | 2026-01-08 12:30
      #   up    | 20260108130000 | add_priority      | 2026-01-08 13:45
      #  down   | 20260108140000 | add_charges_table |
  """

  use Mix.Task

  alias Raggio.BigQuery.Migrator.{Loader, Tracker}

  @shortdoc "Shows BigQuery migration status"

  @switches [
    repo: :string,
    dataset: :string,
    path: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    repo = get_repo!(opts)
    dataset = Keyword.fetch!(opts, :dataset)
    path = Keyword.get(opts, :path, Loader.default_path())

    Mix.Task.run("app.start")

    with {:ok, local} <- Loader.load(path: path, dataset: dataset),
         {:ok, applied} <- Tracker.list_applied(repo, dataset: dataset) do
      display_status(local, applied)
    else
      {:error, reason} ->
        Mix.raise("Status check failed: #{inspect(reason)}")
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

  defp display_status(local, applied) do
    applied_map = Map.new(applied, &{&1.version, &1})

    Mix.shell().info("")
    Mix.shell().info("Status | Version        | Name                  | Applied")
    Mix.shell().info("-------|----------------|-----------------------|------------------")

    Enum.each(local, fn migration ->
      case Map.get(applied_map, migration.version) do
        nil ->
          Mix.shell().info(" down  | #{migration.version} | #{pad(migration.name, 21)} |")

        applied_mig ->
          applied_at = format_datetime(applied_mig.applied_at)

          Mix.shell().info(
            "  up   | #{migration.version} | #{pad(migration.name, 21)} | #{applied_at}"
          )
      end
    end)

    Mix.shell().info("")

    pending_count = length(local) - map_size(applied_map)
    applied_count = map_size(applied_map)

    Mix.shell().info(
      "Total: #{length(local)} migrations (#{applied_count} applied, #{pending_count} pending)"
    )
  end

  defp pad(string, length) do
    string
    |> String.slice(0, length)
    |> String.pad_trailing(length)
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end
