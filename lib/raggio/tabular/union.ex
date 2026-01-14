defmodule Raggio.Tabular.Union do
  @moduledoc """
  Union of multiple SheetSchemas with a matching strategy.

  Allows parsing files that may match one of several schema variants.
  """

  alias Raggio.Tabular.SheetSchema

  @type strategy :: :first_match | :exact_one

  @type t :: %__MODULE__{
          schemas: [SheetSchema.t()],
          strategy: strategy()
        }

  defstruct schemas: [], strategy: :first_match

  @spec new([SheetSchema.t()], keyword()) :: t()
  def new(schemas, opts \\ []) when is_list(schemas) do
    %__MODULE__{
      schemas: schemas,
      strategy: Keyword.get(opts, :strategy, :first_match)
    }
  end
end
