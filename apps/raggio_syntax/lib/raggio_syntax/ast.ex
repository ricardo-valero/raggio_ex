defmodule RaggioSyntax.AST do
  @moduledoc """
  AST structure representing a complete abstract syntax tree.
  """

  defstruct [:root, :metadata]

  @type t :: %__MODULE__{
          root: RaggioSyntax.Node.t(),
          metadata: map()
        }
end
