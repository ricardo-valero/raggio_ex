# Data Model: Multi-Package Monorepo Restructure

**Feature**: Multi-Package Monorepo Restructure  
**Branch**: `001-monorepo-restructure`  
**Date**: 2026-01-12

This document defines all entities, their attributes, relationships, and state transitions for the Raggio.Schema and Raggio.Syntax packages.

---

## 1. Raggio.Schema Entities

### 1.1 Schema

Represents a complete schema definition with type information, constraints, and metadata.

**Attributes**:
- `type` (atom, required) - Base type identifier (`:string`, `:integer`, `:struct`, etc.)
- `encoded` (atom, required) - Wire format type for encoding/decoding
- `filters` (list, optional) - List of constraint tuples or Filter structs
- `annotations` (map, optional) - Metadata including description, custom error messages
- `fields` (map, optional) - For `:struct` type, map of field_name => nested Schema
- `inner_type` (Schema.t, optional) - For `:list` and `:array` types, schema of elements
- `types` (list(Schema.t), optional) - For `:union` type, list of alternative schemas

**Example**:
```elixir
%Raggio.Schema{
  type: :string,
  encoded: :string,
  filters: [
    {:min_length, 3},
    {:max_length, 50},
    {:pattern, ~r/^[a-z0-9_]+$/}
  ],
  annotations: %{
    description: "Username",
    message: "Invalid username format"
  }
}
```

**State Transitions**:
```
[Construction] → [Validated] → [Executed]
     ↓              ↓              ↓
  Building      Type checking   Validation
  constraints   constraints     against data
```

---

### 1.2 Filter

Represents a single validation constraint that can be applied to data.

**Attributes**:
- `predicate` (function, required) - Validation function: `(value) -> boolean | {:error, message}`
- `path` (list, optional) - Path to field being validated (for nested structures)
- `message` (string, optional) - Custom error message
- `metadata` (map, optional) - Additional constraint metadata

**Example**:
```elixir
%Filter{
  predicate: fn value -> String.length(value) >= 3 end,
  path: [:user, :username],
  message: "Username must be at least 3 characters",
  metadata: %{constraint_type: :min_length, value: 3}
}
```

---

### 1.3 ValidationResult

Represents the outcome of validating data against a schema.

**Attributes**:
- `status` (atom, required) - `:ok` or `:error`
- `data` (any, for `:ok`) - Parsed and validated data
- `errors` (list(ValidationError), for `:error`) - List of validation failures

**Example**:
```elixir
# Success
{:ok, %{username: "alice_j", age: 28}}

# Failure
{:error, [
  %ValidationError{
    path: [:username],
    message: "Username too short",
    value: "al"
  },
  %ValidationError{
    path: [:age],
    message: "Must be at least 13",
    value: 10
  }
]}
```

---

### 1.4 ValidationError

Represents a single validation failure with context.

**Attributes**:
- `path` (list, required) - Path to failed field as list of atoms/integers (e.g., `[:user, :addresses, 2, :zipcode]`)
- `message` (string, required) - Human-readable error description
- `value` (any, required) - The actual invalid value that failed validation
- `constraint` (atom, optional) - Type of constraint that failed (`:min_length`, `:pattern`, etc.)

**Example**:
```elixir
%ValidationError{
  path: [:user, :email],
  message: "Invalid email format",
  value: "not-an-email",
  constraint: :email
}
```

---

### 1.5 BigQueryDDL

Represents a generated BigQuery DDL statement.

**Attributes**:
- `table_name` (string, required) - Fully-qualified or simple table name
- `columns` (list(ColumnDef), required) - List of column definitions
- `partition_by` (string, optional) - PARTITION BY clause
- `cluster_by` (list(string), optional) - CLUSTER BY fields
- `options` (map, optional) - Additional table options

**Relationships**:
- Generated from one Schema
- Contains multiple ColumnDef entities

**Example**:
```elixir
%BigQueryDDL{
  table_name: "project.dataset.users",
  columns: [
    %ColumnDef{name: "id", type: "INT64", mode: "REQUIRED"},
    %ColumnDef{name: "email", type: "STRING", mode: "REQUIRED"}
  ],
  partition_by: "DATE(created_at)",
  cluster_by: ["id", "status"]
}
```

---

### 1.6 ColumnDef

Represents a single column in BigQuery DDL.

**Attributes**:
- `name` (string, required) - Column name
- `type` (string, required) - BigQuery type (STRING, INT64, STRUCT<...>, etc.)
- `mode` (string, optional) - "REQUIRED", "NULLABLE", or "REPEATED" (default: "NULLABLE")
- `default` (string, optional) - Default value expression
- `description` (string, optional) - Column description

**Example**:
```elixir
%ColumnDef{
  name: "email",
  type: "STRING",
  mode: "REQUIRED",
  description: "User email address"
}

# Nested STRUCT
%ColumnDef{
  name: "address",
  type: "STRUCT<street STRING, city STRING NOT NULL>",
  mode: "NULLABLE"
}
```

---

### 1.7 SheetSchema

Represents a parsed spreadsheet schema definition.

