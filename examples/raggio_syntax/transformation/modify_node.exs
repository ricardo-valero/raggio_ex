# Modify Node Example
# Demonstrates transform function

alias RaggioSyntax, as: RS

# Create a schema
original_schema =
  RS.schema(:user, [
    RS.field(:name, RS.type(:string)),
    RS.field(:email, RS.type(:string)),
    RS.field(:age, RS.type(:integer))
  ])

original_ast = RS.ast(original_schema)

IO.puts("Original AST:")
fields = RS.get_fields(original_ast)
Enum.each(fields, fn field -> IO.puts("  - #{field.name}: #{field.field_type.name}") end)

# Example 1: Add metadata to all field nodes
IO.puts("\nExample 1: Add metadata to all fields")

add_metadata = fn node ->
  case node do
    %{type: :field} = field ->
      Map.put(field, :metadata, %{validated: true, version: "1.0"})

    other ->
      other
  end
end

transformed_ast1 = RS.transform(original_ast, add_metadata)

sample_field = RS.find(transformed_ast1, fn node -> node.type == :field end)
IO.puts("  Sample field metadata: #{inspect(sample_field.metadata)}")

# Example 2: Convert all string types to text types
IO.puts("\nExample 2: Convert string types to text types")

string_to_text = fn node ->
  case node do
    %{type: :type, name: :string} = type_node ->
      %{type_node | name: :text}

    other ->
      other
  end
end

transformed_ast2 = RS.transform(original_ast, string_to_text)

text_types =
  RS.find_all(transformed_ast2, fn node ->
    node.type == :type && node.name == :text
  end)

IO.puts("  Text type nodes: #{length(text_types)}")

# Example 3: Make all fields optional
IO.puts("\nExample 3: Make all fields optional")

make_optional = fn node ->
  case node do
    %{type: :field} = field ->
      Map.put(field, :optional, true)

    other ->
      other
  end
end

transformed_ast3 = RS.transform(original_ast, make_optional)

optional_fields =
  RS.find_all(transformed_ast3, fn node ->
    node.type == :field && Map.get(node, :optional) == true
  end)

IO.puts("  Optional fields: #{length(optional_fields)}")

# Example 4: Composite transformation
IO.puts("\nExample 4: Composite transformation (metadata + optional)")

composite_transform = fn node ->
  case node do
    %{type: :field} = field ->
      field
      |> Map.put(:metadata, %{generated: true})
      |> Map.put(:optional, true)

    other ->
      other
  end
end

transformed_ast4 = RS.transform(original_ast, composite_transform)

sample_field2 = RS.find(transformed_ast4, fn node -> node.type == :field end)

IO.puts("  Sample field optional: #{Map.get(sample_field2, :optional)}")
IO.puts("  Sample field metadata: #{inspect(sample_field2.metadata)}")

IO.puts("\n✓ Node modification complete!")
