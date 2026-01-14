# Complex Schema Example
# Demonstrates nested schema structures

alias RaggioSyntax, as: RS

# Create an address schema (nested)
address_schema =
  RS.schema(:address, [
    RS.field(:street, RS.type(:string)),
    RS.field(:city, RS.type(:string)),
    RS.field(:zip, RS.type(:string)),
    RS.field(:country, RS.type(:string))
  ])

IO.puts("Created address schema:")
IO.inspect(address_schema, label: "address_schema")

# Create a contact info schema (nested)
contact_schema =
  RS.schema(:contact, [
    RS.field(:email, RS.type(:string)),
    RS.field(:phone, RS.type(:string))
  ])

IO.puts("\nCreated contact schema:")
IO.inspect(contact_schema, label: "contact_schema")

# Create a user schema that references the nested schemas
# Note: TypeNode can reference other schemas
user_schema =
  RS.schema(:user, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:name, RS.type(:string)),
    RS.field(:address, RS.type(:schema, [address_schema])),
    RS.field(:contact, RS.type(:schema, [contact_schema])),
    RS.field(:created_at, RS.type(:datetime))
  ])

IO.puts("\nCreated complex user schema with nested schemas:")
IO.inspect(user_schema, label: "user_schema", limit: :infinity)

# Wrap in AST
user_ast = RS.ast(user_schema, %{version: "1.0", description: "User entity"})

IO.puts("\nCreated AST with metadata:")
IO.inspect(user_ast.metadata, label: "metadata")

# Query nested structure
fields = RS.get_fields(user_ast)
IO.puts("\nTop-level fields: #{length(fields)}")

address_field = RS.get_field(user_ast, :address)
IO.puts("Address field type: #{inspect(address_field.field_type.name)}")

IO.puts("\n✓ Complex schema building complete!")
