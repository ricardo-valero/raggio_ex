# Syntax Capability

## ADDED Requirements

### Requirement: Node builders

`Raggio.Syntax` SHALL provide composable, macro-free builders for syntax nodes: `schema/1` and `schema/2` (build a schema node from a list of field nodes, optionally named), `field/2` and `field/3` (build a field node from a name and type node, with opts `required` and `default`), and `type/1` and `type/2` (build a type node from a type name, optionally with parameter type nodes for generics).

#### Scenario: Build a field node with a type

- **WHEN** a developer calls `Syntax.field(:age, Syntax.type(:integer))`
- **THEN** a field node named `:age` is returned referencing an integer type node

#### Scenario: Build a generic type node

- **WHEN** a developer calls `Syntax.type(:list, [Syntax.type(:string)])`
- **THEN** a type node for `list` is returned parameterized by a string type node

#### Scenario: Compose nodes into a schema node

- **WHEN** a developer calls `Syntax.schema([field_a, field_b])`
- **THEN** a schema node is returned containing both field nodes as children

### Requirement: Tree wrapper

`Raggio.Syntax` SHALL provide `ast/1` and `ast/2` to wrap a root node into a syntax tree, with `ast/2` attaching tree-level metadata.

#### Scenario: Wrap a node into a tree with metadata

- **WHEN** a developer calls `Syntax.ast(root_node, %{source: "user.ex"})`
- **THEN** a syntax tree is returned whose root is the node and whose metadata carries the supplied map

### Requirement: Traversal combinators

`Raggio.Syntax` SHALL provide traversal combinators over a tree or node: `traverse/2` (depth-first visitor), `traverse/3` (depth-first traversal with an accumulator/reducer), `find/2` (first node matching a predicate, or nil), and `find_all/2` (all matching nodes). Traversal SHALL visit nodes in a predictable order.

#### Scenario: Depth-first traversal visits all nodes

- **WHEN** a developer calls `Syntax.traverse(tree, visitor_fn)`
- **THEN** the visitor is invoked for every node in depth-first order

#### Scenario: Find first matching node

- **WHEN** a developer calls `Syntax.find(tree, predicate)` and a node matches
- **THEN** the first matching node is returned; if none match, `nil` is returned

#### Scenario: Accumulate over the tree

- **WHEN** a developer calls `Syntax.traverse/3` with an accumulator and reducer
- **THEN** the reducer folds over every node and the final accumulator is returned

### Requirement: Transformations preserve structural integrity

`Raggio.Syntax` SHALL provide `transform/2` (apply a transformer function to every node), `filter/2` (remove nodes that do not match a predicate), and `replace/3` (replace a specific target node with a replacement). Transformations SHALL return a tree or node that maintains structural integrity.

#### Scenario: Transform every node

- **WHEN** a developer calls `Syntax.transform(tree, transformer_fn)`
- **THEN** a new tree is returned with the transformer applied to each node and the overall structure intact

#### Scenario: Replace a specific node

- **WHEN** a developer calls `Syntax.replace(tree, target_node, replacement_node)`
- **THEN** a new tree is returned in which the target node is replaced by the replacement node

### Requirement: Query helpers

`Raggio.Syntax` SHALL provide query helpers: `get_fields/1` (the field nodes of a schema node), `get_field/2` (a specific field node by name, or nil), and `get_children/1` (the immediate children of a node).

#### Scenario: Get a named field from a schema node

- **WHEN** a developer calls `Syntax.get_field(schema_node, :age)` and the field exists
- **THEN** the corresponding field node is returned; if absent, `nil` is returned

### Requirement: Node protocol

`Raggio.Syntax` SHALL define a `Raggio.Syntax.Node` protocol exposing `node_type/1` (the node's type atom) and `children/1` (the node's child nodes), allowing traversal and transformation to operate uniformly over node structs.

#### Scenario: Query a node's type and children via the protocol

- **WHEN** `Raggio.Syntax.Node.node_type/1` and `children/1` are called on a node struct
- **THEN** the node's type atom and its list of child nodes are returned
