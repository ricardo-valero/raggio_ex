defmodule Manuable.DataSchema.SheetSchema.SheetDef do
  @moduledoc """
  Represents a complete sheet schema definition.

  A SheetDef describes how to parse a single sheet format, including:
  - Column definitions with positions, headers, and types
  - Optional row range filtering
  - Header detection mode (derived from columns)

  ## Fields

  - `columns` - Map of column name to `ColumnDef`
  - `range` - Optional list of row ranges to parse
  - `name` - Optional identifier for debugging/matching
  - `header_mode` - `:enabled` or `:disabled` (derived from columns)
  - `metadata` - Additional metadata for extensions
  """

  alias Manuable.DataSchema.SheetSchema.ColumnDef

  @type t :: %__MODULE__{
          columns: %{atom() => ColumnDef.t()},
          range: [Range.t()] | nil,
          name: atom() | nil,
          header_mode: :enabled | :disabled,
          metadata: keyword()
        }

  defstruct [
    :columns,
    :range,
    :name,
    :header_mode,
    metadata: []
  ]

  @doc """
  Returns the column names in the schema.
  """
  @spec column_names(t()) :: [atom()]
  def column_names(%__MODULE__{columns: columns}) do
    Map.keys(columns)
  end

  @doc """
  Returns whether this schema requires header detection.
  """
  @spec header_enabled?(t()) :: boolean()
  def header_enabled?(%__MODULE__{header_mode: mode}), do: mode == :enabled

  @doc """
  Returns the column positions for position-only schemas.
  Returns nil if any column lacks a position.
  """
  @spec column_positions(t()) :: [non_neg_integer()] | nil
  def column_positions(%__MODULE__{columns: columns}) do
    positions =
      columns
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map(fn {_, col} -> col.at end)

    if Enum.any?(positions, &is_nil/1), do: nil, else: positions
  end
end
