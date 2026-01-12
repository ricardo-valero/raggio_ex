# Raggio.Syntax Public API Contract

**Version**: 0.1.0  
**Date**: 2026-01-12  
**Package**: `raggio_syntax`

---

## Module: Raggio.Syntax

Main entry point for AST construction and manipulation.

### Node Construction Function

#### `field/2`
**Signature**: `(name :: atom, type :: node) -> node`  
**Purpose**: Create field node  
**Parameter**:
- `name` - Field name (atom)  
- `type` - TypeNode representing field type  
**Return**: FieldNode  
**Example**:
```elixir
Raggio.Syntax.field(:name, Raggio.Syntax.type(:string))
```

#### `field/3`
**Signature**: `(name :: atom, type :: node, opts :: keyword) -> node`  
**Purpose**: Create field node with option  
**Parameter**:
- `name` - Field name (atom)  
- `type` - TypeNode representing field type  
- `opts` - Option keyword list (`:required`, `:default`)  
**Return**: FieldNode with option  
**Example**:
```elixir
Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer), required: true)
```

#### `schema/1`
**Signature**: `(fields :: [node]) -> node`  
**Purpose**: Create schema node from field list  
**Parameter**: `fields` - List of FieldNode  
**Return**: SchemaNode  
**Example**:
```elixir
Raggio.Syntax.schema([
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer))
])
```

#### `schema/2`
**Signature**: `(name :: atom, fields :: [node]) -> node`  
**Purpose**: Create named schema node  
**Parameter**:
- `name` - Schema name (atom)  
- `fields` - List of FieldNode  
**Return**: Named SchemaNode  
**Example**:
```elixir
Raggio.Syntax.schema(:user, [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string))
])
```

#### `type/1`
**Signature**: `(name :: atom) -> node`  
**Purpose**: Create simple type node  
**Parameter**: `name` - Type name (`:string`, `:integer`, etc.)  
**Return**: TypeNode  
**Example**:
```elixir
Raggio.Syntax.type(:string)
```

#### `type/2`
**Signature**: `(name :: atom, parameters :: [node]) -> node`  
**Purpose**: Create generic type node with parameter  
**Parameter**:
- `name` - Type name (`:array`, `:union`, etc.)  
- `parameters` - List of TypeNode parameter  
**Return**: Generic TypeNode  
**Example**:
```elixir
# Array of string
Raggio.Syntax.type(:array, [Raggio.Syntax.type(:string)])

# Union of string and integer
Raggio.Syntax.type(:union, [
  Raggio.Syntax.type(:string),
  Raggio.Syntax.type(:integer)
])
```

#### `transform/2`
**Signature**: `(operation :: atom, function :: (any -> any)) -> node`  
**Purpose**: Create transformation node  
**Parameter**:
- `operation` - Operation type (`:map`, `:filter`, `:reduce`)  
- `function` - Transformation function  
**Return**: TransformNode  
**Example**:
```elixir
Raggio.Syntax.transform(:map, fn field -> %{field | required: true} end)
```

---

### AST Construction Function

#### `ast/1`
**Signature**: `(root :: node) -> ast`  
**Purpose**: Create AST from root node  
**Parameter**: `root` - Root node (typically SchemaNode)  
**Return**: AST structure  
**Example**:
```elixir
schema_node = Raggio.Syntax.schema([...])
ast = Raggio.Syntax.ast(schema_node)
```

#### `ast/2`
**Signature**: `(root :: node, metadata :: map) -> ast`  
**Purpose**: Create AST with metadata  
**Parameter**:
- `root` - Root node  
- `metadata` - Arbitrary metadata map  
**Return**: AST with metadata  
**Example**:
```elixir
Raggio.Syntax.ast(schema_node, %{version: "1.0", author: "Alice"})
```

---

### Traversal Function

#### `traverse/2`
**Signature**: `(node :: node, visitor :: (node -> any)) -> any`  
**Purpose**: Traverse AST depth-first, applying visitor function  
**Parameter**:
- `node` - Root node to traverse  
- `visitor` - Function applied to each node  
**Return**: Result of visitor application  
**Example**:
```elixir
# Collect all field name
Raggio.Syntax.traverse(ast, fn
  %FieldNode{name: name} -> name
  _ -> nil
end)
|> Enum.filter(&(&1 != nil))
```

#### `traverse/3`
**Signature**: `(node :: node, acc :: any, visitor :: (node, any -> {action, any})) -> any`  
**Purpose**: Traverse AST with accumulator  
**Parameter**:
- `node` - Root node to traverse  
- `acc` - Initial accumulator value  
- `visitor` - Function `(node, acc) -> {:continue | :halt, new_acc}`  
**Return**: Final accumulator value  
**Example**:
```elixir
# Count required field
Raggio.Syntax.traverse(ast, 0, fn
  %FieldNode{required: true}, count -> {:continue, count + 1}
  _node, count -> {:continue, count}
end)
```

