# Raggio.Syntax Public API Contract

**Version**: 0.2.0  
**Date**: 2026-01-13

## Node Builders

```elixir
@spec schema([FieldNode.t()]) :: SchemaNode.t()
def schema(fields)

@spec schema(atom(), [FieldNode.t()]) :: SchemaNode.t()
def schema(name, fields)

@spec field(atom(), TypeNode.t()) :: FieldNode.t()
def field(name, type_node)

@spec field(atom(), TypeNode.t(), keyword()) :: FieldNode.t()
def field(name, type_node, opts)
# opts: required: boolean, default: any

@spec type(atom()) :: TypeNode.t()
def type(type_name)

@spec type(atom(), [TypeNode.t()]) :: TypeNode.t()
def type(type_name, parameters)
# For generic types like list(string)
```

## Tree Builders

```elixir
@spec ast(Node.t()) :: SyntaxTree.t()
def ast(root_node)

@spec ast(Node.t(), map()) :: SyntaxTree.t()
def ast(root_node, metadata)
```

## Traversal

```elixir
@spec traverse(SyntaxTree.t() | Node.t(), (Node.t() -> any())) :: :ok
def traverse(tree_or_node, visitor_fn)
# Depth-first traversal

@spec traverse(SyntaxTree.t() | Node.t(), acc, (Node.t(), acc -> acc)) :: acc
def traverse(tree_or_node, accumulator, reducer_fn)
# Traversal with accumulator

@spec traverse_breadth_first(SyntaxTree.t() | Node.t(), (Node.t() -> any())) :: :ok
def traverse_breadth_first(tree_or_node, visitor_fn)
# Breadth-first traversal

@spec find(SyntaxTree.t() | Node.t(), (Node.t() -> boolean())) :: Node.t() | nil
def find(tree_or_node, predicate)
# Find first matching node

@spec find_all(SyntaxTree.t() | Node.t(), (Node.t() -> boolean())) :: [Node.t()]
def find_all(tree_or_node, predicate)
# Find all matching nodes
```

## Transformation

```elixir
@spec transform(SyntaxTree.t() | Node.t(), (Node.t() -> Node.t())) :: SyntaxTree.t() | Node.t()
def transform(tree_or_node, transformer_fn)
# Apply transformation to all nodes

@spec filter(SyntaxTree.t() | Node.t(), (Node.t() -> boolean())) :: SyntaxTree.t() | Node.t()
def filter(tree_or_node, predicate)
# Remove nodes that don't match predicate

@spec replace(SyntaxTree.t() | Node.t(), Node.t(), Node.t()) :: SyntaxTree.t() | Node.t()
def replace(tree_or_node, target_node, replacement_node)
# Replace specific node
```

## Query

```elixir
@spec get_fields(SchemaNode.t()) :: [FieldNode.t()]
def get_fields(schema_node)

@spec get_field(SchemaNode.t(), atom()) :: FieldNode.t() | nil
def get_field(schema_node, field_name)

@spec get_children(Node.t()) :: [Node.t()]
def get_children(node)
```

## Node Protocol

```elixir
defprotocol Raggio.Syntax.Node do
  @spec node_type(t) :: atom()
  def node_type(node)
  
  @spec children(t) :: [t]
  def children(node)
end
```
