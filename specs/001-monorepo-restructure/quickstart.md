# Quickstart Guide: Raggio Schema and Syntax

**Version**: 0.1.0  
**Date**: 2026-01-12  
**Purpose**: Get started with Raggio.Schema and Raggio.Syntax package

---

## Prerequisites

- Elixir 1.14 or later installed
- Mix build tool
- Basic familiarity with Elixir syntax

---

## Installation

### Adding Raggio.Schema

Add `:raggio_schema` to your `mix.exs` dependency list:

```elixir
def deps do
  [
    {:raggio_schema, "~> 0.1.0"}
  ]
end
```

### Adding Raggio.Syntax

Add `:raggio_syntax` to your `mix.exs` dependency list:

```elixir
def deps do
  [
    {:raggio_syntax, "~> 0.1.0"}
  ]
end
```

### Installing Package

Run mix to fetch dependency:

```bash
mix deps.get
```

### Verification

Start IEx and verify package loaded:

```bash
iex -S mix
```

```elixir
iex> Raggio.Schema.string()
%Raggio.Schema{type: :string, ...}

iex> Raggio.Syntax.type(:string)
%Raggio.Syntax.TypeNode{name: :string, ...}
```

---

## Your First Schema

### Define Simple Schema

Let's create a schema for user with name and age:

```elixir
# Define schema
user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer()}
])
```

### Validate Data

Validate valid data against schema:

```elixir
valid_data = %{name: "Alice", age: 30}

case Raggio.Schema.validate(user_schema, valid_data) do
  {:ok, data} -> 
    IO.puts("Validation succeeded!")
    IO.inspect(data)
  {:error, errors} -> 
    IO.puts("Validation failed!")
    IO.inspect(errors)
end

# Output:
# Validation succeeded!
# %{name: "Alice", age: 30}
```

### Handle Validation Error

Validate invalid data:

```elixir
invalid_data = %{name: "Bob", age: "not a number"}

case Raggio.Schema.validate(user_schema, invalid_data) do
  {:ok, data} -> 
    IO.puts("Valid: #{inspect(data)}")
  {:error, errors} -> 
    IO.puts("Invalid:")
    Enum.each(errors, fn error ->
      path = Enum.join(error.path, ".")
      IO.puts("  #{path}: #{error.message}")
    end)
end

# Output:
# Invalid:
#   age: must be integer type
```

### Add Constraint

Add constraint to schema field:

```elixir
constrained_user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string() |> Raggio.Schema.min_length(2)},
  {:age, Raggio.Schema.integer() |> Raggio.Schema.positive()},
  {:email, Raggio.Schema.string() |> Raggio.Schema.email()}
])

# Validate
data = %{name: "A", age: -5, email: "invalid"}

{:error, errors} = Raggio.Schema.validate(constrained_user_schema, data)

# Output error:
# - name: minimum length is 2
# - age: must be positive number
# - email: must be valid email format
```

---

## Your First AST

### Create AST Node

Build AST node representing schema structure:

```elixir
# Create field node
name_field = Raggio.Syntax.field(:name, Raggio.Syntax.type(:string))
age_field = Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer), required: true)

# Create schema node
user_schema_ast = Raggio.Syntax.schema(:user, [name_field, age_field])
```

### Compose Node

Compose node to build complex structure:

```elixir
# Address schema
address_fields = [
  Raggio.Syntax.field(:street, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:city, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:zip, Raggio.Syntax.type(:string))
]
address_schema = Raggio.Syntax.schema(:address, address_fields)

# User with address
user_fields = [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer)),
  Raggio.Syntax.field(:address, address_schema)
]
complete_user_schema = Raggio.Syntax.schema(:user, user_fields)
```

### Traverse AST

Navigate AST structure:

```elixir
# Collect all field name
field_names = Raggio.Syntax.traverse(complete_user_schema, [], fn
  %Raggio.Syntax.FieldNode{name: name}, acc -> {:continue, [name | acc]}
  _node, acc -> {:continue, acc}
end)
|> Enum.reverse()

IO.inspect(field_names)
# Output: [:name, :age, :street, :city, :zip]

# Find specific field
email_field = Raggio.Syntax.find(complete_user_schema, fn
  %Raggio.Syntax.FieldNode{name: :email} -> true
  _ -> false
end)

case email_field do
  nil -> IO.puts("Email field not found")
  field -> IO.puts("Found: #{field.name}")
end
```

### Transform AST

Modify AST structure:

