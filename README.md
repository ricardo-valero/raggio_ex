# Raggio

A composable Elixir library for data schema definition, validation, and AST manipulation.

## Overview

Raggio is an umbrella project containing two independent packages:

- **Raggio.Schema**: Composable schema definition and validation library
- **Raggio.Syntax**: AST manipulation library with composable functions

## Structure

```
raggio/
├── apps/
│   ├── raggio_schema/    # Schema definition and validation package
│   └── raggio_syntax/    # AST manipulation package
├── examples/              # Working, compilable examples
│   ├── raggio_schema/    # Schema examples
│   └── raggio_syntax/    # Syntax examples
├── test/                  # Automated example verification tests
└── config/                # Shared configuration
```

## Installation

Add the desired package to your `mix.exs`:

```elixir
def deps do
  [
    {:raggio_schema, "~> 0.1.0"},
    # and/or
    {:raggio_syntax, "~> 0.1.0"}
  ]
end
```

## Getting Started

### Raggio.Schema

Define schemas and validate data with composable functions:

```elixir
# Define schema
user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer() |> Raggio.Schema.positive()}
])

# Validate data
case Raggio.Schema.validate(user_schema, %{name: "Alice", age: 30}) do
  {:ok, data} -> IO.puts("Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("Invalid: #{inspect(errors)}")
end
```

### Raggio.Syntax

Build and manipulate ASTs with composable functions:

```elixir
# Create AST
schema_ast = Raggio.Syntax.schema(:user, [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer))
])

# Traverse AST
Raggio.Syntax.traverse(schema_ast, fn node ->
  IO.inspect(node)
end)
```

## Development

### Setup

```bash
# Install dependencies
mix deps.get

# Compile all packages
mix compile
```

### Running Tests

```bash
# Run all tests (including example verification)
mix test.all

# Run tests for specific package
cd apps/raggio_schema && mix test
cd apps/raggio_syntax && mix test
```

### Formatting

```bash
# Format all code
mix format.all
```

## Examples

Working examples are available in the `examples/` directory, organized by package and use case:

```bash
# Run a schema example
elixir examples/raggio_schema/basic_validation/simple_schema.exs

# Run a syntax example
elixir examples/raggio_syntax/ast_building/simple_ast.exs
```

## Design Principles

- **Function composition over macros**: Use the pipe operator for clean, composable APIs
- **Example-driven documentation**: Working code examples serve as primary documentation
- **Module-level docs only**: Minimal inline documentation, prefer examples
- **Independent packages**: Each package is independently compilable and publishable
- **No circular dependencies**: Clean, layered architecture

## License

MIT License - see LICENSE file for details
