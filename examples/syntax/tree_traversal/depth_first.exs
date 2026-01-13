alias Raggio.Syntax

IO.puts("=== Depth-First Tree Traversal ===\n")

schema =
  Syntax.schema(:order, [
    Syntax.field(:id, Syntax.type(:string)),
    Syntax.field(:items, Syntax.type(:list, [Syntax.type(:string)])),
    Syntax.field(:total, Syntax.type(:decimal))
  ])

tree = Syntax.ast(schema, %{created_at: DateTime.utc_now()})

IO.puts("Tree metadata: #{inspect(tree.metadata)}")
IO.puts("\n--- Visiting all nodes (depth-first) ---")

Syntax.traverse(tree, fn node ->
  type = Raggio.Syntax.Node.Behaviour.node_type(node)
  IO.puts("Visited: #{type}")
end)

IO.puts("\n--- Counting nodes by type ---")

counts =
  Syntax.traverse(tree, %{}, fn node, acc ->
    type = Raggio.Syntax.Node.Behaviour.node_type(node)
    Map.update(acc, type, 1, &(&1 + 1))
  end)

IO.puts("Node counts: #{inspect(counts)}")

IO.puts("\n--- Finding specific field ---")

total_field =
  Syntax.find(tree, fn node ->
    Raggio.Syntax.Node.Behaviour.node_type(node) == :field and
      Map.get(node, :name) == :total
  end)

IO.puts(
  "Found :total field: #{inspect(total_field.name)} -> #{inspect(total_field.field_type.name)}"
)

IO.puts("\n--- Finding all type nodes ---")

type_nodes =
  Syntax.find_all(tree, fn node ->
    Raggio.Syntax.Node.Behaviour.node_type(node) == :type
  end)

IO.puts("Type nodes found: #{length(type_nodes)}")
Enum.each(type_nodes, fn t -> IO.puts("  - #{t.name}") end)
