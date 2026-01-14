defmodule Raggio.Syntax.Node do
  @moduledoc """
  Protocol for syntax tree nodes enabling polymorphic traversal.
  """

  @type t :: SchemaNode.t() | FieldNode.t() | TypeNode.t()

  defprotocol Behaviour do
    @spec node_type(t) :: atom()
    def node_type(node)

    @spec children(t) :: [t]
    def children(node)
  end
end

defmodule Raggio.Syntax.SchemaNode do
  @moduledoc """
  Represents a schema definition in the syntax tree.
  """

  @type t :: %__MODULE__{
          type: :schema,
          name: atom() | nil,
          fields: [Raggio.Syntax.FieldNode.t()],
          metadata: map()
        }

  defstruct type: :schema,
            name: nil,
            fields: [],
            metadata: %{}

  defimpl Raggio.Syntax.Node.Behaviour do
    def node_type(_), do: :schema
    def children(%{fields: fields}), do: fields
  end
end

defmodule Raggio.Syntax.FieldNode do
  @moduledoc """
  Represents a field definition in a schema.
  """

  @type t :: %__MODULE__{
          type: :field,
          name: atom(),
          field_type: Raggio.Syntax.TypeNode.t(),
          required: boolean(),
          default: any(),
          metadata: map()
        }

  defstruct type: :field,
            name: nil,
            field_type: nil,
            required: true,
            default: nil,
            metadata: %{}

  defimpl Raggio.Syntax.Node.Behaviour do
    def node_type(_), do: :field
    def children(%{field_type: field_type}), do: [field_type]
  end
end

defmodule Raggio.Syntax.TypeNode do
  @moduledoc """
  Represents a type reference in a field definition.
  """

  @type t :: %__MODULE__{
          type: :type,
          name: atom(),
          parameters: [t()] | nil,
          metadata: map()
        }

  defstruct type: :type,
            name: nil,
            parameters: nil,
            metadata: %{}

  defimpl Raggio.Syntax.Node.Behaviour do
    def node_type(_), do: :type
    def children(%{parameters: nil}), do: []
    def children(%{parameters: params}), do: params
  end
end

defmodule Raggio.Syntax.Tree do
  @moduledoc """
  Wrapper for a complete syntax tree with metadata.
  """

  @type t :: %__MODULE__{
          root: Raggio.Syntax.Node.t(),
          metadata: map()
        }

  defstruct root: nil,
            metadata: %{}
end
