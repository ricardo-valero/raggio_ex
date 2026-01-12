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