#### `traverse_breadth_first/2`
**Signature**: `(node :: node, visitor :: (node -> any)) -> any`  
**Purpose**: Traverse AST breadth-first  
**Parameter**:
- `node` - Root node to traverse  
- `visitor` - Function applied to each node  
**Return**: Result of visitor application  
**Example**:
```elixir
Raggio.Syntax.traverse_breadth_first(ast, &IO.inspect/1)
```

#### `find/2`
**Signature**: `(node :: node, predicate :: (node -> boolean)) -> node | nil`  
**Purpose**: Find first node matching predicate  
**Parameter**:
- `node` - Root node to search  
- `predicate` - Function returning true for match  
**Return**: Matching node or nil  
**Example**:
```elixir
# Find field named :email
Raggio.Syntax.find(ast, fn
  %FieldNode{name: :email} -> true
  _ -> false
end)
```

#### `find_all/2`
**Signature**: `(node :: node, predicate :: (node -> boolean)) -> [node]`  
**Purpose**: Find all node matching predicate  
**Parameter**:
- `node` - Root node to search  
- `predicate` - Function returning true for match  
**Return**: List of matching node  
**Example**:
```elixir
# Find all required field
Raggio.Syntax.find_all(ast, fn
  %FieldNode{required: true} -> true
  _ -> false
end)
```

---

### Transformation Function

#### `transform/2`
**Signature**: `(node :: node, transformer :: (node -> node)) -> node`  
**Purpose**: Apply transformation to all node, producing new AST  
**Parameter**:
- `node` - Root node to transform  
- `transformer` - Function transforming each node  
**Return**: New AST with transformed node  
**Example**:
```elixir
# Make all field required
Raggio.Syntax.transform(ast, fn
  %FieldNode{} = field -> %{field | required: true}
  other -> other
end)
```

#### `map/2`
**Signature**: `(node :: node, mapper :: (node -> node)) -> node`  
**Purpose**: Map function over all node (alias for transform)  
**Parameter**:
- `node` - Root node  
- `mapper` - Mapping function  
**Return**: New AST  
**Example**:
```elixir
Raggio.Syntax.map(ast, fn node -> 
  Map.put(node, :visited, true) 
end)
```

#### `filter/2`
**Signature**: `(node :: node, predicate :: (node -> boolean)) -> node`  
**Purpose**: Filter node (remove node not matching predicate)  
**Parameter**:
- `node` - Root node  
- `predicate` - Filter function  
**Return**: New AST with filtered node  
**Example**:
```elixir
# Remove optional field
Raggio.Syntax.filter(ast, fn
  %FieldNode{required: false} -> false
  _ -> true
end)
```

#### `replace/3`
**Signature**: `(node :: node, target :: node, replacement :: node) -> node`  
**Purpose**: Replace specific node with replacement  
**Parameter**:
- `node` - Root node  
- `target` - Node to replace  
- `replacement` - Replacement node  
**Return**: New AST with replacement  
**Example**:
```elixir
old_field = Raggio.Syntax.field(:name, Raggio.Syntax.type(:string))
new_field = Raggio.Syntax.field(:full_name, Raggio.Syntax.type(:string))

Raggio.Syntax.replace(ast, old_field, new_field)
```

---

### Query Function

#### `get_fields/1`
**Signature**: `(node :: node) -> [node]`  
**Purpose**: Extract all field node from schema  
**Parameter**: `node` - SchemaNode  
**Return**: List of FieldNode  
**Example**:
```elixir
fields = Raggio.Syntax.get_fields(schema_node)
```

#### `get_field/2`
**Signature**: `(node :: node, name :: atom) -> node | nil`  
**Purpose**: Get specific field by name  
**Parameter**:
- `node` - SchemaNode  
- `name` - Field name  
**Return**: FieldNode or nil  
**Example**:
```elixir
email_field = Raggio.Syntax.get_field(schema_node, :email)
```

#### `get_type/1`
**Signature**: `(node :: node) -> atom`  
**Purpose**: Get type of node  
**Parameter**: `node` - Any node  
**Return**: Type atom (`:field`, `:schema`, `:type`, `:transform`)  
**Example**:
```elixir
Raggio.Syntax.get_type(node)  # => :field
```

#### `get_children/1`
**Signature**: `(node :: node) -> [node]`  
**Purpose**: Get immediate children of node  
**Parameter**: `node` - Parent node  
**Return**: List of child node  
**Example**:
```elixir
children = Raggio.Syntax.get_children(schema_node)
```

---

### Validation Function

