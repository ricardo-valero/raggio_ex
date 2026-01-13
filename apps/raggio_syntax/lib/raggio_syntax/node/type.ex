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

defimpl RaggioSyntax.Node, for: RaggioSyntax.Node.Type do
  @doc """
  Returns :type as the node type.
  """
  def node_type(_node), do: :type

  @doc """
  Returns the type parameters as children.
  """
  def children(%RaggioSyntax.Node.Type{parameters: params}) when is_list(params), do: params
  def children(_), do: []
end
