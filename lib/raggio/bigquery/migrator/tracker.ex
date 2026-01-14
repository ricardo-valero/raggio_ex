defmodule Raggio.BigQuery.Migrator.Tracker do
  @moduledoc """
  Tracks applied migrations in the `_raggio_migrations` table.

  Provides functions to:
  - Record when a migration is applied
  - List all applied migrations
  - Check if a migration is already applied
  - Remove migration records on rollback
  - Ensure the tracking table exists

  ## Usage

      # Ensure tracking table exists
      Tracker.ensure_table(repo, "billing")

      # Get applied migrations
      Tracker.list_applied(repo, dataset: "billing")

      # Check if migration is applied
      Tracker.applied?(repo, "20260108120000", dataset: "billing")

      # Record a migration as applied
      Tracker.record_applied(repo, migration, dataset: "billing")

      # Remove a migration record (for rollback)
      Tracker.remove_applied(repo, migration, dataset: "billing")
  """

  alias Raggio.BigQuery.AppliedMigration
  alias Raggio.BigQuery.Migration
  alias Raggio.BigQuery.Telemetry

  @migrations_table "_raggio_migrations"

  @spec migrations_table :: String.t()
  def migrations_table, do: @migrations_table

  @spec ensure_table(module(), String.t()) :: :ok | {:error, term()}
  def ensure_table(repo, dataset) do
    Telemetry.span([:migrator, :tracker, :ensure_table], %{dataset: dataset}, fn ->
      config = repo.config()
      project_id = config[:project_id]
      table_ref = "`#{project_id}.#{dataset}.#{@migrations_table}`"

      create_sql = """
      CREATE TABLE IF NOT EXISTS #{table_ref} (
        version STRING NOT NULL,
        name STRING NOT NULL,
        applied_at TIMESTAMP NOT NULL,
        checksum STRING NOT NULL,
        execution_time_ms INT64,
        direction STRING NOT NULL
      )
      OPTIONS (
        description = 'Raggio BigQuery migration history'
      )
      """

      case repo.query(create_sql) do
        {:ok, _} -> {:ok, :ok}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec record_applied(module(), Migration.t(), keyword()) ::
          {:ok, AppliedMigration.t()} | {:error, term()}
  def record_applied(repo, migration, opts \\ []) do
    dataset = Keyword.get(opts, :dataset, migration.dataset)
    direction = Keyword.get(opts, :direction, :up)
    execution_time_ms = Keyword.get(opts, :execution_time_ms)

    if is_nil(dataset) do
      {:error, :dataset_required}
    else
      do_record_applied(repo, migration, dataset, direction, execution_time_ms)
    end
  end

  defp do_record_applied(repo, migration, dataset, direction, execution_time_ms) do
    Telemetry.span([:migrator, :tracker, :record], %{version: migration.version}, fn ->
      config = repo.config()
      project_id = config[:project_id]
      table_ref = "`#{project_id}.#{dataset}.#{@migrations_table}`"
      checksum = calculate_checksum(migration)
      direction_str = to_string(direction)
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      insert_sql = """
      INSERT INTO #{table_ref} (version, name, applied_at, checksum, execution_time_ms, direction)
      VALUES ('#{migration.version}', '#{migration.name}', '#{now}', '#{checksum}', #{execution_time_ms || "NULL"}, '#{direction_str}')
      """

      case repo.query(insert_sql) do
        {:ok, _} ->
          applied = %AppliedMigration{
            version: migration.version,
            name: migration.name,
            applied_at: DateTime.utc_now(),
            checksum: checksum,
            execution_time_ms: execution_time_ms,
            direction: direction
          }

          {:ok, {:ok, applied}}

        {:error, reason} ->
          {:error, reason}
      end
    end)
    |> case do
      {:ok, {:ok, applied}} -> {:ok, applied}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec remove_applied(module(), Migration.t(), keyword()) :: :ok | {:error, term()}
  def remove_applied(repo, migration, opts \\ []) do
    dataset = Keyword.get(opts, :dataset, migration.dataset)

    if is_nil(dataset) do
      {:error, :dataset_required}
    else
      do_remove_applied(repo, migration, dataset)
    end
  end

  defp do_remove_applied(repo, migration, dataset) do
    Telemetry.span([:migrator, :tracker, :remove], %{version: migration.version}, fn ->
      config = repo.config()
      project_id = config[:project_id]
      table_ref = "`#{project_id}.#{dataset}.#{@migrations_table}`"

      delete_sql = """
      DELETE FROM #{table_ref}
      WHERE version = '#{migration.version}' AND direction = 'up'
      """

      case repo.query(delete_sql) do
        {:ok, _} -> {:ok, :ok}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec list_applied(module(), keyword()) :: {:ok, [AppliedMigration.t()]} | {:error, term()}
  def list_applied(repo, opts \\ []) do
    dataset = Keyword.fetch!(opts, :dataset)
    config = repo.config()
    project_id = config[:project_id]
    table_ref = "`#{project_id}.#{dataset}.#{@migrations_table}`"

    query = """
    SELECT version, name, applied_at, checksum, execution_time_ms, direction
    FROM #{table_ref}
    WHERE direction = 'up'
    ORDER BY version ASC
    """

    case repo.query(query) do
      {:ok, rows} ->
        migrations =
          Enum.map(rows, fn row ->
            %AppliedMigration{
              version: row["version"],
              name: row["name"],
              applied_at: parse_timestamp(row["applied_at"]),
              checksum: row["checksum"],
              execution_time_ms: row["execution_time_ms"],
              direction: :up
            }
          end)

        {:ok, migrations}

      {:error, %{type: :table_not_found}} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec applied?(module(), String.t(), keyword()) :: boolean()
  def applied?(repo, version, opts) do
    case list_applied(repo, opts) do
      {:ok, applied} ->
        Enum.any?(applied, &(&1.version == version))

      {:error, _} ->
        false
    end
  end

  @spec get_latest(module(), keyword()) :: {:ok, AppliedMigration.t() | nil} | {:error, term()}
  def get_latest(repo, opts) do
    case list_applied(repo, opts) do
      {:ok, []} -> {:ok, nil}
      {:ok, applied} -> {:ok, List.last(applied)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_checksum(%Migration{up_sql: up_sql, down_sql: down_sql}) do
    content = (up_sql || "") <> "\n---\n" <> (down_sql || "")
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> nil
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
end
