defmodule Raggio.BigQuery.AppliedMigration do
  @moduledoc """
  Represents a migration that has been applied to BigQuery.

  This struct is stored in the `_raggio_migrations` tracking table.
  """

  @type t :: %__MODULE__{
          version: String.t(),
          name: String.t(),
          applied_at: DateTime.t() | nil,
          checksum: String.t() | nil,
          execution_time_ms: integer() | nil,
          direction: :up | :down
        }

  @enforce_keys [:version, :name]
  defstruct [:version, :name, :applied_at, :checksum, :execution_time_ms, direction: :up]
end
