defmodule RaggioSyntax.Node.Transform do
  @moduledoc """
  TransformNode represents a transformation operation.
  """

  defstruct [:type, :operation, :function, :input, :output, :metadata]

  @type t :: %__MODULE__{
          type: :transform,
          operation: atom(),
          function: (any() -> any()),
          input: RaggioSyntax.Node.t() | nil,
          output: RaggioSyntax.Node.Type.t() | nil,
          metadata: map()
        }
end
