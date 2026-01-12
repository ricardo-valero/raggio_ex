# Filtering Example
# Demonstrates find/find_all usage

alias RaggioSyntax, as: RS

# Create a complex schema
schema =
  RS.schema(:order, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:customer_name, RS.type(:string)),
    RS.field(:total_amount, RS.type(:decimal)),
    RS.field(:status, RS.type(:string)),
    RS.field(:items, RS.type(:array)),
    RS.field(:created_at, RS.type(:datetime)),
    RS.field(:updated_at, RS.type(:datetime))
  ])

ast = RS.ast(schema)

IO.puts("Demonstrating find/find_all operations:\n")

# Example 1: Find first field
IO.puts("Example 1: Find first field node")
first_field = RS.find(ast, fn node -> node.type == :field end)

if first_field do
  IO.puts("  Found: #{first_field.name}")
end

# Example 2: Find specific field by name
IO.puts("\nExample 2: Find field with name :total_amount")

total_amount_field =
  RS.find(ast, fn node ->
    node.type == :field && node.name == :total_amount
  end)

if total_amount_field do
  IO.puts("  Found: #{total_amount_field.name}")
  IO.puts("  Type: #{total_amount_field.field_type.name}")
end

# Example 3: Find all fields
IO.puts("\nExample 3: Find all field nodes")
all_fields = RS.find_all(ast, fn node -> node.type == :field end)
IO.puts("  Total fields: #{length(all_fields)}")

Enum.each(all_fields, fn field ->
  IO.puts("    - #{field.name}")
end)

# Example 4: Find all datetime types
IO.puts("\nExample 4: Find all datetime type nodes")

datetime_types =
  RS.find_all(ast, fn node ->
    node.type == :type && node.name == :datetime
  end)

IO.puts("  Datetime types found: #{length(datetime_types)}")

# Example 5: Find fields with specific type
IO.puts("\nExample 5: Find all string fields")

string_fields =
  RS.find_all(ast, fn node ->
    node.type == :field && node.field_type.name == :string
  end)

IO.puts("  String fields:")

Enum.each(string_fields, fn field ->
  IO.puts("    - #{field.name}")
end)

# Example 6: Complex predicate
IO.puts("\nExample 6: Find fields with names containing 'at'")

at_fields =
  RS.find_all(ast, fn node ->
    if node.type == :field do
      String.contains?(to_string(node.name), "at")
    else
      false
    end
  end)

IO.puts("  Fields with 'at': #{inspect(Enum.map(at_fields, & &1.name))}")

IO.puts("\n✓ Filtering operations complete!")