```elixir
# Make all field required
transformed = Raggio.Syntax.transform(complete_user_schema, fn
  %Raggio.Syntax.FieldNode{} = field -> 
    %{field | required: true}
  other -> 
    other
end)

# Verify transformation
required_count = Raggio.Syntax.traverse(transformed, 0, fn
  %Raggio.Syntax.FieldNode{required: true}, count -> {:continue, count + 1}
  _, count -> {:continue, count}
end)

IO.puts("Required field: #{required_count}")
```

---

## Exploring Example

### Example Directory Structure

Example are organized by package and use case:

```
examples/
├── raggio_schema/
│   ├── basic_validation/
│   ├── composition/
│   ├── transformation/
│   └── advanced/
└── raggio_syntax/
    ├── ast_building/
    ├── traversal/
    ├── transformation/
    └── advanced/
```

### Running Example

Navigate to example directory and run any example file:

```bash
cd examples/raggio_schema/basic_validation
elixir simple_schema.exs
```

Example execute and show output demonstrating the pattern.

### Example: Simple Schema Validation

**File**: `examples/raggio_schema/basic_validation/simple_schema.exs`

```elixir
# Define user schema
user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer()}
])

# Validate valid data
valid_user = %{name: "Alice", age: 30}

case Raggio.Schema.validate(user_schema, valid_user) do
  {:ok, data} -> 
    IO.puts("✓ Validation succeeded: #{inspect(data)}")
  {:error, errors} -> 
    IO.puts("✗ Validation failed: #{inspect(errors)}")
end

# Validate invalid data
invalid_user = %{name: "Bob", age: "not a number"}

case Raggio.Schema.validate(user_schema, invalid_user) do
  {:ok, data} -> 
    IO.puts("✓ Validation succeeded: #{inspect(data)}")
  {:error, errors} -> 
    IO.puts("✗ Validation failed:")
    Enum.each(errors, fn err ->
      IO.puts("  - #{Enum.join(err.path, ".")}: #{err.message}")
    end)
end
```

**Run**:
```bash
elixir simple_schema.exs
```

**Output**:
```
✓ Validation succeeded: %{name: "Alice", age: 30}
✗ Validation failed:
  - age: must be integer type
```

### Example: AST Building

**File**: `examples/raggio_syntax/ast_building/simple_ast.exs`

```elixir
# Build simple schema AST
fields = [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer), required: true)
]

user_schema = Raggio.Syntax.schema(:user, fields)

IO.puts("Schema AST:")
IO.inspect(user_schema, pretty: true)

# Extract field information
IO.puts("\nField:")
Raggio.Syntax.traverse(user_schema, fn
  %Raggio.Syntax.FieldNode{name: name, required: required} ->
    status = if required, do: "required", else: "optional"
    IO.puts("  - #{name} (#{status})")
  _ ->
    nil
end)
```

**Run**:
```bash
elixir simple_ast.exs
```

### Finding More Example

Browse complete example collection:

```bash
# List all Raggio.Schema example
find examples/raggio_schema -name "*.exs"

# List all Raggio.Syntax example
find examples/raggio_syntax -name "*.exs"
```

Each example file:
- Demonstrates one specific pattern or use case
- Is self-contained and runnable
- Has minimal comment (code is the documentation)
- Shows both success and failure scenario

---

## Composing Custom Function

### Custom Validator

Combine existing validator to create custom validation:

```elixir
defmodule MyValidator do
  alias Raggio.Schema
  
  # Custom validator: password must be 8-20 character, contain uppercase, lowercase, and number
  def password_schema do
    Schema.string()
    |> Schema.min_length(8)
    |> Schema.max_length(20)
    |> Schema.pattern(~r/[A-Z]/)  # Has uppercase
    |> Schema.pattern(~r/[a-z]/)  # Has lowercase
    |> Schema.pattern(~r/[0-9]/)  # Has number
  end
  
  # Custom validator: US phone number
  def us_phone_schema do
    Schema.string()
    |> Schema.pattern(~r/^\d{3}-\d{3}-\d{4}$/)
  end
  
  # Use in schema
  def user_schema do
    Schema.struct([
      {:username, Schema.string() |> Schema.min_length(3)},
      {:password, password_schema()},
      {:phone, us_phone_schema()}
    ])
  end
end

# Use custom validator
user = %{
  username: "alice",
  password: "SecurePass123",
  phone: "555-123-4567"
}

case Raggio.Schema.validate(MyValidator.user_schema(), user) do
  {:ok, data} -> IO.puts("Valid user: #{inspect(data)}")
  {:error, errors} -> IO.inspect(errors)
end
```

### Custom Type

Create reusable schema component:

