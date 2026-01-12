defmodule RaggioSyntax.Node do
  @moduledoc """
  Base node protocol for AST nodes.
  """

  @type t ::
          RaggioSyntax.Node.Field.t()
          | RaggioSyntax.Node.Schema.t()
          | RaggioSyntax.Node.Type.t()
          | RaggioSyntax.Node.Transform.t()
end
