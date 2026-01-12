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
