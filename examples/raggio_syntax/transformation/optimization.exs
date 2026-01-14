# Optimization Example
# Demonstrates optimization patterns using AST transformation

alias RaggioSyntax, as: RS

# Create a schema that could benefit from optimization
schema =
  RS.schema(:analytics_event, [
    RS.field(:id, RS.type(:string)),
    RS.field(:event_name, RS.type(:string)),
    RS.field(:user_id, RS.type(:string)),
    RS.field(:session_id, RS.type(:string)),
    RS.field(:timestamp, RS.type(:datetime)),
    RS.field(:properties, RS.type(:map)),
    RS.field(:metadata, RS.type(:map))
  ])

ast = RS.ast(schema, %{indexed_fields: [], optimized: false})

IO.puts("Original schema:")
IO.puts("  Fields: #{length(RS.get_fields(ast))}")
IO.puts("  Optimized: #{ast.metadata.optimized}")

# Optimization 1: Mark frequently-queried fields for indexing
IO.puts("\nOptimization 1: Mark index candidates")

mark_for_index = fn node ->
  case node do
    %{type: :field, name: name} when name in [:id, :user_id, :session_id, :timestamp] ->
      Map.put(node, :indexed, true)

    other ->
      other
  end
end

optimized_ast1 = RS.transform(ast, mark_for_index)

indexed_fields =
  RS.find_all(optimized_ast1, fn node ->
    node.type == :field && Map.get(node, :indexed) == true
  end)

IO.puts("  Indexed fields: #{length(indexed_fields)}")
Enum.each(indexed_fields, fn field -> IO.puts("    - #{field.name}") end)

# Optimization 2: Add caching hints
IO.puts("\nOptimization 2: Add caching hints")

add_cache_hints = fn node ->
  case node do
    %{type: :field, field_type: %{name: type_name}} when type_name in [:string, :integer] ->
      Map.put(node, :cacheable, true)

    other ->
      other
  end
end

optimized_ast2 = RS.transform(optimized_ast1, add_cache_hints)

cacheable_fields =
  RS.find_all(optimized_ast2, fn node ->
    node.type == :field && Map.get(node, :cacheable) == true
  end)

IO.puts("  Cacheable fields: #{length(cacheable_fields)}")

# Optimization 3: Identify large fields for separate storage
IO.puts("\nOptimization 3: Mark large fields")

mark_large_fields = fn node ->
  case node do
    %{type: :field, field_type: %{name: :map}} ->
      Map.put(node, :storage_strategy, :external)

    other ->
      other
  end
end

optimized_ast3 = RS.transform(optimized_ast2, mark_large_fields)

external_storage_fields =
  RS.find_all(optimized_ast3, fn node ->
    node.type == :field && Map.get(node, :storage_strategy) == :external
  end)

IO.puts("  External storage fields: #{length(external_storage_fields)}")
Enum.each(external_storage_fields, fn field -> IO.puts("    - #{field.name}") end)

# Optimization 4: Update metadata
IO.puts("\nOptimization 4: Update AST metadata")

final_ast = %{
  optimized_ast3
  | metadata:
      Map.merge(optimized_ast3.metadata, %{
        optimized: true,
        indexed_count: length(indexed_fields),
        cacheable_count: length(cacheable_fields),
        optimization_date: DateTime.utc_now()
      })
}

IO.puts("  Final metadata:")
IO.puts("    Optimized: #{final_ast.metadata.optimized}")
IO.puts("    Indexed fields: #{final_ast.metadata.indexed_count}")
IO.puts("    Cacheable fields: #{final_ast.metadata.cacheable_count}")

# Verify optimization impact
IO.puts("\nOptimization Summary:")

all_fields = RS.get_fields(final_ast)

optimized_count =
  Enum.count(all_fields, fn field ->
    Map.get(field, :indexed) == true ||
      Map.get(field, :cacheable) == true ||
      Map.get(field, :storage_strategy) == :external
  end)

IO.puts("  Total fields: #{length(all_fields)}")
IO.puts("  Optimized fields: #{optimized_count}")
IO.puts("  Optimization coverage: #{Float.round(optimized_count / length(all_fields) * 100, 1)}%")

IO.puts("\n✓ Optimization patterns complete!")
