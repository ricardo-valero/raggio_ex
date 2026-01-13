defmodule RaggioSyntax.Node.Schema do
  @moduledoc """
  SchemaNode represents a schema definition.
  """

  defstruct [:type, :name, :fields, :schema_type, :metadata]

  @type t :: %__MODULE__{
          type: :schema,
          name: atom() | nil,
          fields: [RaggioSyntax.Node.Field.t()],
          schema_type: atom(),
          metadata: map()
        }
end

defimpl RaggioSyntax.Node, for: RaggioSyntax.Node.Schema do
  @doc """
  Returns :schema as the node type.
  """
  def node_type(_node), do: :schema

  @doc """
  Returns the field nodes as children.
  """
  def children(%RaggioSyntax.Node.Schema{fields: fields}) when is_list(fields), do: fields
  def children(_), do: []
end
