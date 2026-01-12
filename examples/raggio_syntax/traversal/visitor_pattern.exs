# Visitor Pattern Example
# Demonstrates visitor combinators for traversal

alias RaggioSyntax, as: RS

# Create a schema
schema =
  RS.schema(:blog_post, [
    RS.field(:title, RS.type(:string)),
    RS.field(:content, RS.type(:string)),
    RS.field(:author_id, RS.type(:integer)),
    RS.field(:published_at, RS.type(:datetime)),
    RS.field(:tags, RS.type(:array))
  ])

ast = RS.ast(schema, %{version: "1.0"})

IO.puts("Demonstrating visitor pattern:\n")

# Visitor 1: Field collector
field_visitor = fn node ->
  if node.type == :field do
    IO.puts("  Found field: #{node.name}")
  end
end

IO.puts("Visitor 1: Collecting fields")
RS.traverse(ast, field_visitor)

# Visitor 2: Type analyzer
IO.puts("\nVisitor 2: Analyzing types")

type_visitor = fn node ->
  case node.type do
    :type ->
      IO.puts("  Type node: #{node.name}")

    _ ->
      :ok
  end
end

RS.traverse(ast, type_visitor)

# Visitor 3: Combined visitor with accumulator
IO.puts("\nVisitor 3: Combined analysis")

analysis_visitor = fn node, acc ->
  case node.type do
    :schema ->
      {:continue, Map.put(acc, :schemas, (acc[:schemas] || 0) + 1)}

    :field ->
      field_name = to_string(node.name)
      fields = Map.get(acc, :field_names, [])
      {:continue, Map.put(acc, :field_names, [field_name | fields])}

    :type ->
      type_name = to_string(node.name)
      types = Map.get(acc, :type_usage, %{})
      new_types = Map.update(types, type_name, 1, &(&1 + 1))
      {:continue, Map.put(acc, :type_usage, new_types)}

    _ ->
      {:continue, acc}
  end
end

result = RS.traverse(ast, %{}, analysis_visitor)

IO.puts("Analysis results:")
IO.puts("  Schemas: #{result[:schemas]}")
IO.puts("  Fields: #{inspect(Enum.reverse(result[:field_names] || []))}")
IO.puts("  Type usage: #{inspect(result[:type_usage])}")

IO.puts("\n✓ Visitor pattern complete!")
