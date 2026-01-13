defmodule Raggio.Syntax.Traversal do
  @moduledoc """
  Advanced traversal functions for syntax trees.
  """

  alias Raggio.Syntax.{Tree, Node.Behaviour}

  def traverse_breadth_first(tree_or_node, visitor_fn) when is_function(visitor_fn, 1) do
    root = get_root(tree_or_node)
    do_breadth_first([root], visitor_fn)
    :ok
  end

  defp do_breadth_first([], _visitor_fn), do: :ok

  defp do_breadth_first(nodes, visitor_fn) do
    Enum.each(nodes, visitor_fn)

    next_level =
      nodes
      |> Enum.flat_map(&Behaviour.children/1)

    do_breadth_first(next_level, visitor_fn)
  end

  defp get_root(%Tree{root: root}), do: root
  defp get_root(node), do: node
end
