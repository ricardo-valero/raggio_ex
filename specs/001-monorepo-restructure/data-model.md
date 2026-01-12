# Data Model: Multi-Package Monorepo

**Date**: 2026-01-12  
**Status**: Complete  
**Purpose**: Define entity, relationship, and state transition for Raggio.Schema and Raggio.Syntax package

---

## Raggio.Schema Entity

### Schema
**Purpose**: Container for field definition and validation rule

**Attribute**:
- `type`: Atom representing schema type (`:struct`, `:string`, `:integer`, etc.)
- `constraint`: List of constraint tuple `{:constraint_name, value}`
- `validator`: List of validator function
- `field`: List of field (for struct type only)
- `metadata`: Map of arbitrary metadata

**State**: `draft` → `validated` → `ready`

**Validation Rule**:
- Type must be one of supported primitive or composite type
- Constraint must be applicable to type (e.g., `:min_length` only for string/array)
- Field required for struct type

---

### Field
**Purpose**: Individual data field with type, constraint, and validation

**Attribute**:
- `name`: Atom field identifier
- `type`: Schema defining field type
- `required`: Boolean indicating if field is mandatory
- `default`: Optional default value

**Relationship**: Field belong to Schema (struct type)

---

### Type (Primitive)
**Purpose**: Built-in type definition

**Supported Type**:
- `:string` - Text value
- `:integer` - Whole number
- `:float` - Decimal number
- `:boolean` - True/false value
- `:date` - Date without time (YYYY-MM-DD)
- `:datetime` - Date with time and timezone
- `:decimal` - Arbitrary precision decimal
- `:atom` - Elixir atom
- `:array` - List of value (homogeneous)
- `:struct` - Map with defined field
- `:enum` - One of predefined value
- `:union` - One of multiple type

**Type Composition**:
- Array contain element type: `{:array, element_schema}`
- Struct contain field list: `{:struct, [field]}`
- Enum contain value list: `{:enum, [value]}`
- Union contain type list: `{:union, [schema]}`

---

### Validator
**Purpose**: Composable validation function

**Signature**: `(value) -> :ok | {:error, message}`

**Built-in Validator**:
- String: `min_length`, `max_length`, `pattern`, `email`, `url`
- Numeric: `min`, `max`, `positive`, `negative`, `range`
- Array: `min_items`, `max_items`, `unique`
- Struct: `required_field`, `forbidden_field`
- Custom: User-defined function

**Composition**: Validator can be combined with `compose/1` or `all_of/1`

---

### ValidationResult
**Purpose**: Result of validation execution

**Structure**:
```elixir
# Success
{:ok, validated_data}

# Error
{:error, [validation_error]}
```

---

### ValidationError
**Purpose**: Detailed error information

**Attribute**:
- `path`: List representing path to error field `[:user, :email]`
- `message`: Human-readable error message
- `value`: Invalid value that caused error (optional)
- `constraint`: Constraint that failed

**Example**:
```elixir
%Raggio.Schema.ValidationError{
  path: [:user, :email],
  message: "must be valid email format",
  value: "not-an-email",
  constraint: :email
}
```

---

### CompositionError
**Purpose**: Error when composing incompatible schema

**Attribute**:
- `message`: Error description
- `left_type`: Type of first schema
- `right_type`: Type of second schema

**Trigger**: Raised at composition time when type incompatible (per clarification)

---

### Transformer
**Purpose**: Data transformation function

**Signature**: `(input) -> {:ok, output} | {:error, reason}`

**Use Case**:
- Coercion: Convert string to integer
- Normalization: Trim whitespace, lowercase email
- Derivation: Calculate field from other field

**Composition**: Transformer can be chained with pipe operator

---

## Raggio.Syntax Entity

### AST (Abstract Syntax Tree)
**Purpose**: Root structure representing complete abstract syntax tree

**Attribute**:
- `root`: Root node of tree
- `metadata`: Map of tree-level metadata

**Operation**:
- `traverse(ast, visitor)`: Apply visitor to all node
- `transform(ast, transformer)`: Apply transformation to produce new AST

---

### Node (Base)
**Purpose**: Base AST node with common attribute

**Attribute**:
- `type`: Atom node type (`:field`, `:schema`, `:type`, `:transform`)
- `metadata`: Map of node-specific metadata
- `children`: List of child node (for composite node)

**Node Type**:
- FieldNode: Represents field in schema
- SchemaNode: Represents schema definition
- TypeNode: Represents type annotation
- TransformNode: Represents transformation

---

### FieldNode
**Purpose**: Represents a field in schema

**Attribute**:
- `name`: Atom field name
- `type`: TypeNode representing field type
- `constraint`: List of constraint
- `required`: Boolean required flag

**Parent**: SchemaNode

---

### SchemaNode
**Purpose**: Represents a schema definition

**Attribute**:
- `name`: Optional schema name
- `field`: List of FieldNode
- `type`: Atom schema type (`:struct`, `:array`, etc.)

**Children**: FieldNode list

---

### TypeNode
**Purpose**: Represents a type annotation

**Attribute**:
- `name`: Atom type name (`:string`, `:integer`, etc.)
- `parameter`: List of type parameter (for generic type)

**Example**:
- Simple: `TypeNode{name: :string}`
- Generic: `TypeNode{name: :array, parameter: [TypeNode{name: :integer}]}`

---

### TransformNode
**Purpose**: Represents a transformation

