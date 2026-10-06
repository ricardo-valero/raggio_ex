defmodule Manuable.DataSchema.SheetSchema.ColumnDef do
  @moduledoc """
  Represents a single column definition within a sheet schema.

  A ColumnDef specifies how to locate and parse a column in tabular data:
  - Position via `:at` (0-based column index)
  - Header text via `:header` (exact string match)
  - Type definition via `:type` (from DataSchema.Builders)

  ## Rules

  - At least one of `:at` or `:header` must be specified
  - If both are specified, both must match for header detection
  - If only `:header` is specified, position is discovered at runtime

  ## Fields

  - `name` - The atom key for this column in the output map
  - `at` - 0-based column index (nil if position-agnostic)
  - `header` - Expected header text (nil for header-less parsing)
  - `type` - TypeDef from DataSchema.Builders
  - `optional` - Whether this column can be missing (default: false)
  """

  alias Manuable.DataSchema.Builders.TypeDef

  @type t :: %__MODULE__{
          name: atom(),
          at: non_neg_integer() | nil,
          header: String.t() | nil,
          type: TypeDef.t(),
          optional: boolean()
        }

  defstruct [
    :name,
    :at,
    :header,
    :type,
    optional: false
  ]

  @doc """
  Returns whether this column has a fixed position.
  """
  @spec has_position?(t()) :: boolean()
  def has_position?(%__MODULE__{at: at}), do: not is_nil(at)

  @doc """
  Returns whether this column uses header detection.
  """
  @spec has_header?(t()) :: boolean()
  def has_header?(%__MODULE__{header: header}), do: not is_nil(header)

  @doc """
  Returns whether this column definition is valid.
  A column must have at least :at or :header specified.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{at: at, header: header}) do
    not (is_nil(at) and is_nil(header))
  end
end
