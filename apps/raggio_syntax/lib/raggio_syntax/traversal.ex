defmodule RaggioSyntax.Traversal do
  @moduledoc """
  Traversal functions for AST navigation.
  """

  alias RaggioSyntax.Node.{Field, Schema, Type}
  alias RaggioSyntax.AST

  @doc """
  Traverse AST depth-first, applying visitor function to each node.
  """
  def traverse(%AST{root: root}, visitor), do: traverse(root, visitor)

  def traverse(node, visitor) when is_function(visitor, 1) do
    visitor.(node)

    case node do
      %Schema{fields: fields} ->
        Enum.each(fields, &traverse(&1, visitor))

      %Field{field_type: type} ->
        traverse(type, visitor)

      %Type{parameters: params} ->
        Enum.each(params, &traverse(&1, visitor))

      _ ->
        nil
    end

    node
  end

  @doc """
  Traverse AST with accumulator.
  """
  def traverse(%AST{root: root}, acc, visitor), do: traverse(root, acc, visitor)

  def traverse(node, acc, visitor) when is_function(visitor, 2) do
    {action, new_acc} = visitor.(node, acc)

    case action do
      :halt ->
        new_acc

      :continue ->
        case node do
          %Schema{fields: fields} ->
            Enum.reduce(fields, new_acc, fn field, acc ->
              traverse(field, acc, visitor)
            end)

          %Field{field_type: type} ->
            traverse(type, new_acc, visitor)

          %Type{parameters: params} ->
            Enum.reduce(params, new_acc, fn param, acc ->
              traverse(param, acc, visitor)
            end)

          _ ->
            new_acc
        end
    end
  end

  @doc """
  Traverse AST breadth-first.
  """
  def traverse_breadth_first(%AST{root: root}, visitor), do: traverse_breadth_first(root, visitor)

  def traverse_breadth_first(node, visitor) when is_function(visitor, 1) do
    queue = :queue.from_list([node])
    do_breadth_first(queue, visitor)
  end

  defp do_breadth_first(queue, visitor) do
    case :queue.out(queue) do
      {{:value, node}, rest} ->
        visitor.(node)

        children =
          case node do
            %Schema{fields: fields} -> fields
            %Field{field_type: type} -> [type]
            %Type{parameters: params} -> params
            _ -> []
          end

        new_queue = Enum.reduce(children, rest, &:queue.in(&1, &2))
        do_breadth_first(new_queue, visitor)

      {:empty, _} ->
        :ok
    end
  end

  @doc """
  Find first node matching predicate.
  """
  def find(%AST{root: root}, predicate), do: find(root, predicate)

  def find(node, predicate) when is_function(predicate, 1) do
    if predicate.(node) do
      node
    else
      children =
        case node do
          %Schema{fields: fields} -> fields
          %Field{field_type: type} -> [type]
          %Type{parameters: params} -> params
          _ -> []
        end

      Enum.find_value(children, &find(&1, predicate))
    end
  end

  @doc """
  Find all nodes matching predicate.
  """
  def find_all(%AST{root: root}, predicate), do: find_all(root, predicate)

  def find_all(node, predicate) when is_function(predicate, 1) do
    current =
      if predicate.(node) do
        [node]
      else
        []
      end

    children =
      case node do
        %Schema{fields: fields} -> fields
        %Field{field_type: type} -> [type]
        %Type{parameters: params} -> params
        _ -> []
      end

    child_results =
      children
      |> Enum.flat_map(&find_all(&1, predicate))

    current ++ child_results
  end
end
