# Rewrite Rule Example
# Demonstrates AST rewrite patterns

alias RaggioSyntax, as: RS

# Create a schema with various field types
schema =
  RS.schema(:product, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:name, RS.type(:string)),
    RS.field(:description, RS.type(:string)),
    RS.field(:price, RS.type(:decimal)),
    RS.field(:quantity, RS.type(:integer)),
    RS.field(:sku, RS.type(:string))
  ])

ast = RS.ast(schema)

IO.puts("Original schema:")
fields = RS.get_fields(ast)
Enum.each(fields, fn field -> IO.puts("  - #{field.name}: #{field.field_type.name}") end)

# Rewrite Rule 1: Normalize integer types to number
IO.puts("\nRewrite Rule 1: integer → number")

normalize_numbers = fn node ->
  case node do
    %{type: :type, name: :integer} -> %{node | name: :number}
    %{type: :type, name: :decimal} -> %{node | name: :number}
    other -> other
  end
end

rewritten_ast1 = RS.transform(ast, normalize_numbers)

number_types =
  RS.find_all(rewritten_ast1, fn node ->
    node.type == :type && node.name == :number
  end)

IO.puts("  Number types after rewrite: #{length(number_types)}")

# Rewrite Rule 2: Add prefix to all field names
IO.puts("\nRewrite Rule 2: Add 'prod_' prefix to field names")

add_prefix = fn node ->
  case node do
    %{type: :field} = field ->
      new_name = String.to_atom("prod_#{field.name}")
      %{field | name: new_name}

    other ->
      other
  end
end

rewritten_ast2 = RS.transform(ast, add_prefix)
prefixed_fields = RS.get_fields(rewritten_ast2)

IO.puts("  Prefixed fields:")
Enum.each(prefixed_fields, fn field -> IO.puts("    - #{field.name}") end)

# Rewrite Rule 3: Replace specific type
IO.puts("\nRewrite Rule 3: Replace string type nodes")

string_type = RS.find(ast, fn node -> node.type == :type && node.name == :string end)
text_type = RS.type(:text)

rewritten_ast3 = RS.replace(ast, string_type, text_type)

text_count =
  RS.find_all(rewritten_ast3, fn node ->
    node.type == :type && node.name == :text
  end)
  |> length()

IO.puts("  Text type nodes: #{text_count}")

# Rewrite Rule 4: Filter out specific fields
IO.puts("\nRewrite Rule 4: Filter out string fields")

filter_strings = fn node ->
  case node do
    %{type: :field, field_type: %{name: :string}} -> false
    _ -> true
  end
end

filtered_ast = RS.filter(ast, filter_strings)

if filtered_ast do
  remaining_fields = RS.get_fields(filtered_ast)
  IO.puts("  Remaining fields: #{length(remaining_fields)}")
  Enum.each(remaining_fields, fn field -> IO.puts("    - #{field.name}") end)
end

IO.puts("\n✓ Rewrite rules complete!")
