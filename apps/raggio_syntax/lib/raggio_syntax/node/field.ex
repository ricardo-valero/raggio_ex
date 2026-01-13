defmodule RaggioSyntax.Node.Field do
  @moduledoc """
  FieldNode represents a field in a schema.
  """

  defstruct [:type, :name, :field_type, :required, :default, :metadata]

  @type t :: %__MODULE__{
          type: :field,
          name: atom(),
          field_type: RaggioSyntax.Node.Type.t(),
          required: boolean(),
          default: any(),
          metadata: map()
        }
end

defimpl RaggioSyntax.Node, for: RaggioSyntax.Node.Field do
  @doc """
  Returns :field as the node type.
  """
  def node_type(_node), do: :field

  @doc """
  Returns the field_type as the single child.
  """
  def children(%RaggioSyntax.Node.Field{field_type: field_type}) when not is_nil(field_type) do
    [field_type]
  end

  def children(_), do: []
end
