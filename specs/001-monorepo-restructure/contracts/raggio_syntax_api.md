# Raggio.Syntax API Contract

**Package**: `raggio_syntax`  
**Module**: `Raggio.Syntax`  
**Version**: 1.0.0

## Overview

Composable syntax tree construction and manipulation library using pipe-based function composition.

---

## Node Construction

### `schema/1`
Creates a schema node.

**Signature**: `schema(fields :: [FieldNode.t()]) :: SchemaNode.t()`

**Example**:
```elixir
Syntax.schema([
  Syntax.field(:name, Syntax.type(:string)),
  Syntax.field(:age, Syntax.type(:integer))
])
```

### `schema/2`
Creates a named schema node.

**Signature**: `schema(name :: atom(), fields :: [FieldNode.t()]) :: SchemaNode.t()`

### `field/2`
Creates a field node.

**Signature**: `field(name :: atom(), type :: TypeNode.t()) :: FieldNode.t()`

**Example**:
```elixir
Syntax.field(:email, Syntax.type(:string))
```

### `field/3`
Creates a field node with options.

**Signature**: `field(name :: atom(), type :: TypeNode.t(), opts :: keyword()) :: FieldNode.t()`

**Options**:
- `required: boolean()` - Whether field is required
- `default: term()` - Default value

### `type/1`
Creates a type node.

**Signature**: `type(name :: atom()) :: TypeNode.t()`

**Example**:
```elixir
Syntax.type(:string)
Syntax.type(:integer)
```

### `type/2`
Creates a generic type node with parameters.

**Signature**: `type(name :: atom(), parameters :: [TypeNode.t()]) :: TypeNode.t()`

**Example**:
```elixir
Syntax.type(:list, [Syntax.type(:string)])
# list(string)
```

### `transform_node/2`
Creates a transform node.

**Signature**: `transform_node(operation :: atom(), transformer :: function()) :: TransformNode.t()`

---

## Syntax Tree Construction

### `ast/1`
Wraps a node in a SyntaxTree.

**Signature**: `ast(root :: Node.t()) :: SyntaxTree.t()`

**Example**:
```elixir
schema = Syntax.schema(:user, [...])
tree = Syntax.ast(schema)
```

### `ast/2`
Wraps a node with metadata.

**Signature**: `ast(root :: Node.t(), metadata :: map()) :: SyntaxTree.t()`

---

## Traversal Functions

### `traverse/2`
Traverses syntax tree depth-first, applying visitor function.

**Signature**: `traverse(tree :: SyntaxTree.t() | Node.t(), visitor :: (Node.t() -> term())) :: Node.t()`

**Example**:
```elixir
Syntax.traverse(tree, fn node ->
  IO.inspect(node.type, label: "Visiting")
end)
```

### `traverse/3`
Traverses with accumulator.

**Signature**: `traverse(tree :: SyntaxTree.t() | Node.t(), acc :: term(), visitor :: (Node.t(), term() -> {:continue | :halt, term()})) :: term()`

**Example**:
```elixir
# Count nodes by type
Syntax.traverse(tree, %{}, fn node, acc ->
  {:continue, Map.update(acc, node.type, 1, &(&1 + 1))}
end)
```

### `traverse_breadth_first/2`
Traverses syntax tree breadth-first.

**Signature**: `traverse_breadth_first(tree :: SyntaxTree.t() | Node.t(), visitor :: (Node.t() -> term())) :: :ok`

### `find/2`
Finds first node matching predicate.

**Signature**: `find(tree :: SyntaxTree.t() | Node.t(), predicate :: (Node.t() -> boolean())) :: Node.t() | nil`

**Example**:
```elixir
Syntax.find(tree, fn node ->
  node.type == :field && node.name == :email
end)
```

### `find_all/2`
Finds all nodes matching predicate.

**Signature**: `find_all(tree :: SyntaxTree.t() | Node.t(), predicate :: (Node.t() -> boolean())) :: [Node.t()]`

---

## Transformation Functions

### `transform/2`
Applies transformation to all nodes.

**Signature**: `transform(tree :: SyntaxTree.t() | Node.t(), transformer :: (Node.t() -> Node.t())) :: SyntaxTree.t() | Node.t()`

**Example**:
```elixir
# Add metadata to all fields
Syntax.transform(tree, fn node ->
  case node do
    %{type: :field} = field -> Map.put(field, :validated, true)
    other -> other
  end
end)
```

### `map/2`
Alias for `transform/2`.

**Signature**: `map(tree, mapper) :: tree`

### `filter/2`
Filters nodes (removes non-matching).

**Signature**: `filter(tree :: SyntaxTree.t() | Node.t(), predicate :: (Node.t() -> boolean())) :: SyntaxTree.t() | Node.t() | nil`

**Example**:
```elixir
# Remove optional fields
Syntax.filter(tree, fn node ->
  case node do
    %{type: :field, required: false} -> false
    _ -> true
  end
end)
```

### `replace/3`
Replaces specific node with replacement.

**Signature**: `replace(tree :: SyntaxTree.t() | Node.t(), target :: Node.t(), replacement :: Node.t()) :: SyntaxTree.t() | Node.t()`

---

## Query Functions

### `get_fields/1`
Extracts all field nodes from schema.

**Signature**: `get_fields(tree :: SyntaxTree.t() | SchemaNode.t()) :: [FieldNode.t()]`

**Example**:
```elixir
fields = Syntax.get_fields(schema_node)
field_names = Enum.map(fields, & &1.name)
```

### `get_field/2`
Gets specific field by name.

**Signature**: `get_field(tree :: SyntaxTree.t() | SchemaNode.t(), name :: atom()) :: FieldNode.t() | nil`

### `get_type/1`
Gets type of node.

**Signature**: `get_type(node :: Node.t()) :: atom()`

### `get_children/1`
Gets immediate children of node.

**Signature**: `get_children(node :: Node.t()) :: [Node.t()]`

---

## Type Specifications

```elixir
@type t() :: SyntaxTree.t()

@type node() :: SchemaNode.t() | FieldNode.t() | TypeNode.t() | TransformNode.t()

@type schema_node() :: %SchemaNode{
  type: :schema,
  name: atom(),
  fields: [field_node()],
  schema_type: :struct | :union | :enum,
  metadata: map()
}

@type field_node() :: %FieldNode{
  type: :field,
  name: atom(),
  field_type: type_node(),
  required: boolean(),
  default: term() | nil,
  metadata: map()
}

@type type_node() :: %TypeNode{
  type: :type,
  name: atom(),
  parameters: [type_node()],
  metadata: map()
}

@type transform_node() :: %TransformNode{
  type: :transform,
  operation: atom(),
  target: term(),
  transformer: (node() -> node()),
  metadata: map()
}
```

---

*API contract for Raggio.Syntax complete.*