**Attribute**:
- `operation`: Atom operation type (`:map`, `:filter`, `:reduce`)
- `function`: Function reference or lambda
- `input`: Input node
- `output`: Expected output type

---

### Traversal
**Purpose**: Visitor pattern for AST navigation

**Strategy**:
- Depth-first search (DFS)
- Breadth-first search (BFS)
- Custom order

**Function**: `traverse(node, visitor_fn)`

**Visitor Signature**: `(node, acc) -> {continue | halt, new_acc}`

---

### Transformer
**Purpose**: AST rewrite function

**Signature**: `(node) -> node`

**Use Case**:
- Optimization: Remove unnecessary node
- Rewrite: Change node structure
- Analysis: Extract information from AST

**Pattern**:
```elixir
defmodule MyTransformer do
  def optimize(node) do
    case node do
      %FieldNode{required: false, default: nil} -> 
        %{node | required: true}  # Make field required if no default
      other -> 
        other
    end
  end
end
```

---

## Entity Relationship

### Raggio.Schema Relationship

```
Schema (1) ----contains----> (*) Field
Field (1) ----has----> (1) Type
Schema (1) ----has----> (*) Validator
Schema (1) ----validates----> (1) ValidationResult
ValidationResult (1) ----contains----> (*) ValidationError
```

**Composition Relationship**:
```
Schema ----composes----> Schema  (may fail with CompositionError)
Validator ----composes----> Validator
Transformer ----chains----> Transformer
```

### Raggio.Syntax Relationship

```
AST (1) ----has----> (1) Node (root)
SchemaNode (1) ----contains----> (*) FieldNode
FieldNode (1) ----has----> (1) TypeNode
Node (*) ----parent/child----> (*) Node (tree structure)
Traversal ----visits----> (*) Node
Transformer ----transforms----> Node (produces new Node)
```

---

## State Transition

### Schema State
```
draft → validated → ready
  ↓         ↓          ↓
error    error      usable
```

**Trigger**:
- `draft → validated`: Call `validate/2`
- `validated → ready`: Validation succeed
- `* → error`: Validation fail or composition error

### ValidationResult State
```
pending → success
    ↓
    → failure
```

**Trigger**:
- `pending → success`: All validation pass
- `pending → failure`: At least one validation fail

### AST State
```
constructed → traversed → transformed
     ↓            ↓            ↓
  usable       analyzed     modified
```

**Trigger**:
- `constructed → traversed`: Call `traverse/2`
- `traversed → transformed`: Call `transform/2`

---

## Data Flow

### Raggio.Schema Validation Flow
```
Input Data
    ↓
Schema.validate(schema, data)
    ↓
Apply Validator (accumulate error)
    ↓
ValidationResult {:ok, data} | {:error, [error]}
```

### Raggio.Schema Composition Flow
```
Schema A + Schema B
    ↓
Check type compatibility (composition time)
    ↓
Compatible? → Merge constraint and validator
    ↓
Not compatible? → CompositionError
```

### Raggio.Syntax Traversal Flow
```
AST
    ↓
traverse(ast, visitor)
    ↓
Visit each node (DFS/BFS)
    ↓
Apply visitor function
    ↓
Accumulate result
```

### Raggio.Syntax Transformation Flow
```
AST
    ↓
transform(ast, transformer)
    ↓
Apply transformer to each node
    ↓
Build new AST with transformed node
    ↓
New AST
```

---

## Constraint and Invariant

### Raggio.Schema Constraint
1. Schema type must be valid (one of supported type)
2. Constraint must be applicable to type
3. Struct schema must have at least one field
4. Array schema must specify element type
5. Enum schema must have at least one value
6. Required field cannot have `nil` value

### Raggio.Syntax Constraint
1. AST must have exactly one root node
2. FieldNode must have valid TypeNode
3. SchemaNode with struct type must have field list
4. TypeNode name must be valid type identifier
5. Node cannot be its own ancestor (no cycle in tree)
6. TransformNode input/output type must be specified

---

## Migration from old_code

### old_code Structure Mapping

**old_code/data_schema → Raggio.Schema**:
- `data_schema.ex` → `raggio_schema.ex` (entry point)
- `builders.ex` → `builder.ex` (schema builder)
- `parser.ex` → `validator.ex` (validation logic)
- `field.ex` → Field struct definition
- `types/*.ex` → `type/*.ex` (type definition)
- `transformer.ex` → `transformer.ex` (data transformation)

**old_code/data_schema/ast → Raggio.Syntax**:
- `ast.ex` → `ast.ex` (AST definition)
- `field.ex` → `node/field.ex` (FieldNode)
- `schema.ex` → `node/schema.ex` (SchemaNode)
- `*_type.ex` → `node/type.ex` (TypeNode with variant)
- `transform_type.ex` → `node/transform.ex` (TransformNode)

### Preservation Strategy
- Existing functionality preserved as function in new package
- Macro eliminated; replaced with function composition
- API redesigned for composability
- Test migrated to new structure

---

## Summary

**Raggio.Schema**: 7 core entity (Schema, Field, Type, Validator, ValidationResult, ValidationError, Transformer) with composition and validation flow

**Raggio.Syntax**: 7 core entity (AST, Node, FieldNode, SchemaNode, TypeNode, TransformNode, Traversal) with tree structure and transformation flow

**Key Design Principle**:
- Immutable data structure (entity are value, not reference)
- Pure function (no side effect)
- Explicit error (no exception, use Result tuple)
- Composable (small function combine into larger behavior)
- Type safety (pattern matching and guard ensure invariant)
