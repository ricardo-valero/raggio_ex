defmodule RaggioSyntax.AST do
  @moduledoc """
  Syntax tree structure.
  """

  defstruct [:root, metadata: %{}]

  @type t :: %__MODULE__{
          root: RaggioSyntax.Node.Any.t(),
          metadata: map()
        }
end