```elixir
defmodule MySchema do
  alias Raggio.Schema
  
  # Reusable email schema
  def email do
    Schema.string()
    |> Schema.email()
    |> Schema.transform(fn email -> {:ok, String.downcase(email)} end)
  end
  
  # Reusable age schema
  def age do
    Schema.integer()
    |> Schema.range(0, 120)
  end
  
  # Reusable timestamp schema
  def timestamp do
    Schema.datetime()
    |> Schema.default(DateTime.utc_now())
  end
  
  # Compose into user schema
  def user do
    Schema.struct([
      {:email, email()},
      {:age, age()},
      {:created_at, timestamp()}
    ])
  end
end

# Use composable schema
Raggio.Schema.validate(MySchema.user(), %{
  email: "ALICE@EXAMPLE.COM",
  age: 30
})
# => {:ok, %{email: "alice@example.com", age: 30, created_at: ~U[2026-01-12 ...]}}
```

### Custom AST Transformer

Build custom transformation for AST:

```elixir
defmodule MyTransformer do
  alias Raggio.Syntax
  
  # Make all field required
  def require_all_fields(ast) do
    Syntax.transform(ast, fn
      %Syntax.FieldNode{} = field -> 
        %{field | required: true}
      other -> 
        other
    end)
  end
  
  # Remove field with specific name
  def remove_field(ast, field_name) do
    Syntax.filter(ast, fn
      %Syntax.FieldNode{name: ^field_name} -> false
      _ -> true
    end)
  end
  
  # Add prefix to all field name
  def prefix_fields(ast, prefix) do
    Syntax.transform(ast, fn
      %Syntax.FieldNode{name: name} = field ->
        new_name = String.to_atom("#{prefix}_#{name}")
        %{field | name: new_name}
      other ->
        other
    end)
  end
end

# Use custom transformer
original_schema = Raggio.Syntax.schema(:user, [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer))
])

# Transform
transformed = original_schema
|> MyTransformer.require_all_fields()
|> MyTransformer.prefix_fields("user")

# Result: field name :user_name and :user_age, both required
```

### Composing Multiple Validator

Chain validator function together:

```elixir
defmodule Combinator do
  alias Raggio.Schema
  
  # Compose validator with "and" logic (all must pass)
  def all_of(validators) do
    fn schema ->
      Enum.reduce(validators, schema, fn validator, acc_schema ->
        validator.(acc_schema)
      end)
    end
  end
  
  # Use
  strict_string = all_of([
    &Schema.min_length(&1, 5),
    &Schema.max_length(&1, 50),
    &Schema.pattern(&1, ~r/^[A-Za-z\s]+$/)
  ])
  
  # Apply to schema
  name_schema = strict_string.(Schema.string())
end
```

---

## Next Step

### Learn More

- **Example**: Browse `examples/` directory for comprehensive pattern
- **API Reference**: See `contracts/raggio_schema_api.md` and `contracts/raggio_syntax_api.md`
- **Data Model**: Review `data-model.md` for entity and relationship

### Contributing

- Run test: `mix test`
- Format code: `mix format`
- Verify example: `mix test test/example_test.exs`

### Common Pattern

Explore these advanced example:

- **Conditional Validation**: `examples/raggio_schema/advanced/conditional_validation.exs`
- **Cross-field Validation**: `examples/raggio_schema/advanced/cross_field.exs`
- **Code Generation**: `examples/raggio_syntax/advanced/code_generation.exs`
- **AST Analysis**: `examples/raggio_syntax/advanced/analysis.exs`

---

## Troubleshooting

### Compilation Error

If package fail to compile:

1. Ensure Elixir 1.14+ installed: `elixir --version`
2. Clean build artifact: `mix clean`
3. Fetch dependency again: `mix deps.get`
4. Recompile: `mix compile`

### Validation Not Working

If validation produce unexpected result:

1. Verify schema structure: `IO.inspect(schema, pretty: true)`
2. Check data type match schema expectation
3. Review validation error path and message
4. Test with simple schema first, then add complexity

### AST Traversal Issue

If traversal not visiting expected node:

1. Verify AST structure: `IO.inspect(ast, pretty: true)`
2. Check visitor function return value (must return `{:continue, acc}` or `{:halt, acc}`)
3. Use `find` or `find_all` for simpler query
4. Test traversal with simple AST first

---

## Summary

You now know how to:

- ✓ Install Raggio.Schema and Raggio.Syntax package
- ✓ Define schema and validate data
- ✓ Build AST and manipulate node
- ✓ Run and learn from working example
- ✓ Compose custom validator and transformer
- ✓ Combine function to create reusable component

**Remember**: Example are your primary documentation. When in doubt, find a relevant example in `examples/` directory and run it!
