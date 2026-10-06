defmodule Manuable.DataSchema.SheetSchema.Union do
  @moduledoc """
  Represents a union of sheet schemas.

  A Union allows parsing to succeed if any of the contained schemas match.
  This is useful when the same data type can appear in multiple formats.

  ## Matching Strategy

  - `:first_match` (default) - Returns the result of the first matching schema
  - `:exact_one` - Requires exactly one schema to match; errors if multiple match

  ## Example

      union([
        sheet(%{tracking: [at: 2, header: "Guia", type: string()]}),
        sheet(%{tracking: [at: 2, header: "guia", type: string()]})
      ])

  ## Fields

  - `schemas` - List of SheetDef schemas to try
  - `strategy` - Matching strategy (`:first_match` or `:exact_one`)
  """

  alias Manuable.DataSchema.SheetSchema.SheetDef

  @type strategy :: :first_match | :exact_one

  @type t :: %__MODULE__{
          schemas: [SheetDef.t()],
          strategy: strategy()
        }

  defstruct schemas: [],
            strategy: :first_match

  @doc """
  Returns the number of schemas in the union.
  """
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{schemas: schemas}), do: length(schemas)

  @doc """
  Returns the schema names (for debugging).
  """
  @spec schema_names(t()) :: [atom() | nil]
  def schema_names(%__MODULE__{schemas: schemas}) do
    Enum.map(schemas, & &1.name)
  end
end
