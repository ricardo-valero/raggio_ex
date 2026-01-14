defmodule Raggio.BigQuery.Migrator.Executor do
  @moduledoc """
  Executes migrations against BigQuery.

  Handles:
  - Variable substitution in SQL ({project}, {dataset})
  - Executing up and down migrations
  - Timing execution for tracking
  - Error handling and rollback coordination

  ## Variable Substitution

  Migration SQL files can use placeholders replaced at runtime:

  - `{project}` - Replaced with the GCP project ID
  - `{dataset}` - Replaced with the dataset name

  ## Example

      # up.sql
      ALTER TABLE `{project}.{dataset}.billing_items`
      ADD COLUMN status STRING;

      # Execution
      Executor.execute_up(repo, migration, dataset: "billing")
  """

  alias Raggio.BigQuery.Migration
  alias Raggio.BigQuery.Migrator.Tracker
  alias Raggio.BigQuery.Telemetry

  @type result :: {:ok, integer()} | {:ok, map()} | {:error, term()}

  @spec execute_up(module(), Migration.t(), keyword()) :: result()
  def execute_up(repo, migration, opts \\ []) do
    dataset = Keyword.get(opts, :dataset, migration.dataset)
    dry_run = Keyword.get(opts, :dry_run, false)

    case validate_migration(migration, :up) do
      :ok ->
        execute_sql(repo, migration.up_sql, dataset, dry_run, migration, :up, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec execute_down(module(), Migration.t(), keyword()) :: result()
  def execute_down(repo, migration, opts \\ []) do
    dataset = Keyword.get(opts, :dataset, migration.dataset)
    dry_run = Keyword.get(opts, :dry_run, false)

    case validate_migration(migration, :down) do
      :ok ->
        execute_sql(repo, migration.down_sql, dataset, dry_run, migration, :down, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec substitute_variables(String.t(), module(), String.t()) :: String.t()
  def substitute_variables(sql, repo, dataset) do
    config = repo.config()
    project_id = config[:project_id]

    sql
    |> String.replace("{project}", project_id || "")
    |> String.replace("{dataset}", dataset || "")
  end

  @spec validate_migration(Migration.t(), :up | :down) :: :ok | {:error, term()}
  def validate_migration(%Migration{up_sql: nil}, :up), do: {:error, :missing_up_sql}
  def validate_migration(%Migration{down_sql: nil}, :down), do: {:error, :missing_down_sql}
  def validate_migration(%Migration{up_sql: ""}, :up), do: {:error, :empty_up_sql}
  def validate_migration(%Migration{down_sql: ""}, :down), do: {:error, :empty_down_sql}
  def validate_migration(_migration, _direction), do: :ok

  defp execute_sql(repo, sql, dataset, dry_run, migration, direction, _opts) do
    if is_nil(dataset) do
      {:error, :dataset_required}
    else
      substituted_sql = substitute_variables(sql, repo, dataset)

      if dry_run do
        {:ok, %{sql: substituted_sql, dry_run: true}}
      else
        do_execute_sql(repo, substituted_sql, migration, dataset, direction)
      end
    end
  end

  defp do_execute_sql(repo, sql, migration, dataset, direction) do
    metadata = %{
      version: migration.version,
      direction: direction,
      dataset: dataset
    }

    Telemetry.span([:migrator, :executor, :execute], metadata, fn ->
      statements = split_statements(sql)
      start_time = System.monotonic_time(:millisecond)

      case execute_statements(repo, statements) do
        :ok ->
          execution_time_ms = System.monotonic_time(:millisecond) - start_time
          track_migration(repo, migration, dataset, direction, execution_time_ms)

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp track_migration(repo, migration, dataset, :up, execution_time_ms) do
    case Tracker.record_applied(repo, migration,
           dataset: dataset,
           direction: :up,
           execution_time_ms: execution_time_ms
         ) do
      {:ok, _} -> {:ok, {:ok, execution_time_ms}}
      {:error, reason} -> {:error, {:tracking_failed, reason}}
    end
  end

  defp track_migration(repo, migration, dataset, :down, execution_time_ms) do
    case Tracker.remove_applied(repo, migration, dataset: dataset) do
      :ok -> {:ok, {:ok, execution_time_ms}}
      {:error, reason} -> {:error, {:tracking_failed, reason}}
    end
  end

  defp split_statements(sql) do
    sql
    |> String.split(~r/;\s*\n/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp execute_statements(_repo, []), do: :ok

  defp execute_statements(repo, [statement | rest]) do
    statement = if String.ends_with?(statement, ";"), do: statement, else: statement <> ";"

    case repo.query(statement) do
      {:ok, _} ->
        execute_statements(repo, rest)

      {:error, reason} ->
        {:error, {:statement_failed, statement, reason}}
    end
  end
end
