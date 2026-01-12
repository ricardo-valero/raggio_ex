defmodule RaggioSyntax.Transformer do
  @moduledoc """
  Transformation functions for AST rewriting.
  """

  alias RaggioSyntax.Node.{Field, Schema, Type}
  alias RaggioSyntax.AST

  @doc """
  Apply transformation to all nodes, producing new AST.
  """
  def transform(%AST{root: root, metadata: metadata}, transformer) do
    %AST{
      root: transform(root, transformer),
      metadata: metadata
    }
  end

  def transform(node, transformer) when is_function(transformer, 1) do
    # Transform the node first
    transformed = transformer.(node)

    # Then recursively transform children
    case transformed do
      %Schema{fields: fields} = schema ->
        %{schema | fields: Enum.map(fields, &transform(&1, transformer))}

      %Field{field_type: type} = field ->
        %{field | field_type: transform(type, transformer)}

      %Type{parameters: params} = type_node ->
        %{type_node | parameters: Enum.map(params, &transform(&1, transformer))}

      other ->
        other
    end
  end

  @doc """
  Filter nodes (remove nodes not matching predicate).
  """
  def filter(%AST{root: root, metadata: metadata}, predicate) do
    %AST{
      root: filter(root, predicate),
      metadata: metadata
    }
  end

  def filter(node, predicate) when is_function(predicate, 1) do
    if predicate.(node) do
      case node do
        %Schema{fields: fields} = schema ->
          filtered_fields =
            fields
            |> Enum.filter(predicate)
            |> Enum.map(&filter(&1, predicate))

          %{schema | fields: filtered_fields}

        %Field{field_type: type} = field ->
          %{field | field_type: filter(type, predicate)}

        %Type{parameters: params} = type_node ->
          filtered_params =
            params
            |> Enum.filter(predicate)
            |> Enum.map(&filter(&1, predicate))

          %{type_node | parameters: filtered_params}

        other ->
          other
      end
    else
      nil
    end
  end

  @doc """
  Replace specific node with replacement.
  """
  def replace(%AST{root: root, metadata: metadata}, target, replacement) do
    %AST{
      root: replace(root, target, replacement),
      metadata: metadata
    }
  end

  def replace(node, target, replacement) do
    if node == target do
      replacement
    else
      case node do
        %Schema{fields: fields} = schema ->
          %{schema | fields: Enum.map(fields, &replace(&1, target, replacement))}

        %Field{field_type: type} = field ->
          %{field | field_type: replace(type, target, replacement)}

        %Type{parameters: params} = type_node ->
          %{type_node | parameters: Enum.map(params, &replace(&1, target, replacement))}

        other ->
          other
      end
    end
  end
end
