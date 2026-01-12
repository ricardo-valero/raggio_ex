# Depth-First Traversal Example
# Demonstrates DFS traversal per data-model.md

alias RaggioSyntax, as: RS

# Create a nested schema to traverse
profile_schema =
  RS.schema(:profile, [
    RS.field(:name, RS.type(:string)),
    RS.field(:bio, RS.type(:string))
  ])

user_schema =
  RS.schema(:user, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:profile, RS.type(:schema, [profile_schema])),
    RS.field(:tags, RS.type(:array))
  ])

user_ast = RS.ast(user_schema)

IO.puts("Traversing AST in depth-first order:\n")

# Example 1: Simple visitor that prints node types
IO.puts("Example 1: Print all node types")

RS.traverse(user_ast, fn node ->
  IO.puts("  Visited: #{node.type}")
end)

# Example 2: Collect all node types
IO.puts("\nExample 2: Collect node types with accumulator")

collected_types =
  RS.traverse(user_ast, [], fn node, acc ->
    {:continue, [node.type | acc]}
  end)

IO.puts("Collected types (reverse order): #{inspect(Enum.reverse(collected_types))}")

# Example 3: Count nodes by type
IO.puts("\nExample 3: Count nodes by type")

node_counts =
  RS.traverse(user_ast, %{}, fn node, acc ->
    {:continue, Map.update(acc, node.type, 1, &(&1 + 1))}
  end)

IO.puts("Node counts: #{inspect(node_counts)}")

# Example 4: Early termination
IO.puts("\nExample 4: Early termination on first field")

result =
  RS.traverse(user_ast, nil, fn node, _acc ->
    if node.type == :field do
      {:halt, node}
    else
      {:continue, nil}
    end
  end)

IO.puts("Found first field: #{inspect(result.name)}")

IO.puts("\n✓ Depth-first traversal complete!")
