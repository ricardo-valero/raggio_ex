defmodule Raggio.Syntax do
  @moduledoc """
  Build and manipulate syntax trees for schema definitions.
  """

  alias Raggio.Syntax.{SchemaNode, FieldNode, TypeNode, Tree, Node.Behaviour}

  def schema(fields) when is_list(fields) do
    %SchemaNode{fields: fields}
  end

  def schema(name, fields) when is_atom(name) and is_list(fields) do
    %SchemaNode{name: name, fields: fields}
  end

  def field(name, type_node) when is_atom(name) do
    %FieldNode{name: name, field_type: type_node}
  end

  def field(name, type_node, opts) when is_atom(name) and is_list(opts) do
    %FieldNode{
      name: name,
      field_type: type_node,
      required: Keyword.get(opts, :required, true),
      default: Keyword.get(opts, :default)
    }
  end

  def type(type_name) when is_atom(type_name) do
    %TypeNode{name: type_name}
  end

  def type(type_name, parameters) when is_atom(type_name) and is_list(parameters) do
    %TypeNode{name: type_name, parameters: parameters}
  end

  def ast(root_node) do
    %Tree{root: root_node}
  end

  def ast(root_node, metadata) when is_map(metadata) do
    %Tree{root: root_node, metadata: metadata}
  end

  def traverse(tree_or_node, visitor_fn) when is_function(visitor_fn, 1) do
    do_traverse(get_root(tree_or_node), visitor_fn)
    :ok
  end

  def traverse(tree_or_node, acc, reducer_fn) when is_function(reducer_fn, 2) do
    do_traverse_acc(get_root(tree_or_node), acc, reducer_fn)
  end

  def find(tree_or_node, predicate) when is_function(predicate, 1) do
    do_find(get_root(tree_or_node), predicate)
  end

  def find_all(tree_or_node, predicate) when is_function(predicate, 1) do
    traverse(tree_or_node, [], fn node, acc ->
      if predicate.(node), do: [node | acc], else: acc
    end)
    |> Enum.reverse()
  end

  def get_fields(%SchemaNode{fields: fields}), do: fields

  def get_field(%SchemaNode{fields: fields}, field_name) do
    Enum.find(fields, fn %FieldNode{name: name} -> name == field_name end)
  end

  def get_children(node), do: Behaviour.children(node)

  defp get_root(%Tree{root: root}), do: root
  defp get_root(node), do: node

  defp do_traverse(node, visitor_fn) do
    visitor_fn.(node)
    Enum.each(Behaviour.children(node), &do_traverse(&1, visitor_fn))
  end

  defp do_traverse_acc(node, acc, reducer_fn) do
    new_acc = reducer_fn.(node, acc)
    Enum.reduce(Behaviour.children(node), new_acc, &do_traverse_acc(&1, &2, reducer_fn))
  end

  defp do_find(node, predicate) do
    if predicate.(node) do
      node
    else
      Enum.find_value(Behaviour.children(node), fn child ->
        do_find(child, predicate)
      end)
    end
  end
end