**Attributes**:
- `rows` (list(SheetRow), required) - List of field definitions from spreadsheet
- `source_url` (string, optional) - Google Sheets URL if imported remotely
- `sheet_name` (string, optional) - Name of sheet within spreadsheet
- `parsed_at` (DateTime.t, required) - When sheet was parsed

**Relationships**:
- Contains multiple SheetRow entities
- Converts to one Schema

**Example**:
```elixir
%SheetSchema{
  rows: [
    %SheetRow{field_name: "email", type: "string", required: true, constraints: "email() | max_length(255)"},
    %SheetRow{field_name: "age", type: "integer", required: false, constraints: "min(13) | max(120)"}
  ],
  source_url: "https://docs.google.com/spreadsheets/d/abc123",
  sheet_name: "UserSchema",
  parsed_at: ~U[2026-01-12 10:30:00Z]
}
```

---

### 1.8 SheetRow

Represents a single row from SheetSchema spreadsheet.

**Attributes**:
- `field_name` (string, required) - Field identifier
- `type` (string, required) - Type expression
- `required` (boolean, optional, default: false) - Whether field is required
- `constraints` (string, optional) - Pipe-separated constraint functions
- `description` (string, optional) - Human-readable documentation
- `example` (string, optional) - Example value
- `default` (string, optional) - Default value
- `parent_path` (string, optional) - Dot-notation nesting path

**Example**:
```elixir
%SheetRow{
  field_name: "username",
  type: "string",
  required: true,
  constraints: "min_length(3) | max_length(30) | pattern(^[a-z0-9_]+$)",
  description: "Login username",
  example: "alice_j",
  default: nil,
  parent_path: nil  # Top-level field
}

# Nested field
%SheetRow{
  field_name: "street",
  type: "string",
  required: false,
  constraints: "max_length(100)",
  description: "Street address",
  example: "123 Main St",
  default: nil,
  parent_path: "address"  # Nested in address
}
```

---

## 2. Raggio.Syntax Entities

### 2.1 SyntaxTree

Represents a complete syntax tree with metadata.

**Attributes**:
- `root` (Node.t, required) - Root node of the tree
- `metadata` (map, optional) - Tree-level metadata

**Example**:
```elixir
%SyntaxTree{
  root: %SchemaNode{
    name: :user,
    fields: [...]
  },
  metadata: %{
    version: "1.0",
    created_at: ~U[2026-01-12 10:00:00Z]
  }
}
```

---

### 2.2 Node (Protocol)

Base protocol that all node types implement.

**Required Functions**:
- `node_type/1` - Returns node type atom (`:schema`, `:field`, `:type`, `:transform`)
- `children/1` - Returns list of child nodes

---

### 2.3 SchemaNode

Represents a schema definition node in the syntax tree.

**Attributes**:
- `type` (atom, required) - Always `:schema`
- `name` (atom, required) - Schema name
- `fields` (list(FieldNode), required) - List of field definitions
- `schema_type` (atom, optional) - `:struct`, `:union`, `:enum` (default: `:struct`)
- `metadata` (map, optional) - Node metadata

**Example**:
```elixir
%SchemaNode{
  type: :schema,
  name: :user,
  fields: [
    %FieldNode{name: :email, field_type: %TypeNode{name: :string}},
    %FieldNode{name: :age, field_type: %TypeNode{name: :integer}}
  ],
  schema_type: :struct,
  metadata: %{}
}
```

**Relationships**:
- Contains multiple FieldNode children
- Root of schema definition

---

### 2.4 FieldNode

Represents a field within a schema.

**Attributes**:
- `type` (atom, required) - Always `:field`
- `name` (atom, required) - Field name
- `field_type` (TypeNode, required) - Type of the field
- `required` (boolean, optional, default: false) - Whether field is required
- `default` (any, optional) - Default value
- `metadata` (map, optional) - Field metadata

**Example**:
```elixir
%FieldNode{
  type: :field,
  name: :email,
  field_type: %TypeNode{
    name: :string,
    constraints: [:email, {:max_length, 255}]
  },
  required: true,
  default: nil,
  metadata: %{description: "User email address"}
}
```

**Relationships**:
- Belongs to one SchemaNode
- Has one TypeNode

---

### 2.5 TypeNode

Represents a type specification.

**Attributes**:
- `type` (atom, required) - Always `:type`
- `name` (atom, required) - Type name (`:string`, `:integer`, `:list`, `:struct`, etc.)
- `parameters` (list, optional) - Type parameters (for generic types like `list(string)`)
- `constraints` (list, optional) - List of constraint tuples
- `metadata` (map, optional) - Type metadata

**Example**:
```elixir
# Simple type
%TypeNode{
  type: :type,
  name: :string,
  parameters: [],
  constraints: [],
  metadata: %{}
}

# Generic type
%TypeNode{
  type: :type,
  name: :list,
  parameters: [
    %TypeNode{name: :string, constraints: [email: true]}
  ],
  constraints: [min_items: 1, max_items: 10],
  metadata: %{}
}
```

---

### 2.6 TransformNode

