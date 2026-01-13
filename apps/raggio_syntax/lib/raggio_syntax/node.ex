defprotocol RaggioSyntax.Node do
  @moduledoc """
  Protocol for syntax tree nodes.
  """

  @doc "Returns the node type as an atom"
  def node_type(node)

  @doc "Returns the immediate children of this node"
  def children(node)
end

defmodule RaggioSyntax.Node.Any do
  @moduledoc """
  Type union for all node types.
  """

  @type t ::
          RaggioSyntax.Node.Field.t()
          | RaggioSyntax.Node.Schema.t()
          | RaggioSyntax.Node.Type.t()
          | RaggioSyntax.Node.Transform.t()
end
