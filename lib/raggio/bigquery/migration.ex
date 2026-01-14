defmodule Raggio.BigQuery.Migration do
  @moduledoc """
  Represents a BigQuery schema migration.

  Migrations are stored as directories containing `up.sql` and `down.sql` files.

  ## Structure

      priv/raggio/bigquery/
      └── billing/                           # dataset
          └── 20260108120000_add_status/     # version_name
              ├── up.sql                     # forward migration
              └── down.sql                   # rollback migration
  """

  @type t :: %__MODULE__{
          version: String.t(),
          name: String.t(),
          dataset: String.t() | nil,
          up_sql: String.t() | nil,
          down_sql: String.t() | nil,
          checksum: String.t() | nil,
          applied_at: DateTime.t() | nil
        }

  @enforce_keys [:version, :name]
  defstruct [:version, :name, :dataset, :up_sql, :down_sql, :checksum, :applied_at]

  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(version, name, opts \\ []) do
    %__MODULE__{
      version: version,
      name: name,
      dataset: Keyword.get(opts, :dataset),
      up_sql: Keyword.get(opts, :up_sql),
      down_sql: Keyword.get(opts, :down_sql),
      applied_at: Keyword.get(opts, :applied_at)
    }
  end

  @spec from_filename(String.t()) :: {:ok, t()} | {:error, :invalid_format}
  def from_filename(filename) do
    case Regex.run(~r/^(\d{14})_(.+)$/, filename) do
      [_, version, name] ->
        {:ok, new(version, name)}

      nil ->
        {:error, :invalid_format}
    end
  end

  @spec full_name(t()) :: String.t()
  def full_name(%__MODULE__{version: version, name: name}) do
    "#{version}_#{name}"
  end

  @spec compare(t(), t()) :: :lt | :eq | :gt
  def compare(%__MODULE__{version: v1}, %__MODULE__{version: v2}) do
    cond do
      v1 < v2 -> :lt
      v1 > v2 -> :gt
      true -> :eq
    end
  end

  @spec directory(t(), String.t()) :: String.t()
  def directory(%__MODULE__{dataset: nil}, base_path), do: base_path
  def directory(%__MODULE__{dataset: dataset}, base_path), do: Path.join(base_path, dataset)

  @spec migration_dir(t(), String.t()) :: String.t()
  def migration_dir(migration, base_path) do
    Path.join(directory(migration, base_path), full_name(migration))
  end

  @spec up_path(t(), String.t()) :: String.t()
  def up_path(migration, base_path) do
    Path.join(migration_dir(migration, base_path), "up.sql")
  end

  @spec down_path(t(), String.t()) :: String.t()
  def down_path(migration, base_path) do
    Path.join(migration_dir(migration, base_path), "down.sql")
  end
end
