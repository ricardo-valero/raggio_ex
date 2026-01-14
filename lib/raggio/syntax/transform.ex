defmodule Raggio.Syntax.Transform do
  @moduledoc """
  Transformation utilities for syntax trees.
  """

  alias Raggio.Syntax.{Tree, SchemaNode, FieldNode, TypeNode}

  def transform(%Tree{root: root} = tree, transformer_fn) do
    %{tree | root: do_transform(root, transformer_fn)}
  end

  def transform(node, transformer_fn) do
    do_transform(node, transformer_fn)
  end

  def filter(%Tree{root: root} = tree, predicate) do
    %{tree | root: do_filter(root, predicate)}
  end

  def filter(node, predicate) do
    do_filter(node, predicate)
  end

  def replace(%Tree{root: root} = tree, target, replacement) do
    %{tree | root: do_replace(root, target, replacement)}
  end

  def replace(node, target, replacement) do
    do_replace(node, target, replacement)
  end

  defp do_transform(%SchemaNode{fields: fields} = node, transformer_fn) do
    transformed = transformer_fn.(node)
    new_fields = Enum.map(fields, &do_transform(&1, transformer_fn))
    %{transformed | fields: new_fields}
  end

  defp do_transform(%FieldNode{field_type: field_type} = node, transformer_fn) do
    transformed = transformer_fn.(node)
    new_type = do_transform(field_type, transformer_fn)
    %{transformed | field_type: new_type}
  end

  defp do_transform(%TypeNode{parameters: nil} = node, transformer_fn) do
    transformer_fn.(node)
  end

  defp do_transform(%TypeNode{parameters: params} = node, transformer_fn) do
    transformed = transformer_fn.(node)
    new_params = Enum.map(params, &do_transform(&1, transformer_fn))
    %{transformed | parameters: new_params}
  end

  defp do_filter(%SchemaNode{fields: fields} = node, predicate) do
    if predicate.(node) do
      new_fields =
        fields
        |> Enum.filter(predicate)
        |> Enum.map(&do_filter(&1, predicate))

      %{node | fields: new_fields}
    else
      nil
    end
  end

  defp do_filter(%FieldNode{} = node, predicate) do
    if predicate.(node), do: node, else: nil
  end

  defp do_filter(%TypeNode{} = node, predicate) do
    if predicate.(node), do: node, else: nil
  end

  defp do_replace(node, target, replacement) when node == target do
    replacement
  end

  defp do_replace(%SchemaNode{fields: fields} = node, target, replacement) do
    new_fields = Enum.map(fields, &do_replace(&1, target, replacement))
    %{node | fields: new_fields}
  end

  defp do_replace(%FieldNode{field_type: field_type} = node, target, replacement) do
    new_type = do_replace(field_type, target, replacement)
    %{node | field_type: new_type}
  end

  defp do_replace(%TypeNode{parameters: nil} = node, _target, _replacement) do
    node
  end

  defp do_replace(%TypeNode{parameters: params} = node, target, replacement) do
    new_params = Enum.map(params, &do_replace(&1, target, replacement))
    %{node | parameters: new_params}
  end
end
