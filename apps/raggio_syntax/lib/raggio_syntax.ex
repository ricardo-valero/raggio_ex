defmodule RaggioSyntax do
  @moduledoc """
  Raggio.Syntax - Composable AST construction and manipulation library.

  Provides functions for building, traversing, and transforming abstract syntax trees
  using composable functions instead of macro-based DSLs.

  ## Example

      # Build an AST
      user_schema = RaggioSyntax.schema(:user, [
        RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
        RaggioSyntax.field(:age, RaggioSyntax.type(:integer), required: true)
      ])

      # Traverse the AST
      RaggioSyntax.traverse(user_schema, fn node ->
        IO.inspect(node.type)
      end)

      # Transform the AST
      RaggioSyntax.transform(user_schema, fn
        %RaggioSyntax.Node.Field{} = field -> %{field | required: true}
        other -> other
      end)
  """

  alias RaggioSyntax.AST
  alias RaggioSyntax.Node.{Field, Schema, Type, Transform}

  # Node Construction Functions

  @doc """
  Create a field node.
  """
  def field(name, type) when is_atom(name) do
    %Field{
      type: :field,
      name: name,
      field_type: type,
      required: false,
      default: nil,
      metadata: %{}
    }
  end

  @doc """
  Create a field node with options.
  """
  def field(name, type, opts) when is_atom(name) and is_list(opts) do
    %Field{
      type: :field,
      name: name,
      field_type: type,
      required: Keyword.get(opts, :required, false),
      default: Keyword.get(opts, :default),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Create a schema node from a list of fields.
  """
  def schema(fields) when is_list(fields) do
    %Schema{
      type: :schema,
      name: nil,
      fields: fields,
      schema_type: :struct,
      metadata: %{}
    }
  end

  @doc """
  Create a named schema node.
  """
  def schema(name, fields) when is_atom(name) and is_list(fields) do
    %Schema{
      type: :schema,
      name: name,
      fields: fields,
      schema_type: :struct,
      metadata: %{}
    }
  end

  @doc """
  Create a simple type node.
  """
  def type(name) when is_atom(name) do
    %Type{
      type: :type,
      name: name,
      parameters: [],
      metadata: %{}
    }
  end

  @doc """
  Create a generic type node with parameters.
  """
  def type(name, parameters) when is_atom(name) and is_list(parameters) do
    %Type{
      type: :type,
      name: name,
      parameters: parameters,
      metadata: %{}
    }
  end

  @doc """
  Create a transformation node.
  """
  def transform_node(operation, function) when is_atom(operation) and is_function(function) do
    %Transform{
      type: :transform,
      operation: operation,
      function: function,
      input: nil,
      output: nil,
      metadata: %{}
    }
  end

  # AST Construction Functions

  @doc """
  Create an AST from a root node.
  """
  def ast(root) do
    %AST{
      root: root,
      metadata: %{}
    }
  end

  @doc """
  Create an AST with metadata.
  """
  def ast(root, metadata) when is_map(metadata) do
    %AST{
      root: root,
      metadata: metadata
    }
  end

  # Traversal Functions (delegated to Traversal module)

  @doc """
  Traverse AST depth-first, applying visitor function to each node.
  """
  defdelegate traverse(node, visitor), to: RaggioSyntax.Traversal

  @doc """
  Traverse AST with accumulator.
  """
  defdelegate traverse(node, acc, visitor), to: RaggioSyntax.Traversal

  @doc """
  Traverse AST breadth-first.
  """
  defdelegate traverse_breadth_first(node, visitor), to: RaggioSyntax.Traversal

  @doc """
  Find first node matching predicate.
  """
  defdelegate find(node, predicate), to: RaggioSyntax.Traversal

  @doc """
  Find all nodes matching predicate.
  """
  defdelegate find_all(node, predicate), to: RaggioSyntax.Traversal

  # Transformation Functions (delegated to Transformer module)

  @doc """
  Apply transformation to all nodes, producing new AST.
  """
  defdelegate transform(node, transformer), to: RaggioSyntax.Transformer

  @doc """
  Map function over all nodes (alias for transform).
  """
  def map(node, mapper), do: transform(node, mapper)

  @doc """
  Filter nodes (remove nodes not matching predicate).
  """
  defdelegate filter(node, predicate), to: RaggioSyntax.Transformer

  @doc """
  Replace specific node with replacement.
  """
  defdelegate replace(node, target, replacement), to: RaggioSyntax.Transformer

  # Query Functions

  @doc """
  Extract all field nodes from schema.
  """
  def get_fields(%AST{root: root}), do: get_fields(root)
  def get_fields(%Schema{fields: fields}), do: fields
  def get_fields(_), do: []

  @doc """
  Get specific field by name.
  """
  def get_field(%AST{root: root}, name), do: get_field(root, name)

  def get_field(%Schema{fields: fields}, name) when is_atom(name) do
    Enum.find(fields, fn
      %Field{name: ^name} -> true
      _ -> false
    end)
  end

  def get_field(_, _), do: nil

  @doc """
  Get type of node.
  """
  def get_type(%{type: type}), do: type
  def get_type(_), do: nil

  @doc """
  Get immediate children of node.
  """
  def get_children(%AST{root: root}), do: get_children(root)
  def get_children(%Schema{fields: fields}), do: fields
  def get_children(%Field{field_type: type}), do: [type]
  def get_children(%Type{parameters: params}), do: params
  def get_children(_), do: []

  # Validation Functions

  @doc """
  Check if AST structure is valid.
  """
  def valid?(node) do
    case validate(node) do
      :ok -> true
      {:error, _} -> false
    end
  end

  @doc """
  Validate AST structure with detailed errors.
  """
  def validate(%AST{root: root}) do
    validate(root)
  end

  def validate(%Schema{fields: fields}) when is_list(fields) do
    if Enum.all?(fields, &match?(%Field{}, &1)) do
      :ok
    else
      {:error, ["Schema fields must be FieldNode structs"]}
    end
  end

  def validate(%Field{name: name, field_type: type}) do
    cond do
      not is_atom(name) ->
        {:error, ["Field name must be an atom"]}

      not is_struct(type, Type) ->
        {:error, ["Field type must be a TypeNode"]}

      true ->
        :ok
    end
  end

  def validate(%Type{name: name}) do
    if is_atom(name) do
      :ok
    else
      {:error, ["Type name must be an atom"]}
    end
  end

  def validate(_), do: :ok

  # Composition Functions

  @doc """
  Merge two schema nodes.
  """
  def merge(%Schema{} = schema1, %Schema{} = schema2) do
    %Schema{
      type: :schema,
      name: schema1.name || schema2.name,
      fields: schema1.fields ++ schema2.fields,
      schema_type: schema1.schema_type,
      metadata: Map.merge(schema1.metadata, schema2.metadata)
    }
  end

  @doc """
  Compose multiple schemas into one.
  """
  def compose(schemas) when is_list(schemas) do
    Enum.reduce(
      schemas,
      %Schema{type: :schema, fields: [], schema_type: :struct, metadata: %{}},
      &merge/2
    )
  end
end
