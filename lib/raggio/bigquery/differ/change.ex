defmodule Raggio.BigQuery.Differ.Change do
  @moduledoc """
  Represents a schema change detected between local and remote BigQuery schemas.

  Changes are categorized by type and carry all information needed to generate
  DDL statements or display to users.

  ## Change Types

  | Type | Description | Reversible |
  |------|-------------|------------|
  | `:add_column` | New column in local schema | Yes (DROP) |
  | `:drop_column` | Column removed from local | Yes (ADD) |
  | `:rename_column` | Column renamed | Yes (reverse rename) |
  | `:change_type` | Column type changed | Limited |
  | `:change_mode` | NULLABLE/REQUIRED changed | Limited |
  | `:change_description` | Column description changed | Yes |
  | `:create_table` | Table doesn't exist remotely | Yes (DROP) |
  | `:drop_table` | Table removed from local | Yes (CREATE) |
  """

  @type change_type ::
          :add_column
          | :drop_column
          | :rename_column
          | :change_type
          | :change_mode
          | :change_description
          | :create_table
          | :drop_table

  @type t :: %__MODULE__{
          type: change_type(),
          table: String.t(),
          column: String.t() | nil,
          details: map(),
          destructive: boolean()
        }

  @enforce_keys [:type, :table]
  defstruct [:type, :table, :column, details: %{}, destructive: false]

  @spec new(change_type(), String.t(), keyword()) :: t()
  def new(type, table, opts \\ []) do
    %__MODULE__{
      type: type,
      table: table,
      column: Keyword.get(opts, :column),
      details: Keyword.get(opts, :details, %{}),
      destructive: Keyword.get(opts, :destructive, destructive_by_default?(type))
    }
  end

  @spec destructive_by_default?(change_type()) :: boolean()
  def destructive_by_default?(:drop_column), do: true
  def destructive_by_default?(:drop_table), do: true
  def destructive_by_default?(:change_type), do: true
  def destructive_by_default?(_), do: false

  @spec reversible?(t()) :: boolean()
  def reversible?(%__MODULE__{type: :add_column}), do: true
  def reversible?(%__MODULE__{type: :drop_column}), do: true
  def reversible?(%__MODULE__{type: :rename_column}), do: true
  def reversible?(%__MODULE__{type: :change_description}), do: true
  def reversible?(%__MODULE__{type: :create_table}), do: true

  def reversible?(%__MODULE__{type: :drop_table, details: details}) do
    Map.has_key?(details, :schema)
  end

  def reversible?(%__MODULE__{type: :change_type}), do: false

  def reversible?(%__MODULE__{type: :change_mode, details: %{from: "NULLABLE", to: "REQUIRED"}}),
    do: false

  def reversible?(%__MODULE__{type: :change_mode}), do: true
  def reversible?(_), do: false

  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{type: :add_column, table: table, column: column, details: details}) do
    type = Map.get(details, :bq_type, "?")
    mode = Map.get(details, :mode, "NULLABLE")
    "Add column #{column} (#{type}, #{mode}) to #{table}"
  end

  def describe(%__MODULE__{type: :drop_column, table: table, column: column}) do
    "Drop column #{column} from #{table}"
  end

  def describe(%__MODULE__{type: :rename_column, table: table, details: %{from: from, to: to}}) do
    "Rename column #{from} to #{to} in #{table}"
  end

  def describe(%__MODULE__{type: :change_type, table: table, column: column, details: details}) do
    from = Map.get(details, :from, "?")
    to = Map.get(details, :to, "?")
    "Change type of #{column} from #{from} to #{to} in #{table}"
  end

  def describe(%__MODULE__{type: :change_mode, table: table, column: column, details: details}) do
    from = Map.get(details, :from, "?")
    to = Map.get(details, :to, "?")
    "Change mode of #{column} from #{from} to #{to} in #{table}"
  end

  def describe(%__MODULE__{type: :change_description, table: table, column: column}) do
    "Update description of #{column} in #{table}"
  end

  def describe(%__MODULE__{type: :create_table, table: table}) do
    "Create table #{table}"
  end

  def describe(%__MODULE__{type: :drop_table, table: table}) do
    "Drop table #{table}"
  end

  def describe(%__MODULE__{type: type, table: table}) do
    "#{type} on #{table}"
  end

  @spec sort([t()]) :: [t()]
  def sort(changes) do
    Enum.sort_by(changes, &execution_order/1)
  end

  defp execution_order(%__MODULE__{type: :create_table}), do: 0
  defp execution_order(%__MODULE__{type: :add_column}), do: 1
  defp execution_order(%__MODULE__{type: :change_description}), do: 2
  defp execution_order(%__MODULE__{type: :change_mode}), do: 3
  defp execution_order(%__MODULE__{type: :change_type}), do: 4
  defp execution_order(%__MODULE__{type: :rename_column}), do: 5
  defp execution_order(%__MODULE__{type: :drop_column}), do: 6
  defp execution_order(%__MODULE__{type: :drop_table}), do: 7
  defp execution_order(_), do: 99
end
