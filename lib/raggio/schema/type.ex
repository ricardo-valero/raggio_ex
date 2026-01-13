defmodule Raggio.Schema.Type do
  @moduledoc """
  Internal struct representing a schema type definition.
  """

  @type t :: %__MODULE__{
          kind: atom(),
          constraints: keyword(),
          inner: t() | nil,
          fields: [{atom(), t()}] | nil,
          elements: [t()] | nil,
          key_type: t() | nil,
          value_type: t() | nil,
          values: [any()] | nil,
          optional: boolean(),
          nullable: boolean(),
          default: any(),
          metadata: map()
        }

  defstruct kind: nil,
            constraints: [],
            inner: nil,
            fields: nil,
            elements: nil,
            key_type: nil,
            value_type: nil,
            values: nil,
            optional: false,
            nullable: false,
            default: nil,
            metadata: %{}
end
