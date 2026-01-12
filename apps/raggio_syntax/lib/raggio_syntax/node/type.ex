defmodule RaggioSyntax.Node.Type do
  @moduledoc """
  TypeNode represents a type annotation.
  """

  defstruct [:type, :name, :parameters, :metadata]

  @type t :: %__MODULE__{
          type: :type,
          name: atom(),
          parameters: [t()],
          metadata: map()
        }
end
