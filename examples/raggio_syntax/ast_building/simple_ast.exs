# Simple AST Building Example
# Demonstrates US2 Acceptance Scenario 1: Building AST nodes programmatically

# This example shows how to create a simple user schema AST

alias RaggioSyntax, as: RS

# Step 1: Create individual field nodes
name_field = RS.field(:name, RS.type(:string))
email_field = RS.field(:email, RS.type(:string))
age_field = RS.field(:age, RS.type(:integer))

IO.puts("Created field nodes:")
IO.inspect(name_field, label: "name_field")
IO.inspect(email_field, label: "email_field")
IO.inspect(age_field, label: "age_field")

# Step 2: Compose fields into a schema
user_schema = RS.schema(:user, [name_field, email_field, age_field])

IO.puts("\nCreated user schema:")
IO.inspect(user_schema, label: "user_schema")

# Step 3: Wrap schema in an AST
user_ast = RS.ast(user_schema)

IO.puts("\nCreated AST:")
IO.inspect(user_ast, label: "user_ast")

# Step 4: Query the AST
fields = RS.get_fields(user_ast)
IO.puts("\nFields in schema: #{length(fields)}")

first_field = RS.get_field(user_ast, :name)
IO.puts("First field: #{inspect(first_field.name)}")

IO.puts("\n✓ Simple AST building complete!")
