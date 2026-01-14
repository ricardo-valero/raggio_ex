# Node Composition Example
# Demonstrates composing nodes incrementally

alias RaggioSyntax, as: RS

# Scenario: Building a product catalog schema incrementally

IO.puts("Building a product catalog schema step by step...\n")

# Step 1: Start with basic product fields
basic_fields = [
  RS.field(:id, RS.type(:integer)),
  RS.field(:name, RS.type(:string)),
  RS.field(:price, RS.type(:decimal))
]

basic_product = RS.schema(:product, basic_fields)
IO.puts("Step 1 - Basic product schema:")
IO.inspect(RS.get_fields(basic_product) |> Enum.map(& &1.name), label: "fields")

# Step 2: Add optional metadata fields
metadata_fields = [
  RS.field(:description, RS.type(:string), optional: true),
  RS.field(:tags, RS.type(:array), optional: true)
]

all_fields = basic_fields ++ metadata_fields
product_with_metadata = RS.schema(:product, all_fields)
IO.puts("\nStep 2 - Product with metadata:")
IO.inspect(RS.get_fields(product_with_metadata) |> Enum.map(& &1.name), label: "fields")

# Step 3: Add inventory tracking
inventory_schema =
  RS.schema(:inventory, [
    RS.field(:quantity, RS.type(:integer)),
    RS.field(:warehouse_id, RS.type(:integer)),
    RS.field(:reorder_level, RS.type(:integer))
  ])

inventory_field = RS.field(:inventory, RS.type(:schema, [inventory_schema]))

complete_fields = all_fields ++ [inventory_field]
complete_product = RS.schema(:product, complete_fields)

IO.puts("\nStep 3 - Complete product with inventory:")
IO.inspect(RS.get_fields(complete_product) |> Enum.map(& &1.name), label: "fields")

# Step 4: Create catalog AST
catalog_ast =
  RS.ast(complete_product, %{
    version: "1.0",
    domain: "e-commerce",
    created_at: DateTime.utc_now()
  })

IO.puts("\nStep 4 - Final catalog AST created")
IO.puts("Total fields: #{length(RS.get_fields(catalog_ast))}")
IO.puts("Metadata: #{inspect(catalog_ast.metadata.domain)}")

# Verify composition
inventory_field_check = RS.get_field(catalog_ast, :inventory)

if inventory_field_check do
  IO.puts("\n✓ Inventory field successfully composed into schema")
  IO.puts("  Inventory field type: #{inspect(inventory_field_check.field_type.name)}")
end

IO.puts("\n✓ Node composition complete!")
