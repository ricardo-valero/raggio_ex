# Raggio.Syntax

AST manipulation library with composable functions for Elixir.

## Purpose

Raggio.Syntax provides composable functions for building, traversing, and transforming abstract syntax trees. Work with ASTs using clean, functional patterns instead of complex macro-generated structures.

## Installation

Add `raggio_syntax` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raggio_syntax, "~> 0.1.0"}
  ]
end
```

## Quick Example

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

## More Examples

See the `examples/raggio_syntax/` directory for working, compilable examples demonstrating various patterns and use cases.