Represents a transformation operation on a syntax tree.

**Attributes**:
- `type` (atom, required) - Always `:transform`
- `operation` (atom, required) - Operation type (`:rename`, `:add_field`, `:remove_field`, `:modify_type`, etc.)
- `target` (term, required) - What to transform (pattern or path)
- `transformer` (function, required) - Transformation function
- `metadata` (map, optional) - Transform metadata

**Example**:
```elixir
%TransformNode{
  type: :transform,
  operation: :rename_field,
  target: {:field, :old_name},
  transformer: fn field_node -> 
    %{field_node | name: :new_name}
  end,
  metadata: %{reason: "API migration"}
}
```

---

## 3. Entity Relationships

### Raggio.Schema Relationships

```
Schema
  ├─ filters: [Filter]
  ├─ fields: %{name => Schema}  (for struct types)
  └─ annotations: %{metadata}

ValidationResult
  ├─ data: any (for :ok status)
  └─ errors: [ValidationError] (for :error status)

SheetSchema
  ├─ rows: [SheetRow]
  └─ converts_to: Schema

BigQueryDDL
  ├─ generated_from: Schema
  └─ columns: [ColumnDef]
```

### Raggio.Syntax Relationships

```
SyntaxTree
  └─ root: Node

SchemaNode (implements Node)
  └─ fields: [FieldNode]

FieldNode (implements Node)
  └─ field_type: TypeNode

TypeNode (implements Node)
  └─ parameters: [TypeNode]  (for generic types)

TransformNode (implements Node)
  └─ applies_to: Node
```

---

## 4. State Transitions

### Schema Validation Flow

```
[Input Data] → [Schema] → [Validation Engine] → [ValidationResult]
                   ↓
              [Filters Applied]
                   ↓
          [Success Path | Error Path]
                   ↓              ↓
              {:ok, data}    {:error, [errors]}
```

### Syntax Tree Transformation Flow

```
[Source Tree] → [Transform Accumulation] → [Apply Transforms] → [Result Tree]
                        ↓
                [TransformNode list]
                        ↓
                [Sequential Application]
```

### SheetSchema Import Flow

```
[Spreadsheet] → [Parse Rows] → [Group by parent_path] → [Build Tree] → [Generate Code]
      ↓               ↓                  ↓                     ↓              ↓
  CSV/TSV        SheetRow list      Nested map          Schema tree    Elixir code
```

### BigQuery Export Flow

```
[Schema] → [Type Mapping] → [Column Generation] → [DDL Formatting] → [SQL String]
    ↓             ↓                  ↓                    ↓                 ↓
 Analyze      Map types        Build ColumnDef       Format SQL      Output DDL
```

---

## 5. Validation Rules

### Raggio.Schema Rules

1. **Schema Integrity**:
   - `type` must be a known type atom
   - `filters` must be list of valid constraint tuples or Filter structs
   - `fields` (for struct) must be map with atom keys and Schema values
   - Circular references in nested structs are prohibited

2. **Filter Constraints**:
   - `predicate` must be a function with arity 1
   - Must return boolean, `{:error, message}`, or `:ok`
   - `path` must be list of atoms and/or integers

3. **Validation Results**:
   - `path` in ValidationError must accurately represent nesting
   - Multiple errors for same path are allowed (collected mode)
   - Errors must include original invalid `value` for debugging

### Raggio.Syntax Rules

1. **Node Structure**:
   - Every node must have `type` field matching its module (`:schema`, `:field`, `:type`, `:transform`)
   - `SchemaNode.fields` must be list of FieldNode
   - `FieldNode.field_type` must be valid TypeNode
   - Circular references in type parameters are prohibited

2. **Tree Integrity**:
   - SyntaxTree must have exactly one root node
   - All child relationships must form a valid tree (no cycles)
   - Transform operations must preserve tree validity

3. **Type Parameters**:
   - Generic types (list, map) must have valid parameter types
   - Union types must have at least 2 alternatives
   - Tuple types must specify all element types

---

## 6. Identity & Uniqueness

### Raggio.Schema

- **Schema**: No unique identifier (value-based equality)
- **Filter**: No unique identifier (value-based equality)
- **ValidationError**: Uniquely identified by `path` within a ValidationResult
- **SheetRow**: Uniquely identified by combination of `field_name` and `parent_path`

### Raggio.Syntax

- **Node**: No unique identifier (structural equality)
- **SyntaxTree**: No unique identifier (structural equality)
- **Path-based identity**: Nodes can be identified by path from root (e.g., `[:fields, 0, :field_type]`)

---

## 7. Data Volume Assumptions

- **Schema depth**: Maximum nesting level ~10 for practical use
- **Fields per schema**: Typically 10-50, support up to 1000
- **Validation errors**: Collect up to 100 errors per validation (configurable)
- **SheetSchema rows**: Support up to 1000 rows per sheet
- **Syntax tree nodes**: Support up to 10,000 nodes per tree
- **Transform operations**: Support chaining up to 100 transforms

---

*Data model complete. All entities, relationships, and rules defined for implementation.*