#### `valid?/1`
**Signature**: `(node :: node) -> boolean`  
**Purpose**: Check if AST structure is valid  
**Parameter**: `node` - Node to validate  
**Return**: true if valid, false otherwise  
**Example**:
```elixir
if Raggio.Syntax.valid?(ast) do
  IO.puts("AST is valid")
end
```

#### `validate/1`
**Signature**: `(node :: node) -> :ok | {:error, [error]}`  
**Purpose**: Validate AST structure with detailed error  
**Parameter**: `node` - Node to validate  
**Return**: `:ok` or error list  
**Example**:
```elixir
case Raggio.Syntax.validate(ast) do
  :ok -> :ok
  {:error, errors} -> IO.inspect(errors)
end
```

---

### Composition Function

#### `merge/2`
**Signature**: `(node1 :: node, node2 :: node) -> node`  
**Purpose**: Merge two schema node  
**Parameter**:
- `node1` - First SchemaNode  
- `node2` - Second SchemaNode  
**Return**: Merged SchemaNode  
**Example**:
```elixir
base_schema = Raggio.Syntax.schema([...])
extended_schema = Raggio.Syntax.schema([...])

merged = Raggio.Syntax.merge(base_schema, extended_schema)
```

#### `compose/1`
**Signature**: `(nodes :: [node]) -> node`  
**Purpose**: Compose multiple schema into one  
**Parameter**: `nodes` - List of SchemaNode  
**Return**: Composed SchemaNode  
**Example**:
```elixir
Raggio.Syntax.compose([
  base_schema,
  additional_fields,
  validation_schema
])
```

---

## Module: Raggio.Syntax.Node

Base node protocol and helper.

### Node Type

All node implement `Raggio.Syntax.Node` protocol with:

```elixir
%FieldNode{
  type: :field,
  name: atom(),
  field_type: TypeNode.t(),
  required: boolean(),
  default: any(),
  metadata: map()
}

%SchemaNode{
  type: :schema,
  name: atom() | nil,
  fields: [FieldNode.t()],
  schema_type: atom(),
  metadata: map()
}

%TypeNode{
  type: :type,
  name: atom(),
  parameters: [TypeNode.t()],
  metadata: map()
}

%TransformNode{
  type: :transform,
  operation: atom(),
  function: (any -> any),
  input: node(),
  output: TypeNode.t() | nil,
  metadata: map()
}
```

---

## Module: Raggio.Syntax.Visitor

Helper for building custom visitor.

#### `visitor/1`
**Signature**: `(handlers :: keyword) -> (node -> any)`  
**Purpose**: Build visitor from handler map  
**Parameter**: `handlers` - Keyword list of `{node_type, handler_fn}`  
**Return**: Visitor function  
**Example**:
```elixir
my_visitor = Raggio.Syntax.Visitor.visitor([
  field: fn field -> IO.puts("Field: #{field.name}") end,
  schema: fn schema -> IO.puts("Schema: #{schema.name}") end
])

Raggio.Syntax.traverse(ast, my_visitor)
```

---

## Usage Pattern

### Building AST

```elixir
# Simple schema
user_ast = Raggio.Syntax.schema(:user, [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:age, Raggio.Syntax.type(:integer), required: true)
])

# Complex nested schema
address_ast = Raggio.Syntax.schema(:address, [
  Raggio.Syntax.field(:street, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:city, Raggio.Syntax.type(:string))
])

user_with_address = Raggio.Syntax.schema(:user, [
  Raggio.Syntax.field(:name, Raggio.Syntax.type(:string)),
  Raggio.Syntax.field(:address, address_ast)
])
```

### Traversing AST

```elixir
# Collect information
field_names = Raggio.Syntax.traverse(ast, 0, fn
  %FieldNode{name: name}, acc -> {:continue, [name | acc]}
  _, acc -> {:continue, acc}
end)

# Conditional traversal
first_required = Raggio.Syntax.traverse(ast, nil, fn
  %FieldNode{required: true} = field, nil -> {:halt, field}
  _, acc -> {:continue, acc}
end)
```

### Transforming AST

```elixir
# Make all field optional with default
transformed = Raggio.Syntax.transform(ast, fn
  %FieldNode{} = field -> 
    %{field | required: false, default: nil}
  other -> 
    other
end)

# Remove field matching condition
filtered = Raggio.Syntax.filter(ast, fn
  %FieldNode{name: :internal_id} -> false  # Remove this field
  _ -> true
end)
```

### Pattern Matching

```elixir
# Extract specific information
case Raggio.Syntax.find(ast, fn n -> n.type == :field && n.name == :email end) do
  %FieldNode{field_type: type} ->
    IO.puts("Email type: #{inspect(type)}")
  nil ->
    IO.puts("Email field not found")
end
```

---

## Breaking Change Policy

Per specification, this is a clean break from old_code. No backward compatibility guarantee.

**Version**: All function follow semantic versioning. Breaking change increment major version.
