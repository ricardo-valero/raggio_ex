# Feature Specification: Drizzle-like Composable BigQuery API

**Feature Branch**: `004-drizzle-bq-api`  
**Created**: 2026-01-17  
**Status**: Draft  
**Input**: User description: "whats the status of our bigquery adapter, how far off are we from the drizzle-api, i want to match it more closely, it should be a combination of drizzle and effect-ts/schema we should be able to compose the project_id, dataset schema and tables schemas lets see alteratives on how to the api might look like (we should use raggio.schema and/or raggio.syntax exensively) also maybe use nimble_parsec to create a ddl builder (similar to nimble_csv or is this too farfetched)"

## Clarifications

### Session 2026-01-17

- Q: What is the relationship between raggio.schema and adapter-specific schemas (like BigQuery)? → A: Canonical raggio.schema - raggio.schema.Type is THE portable schema format; BigQuery/API/JSON-Schema are adapters that convert to/from it
- Q: Which adapters beyond BigQuery should be included in the initial scope? → A: BigQuery adapter only, with documented extensible adapter pattern for future adapters (API, JSON-Schema, etc.)
- Q: How should the adapter extension point be implemented? → A: Behaviour with callbacks - `@behaviour Raggio.Schema.Adapter` with `to_schema/1` and `from_schema/1` callbacks
- Q: What happens to adapter-specific metadata during cross-adapter conversion? → A: Preserve in metadata, warn on export - keep in Type.metadata under adapter namespace; warn when exporting to adapter that can't use it

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define Composable BigQuery Project (Priority: P1)

As a developer, I want to define my BigQuery schema hierarchy using a composable, declarative API similar to Drizzle, so that I can organize my tables by dataset and reference them with full type safety.

**Why this priority**: This is the foundation of the entire feature - without hierarchical composition (project -> dataset -> tables), the Drizzle-like experience cannot be achieved. Enables clean organization and discoverability.

**Independent Test**: Can be fully tested by defining a project with nested datasets and tables, then verifying the resulting schema structure contains correct hierarchy and metadata. Delivers value by providing a single entry point to define all BigQuery resources.

**Acceptance Scenarios**:

1. **Given** a developer wants to define a BigQuery project, **When** they use the composable API to define project_id, datasets, and tables in a nested structure, **Then** the resulting schema object contains the complete hierarchy accessible via dot notation or pattern matching.
2. **Given** a project definition exists with multiple datasets, **When** the developer queries for a specific table, **Then** they can access it via `project.dataset.table` or equivalent composition.
3. **Given** a table definition references schema types from raggio.schema, **When** the schema is validated, **Then** all type constraints are enforced at definition time.

---

### User Story 2 - Generate DDL from Composed Schema (Priority: P2)

As a developer, I want to generate BigQuery DDL statements from my composed schema definitions, so that I can create or migrate my BigQuery infrastructure declaratively.

**Why this priority**: Once schemas are defined (P1), the natural next step is generating DDL for deployment. This bridges definition to execution.

**Independent Test**: Can be fully tested by taking a composed schema and generating CREATE TABLE, CREATE SCHEMA statements, then validating the SQL syntax and completeness.

**Acceptance Scenarios**:

1. **Given** a composed project schema with tables, **When** DDL generation is invoked, **Then** valid BigQuery CREATE TABLE statements are produced for each table.
2. **Given** a schema with partitioning and clustering options, **When** DDL is generated, **Then** the resulting SQL includes correct PARTITION BY and CLUSTER BY clauses.
3. **Given** nested STRUCT/RECORD types in a schema, **When** DDL is generated, **Then** the nested structure is correctly represented in BigQuery schema format.

---

### User Story 3 - Parse DDL into Schema Definitions (Priority: P3)

As a developer, I want to parse existing BigQuery DDL into raggio schema definitions, so that I can import existing table definitions into my composable schema hierarchy.

**Why this priority**: Enables adoption for existing BigQuery users who have tables already defined. Provides round-trip capability (schema -> DDL -> schema).

**Independent Test**: Can be fully tested by parsing valid BigQuery DDL strings and verifying the resulting schema objects match expected structure.

**Acceptance Scenarios**:

1. **Given** a valid BigQuery CREATE TABLE DDL statement, **When** parsed, **Then** a corresponding raggio.schema type definition is produced.
2. **Given** DDL with complex nested STRUCT types, **When** parsed, **Then** the nested structure is correctly represented as composed raggio.schema types.
3. **Given** DDL with partitioning and clustering, **When** parsed, **Then** the metadata is preserved in the resulting schema definition.

---

### User Story 4 - Effect-TS/Schema Style Composition (Priority: P2)

As a developer, I want to compose schemas using functional combinators similar to Effect-TS/Schema, so that I can build complex types from simple building blocks with transformations.

**Why this priority**: This differentiates the API from basic ORM patterns and enables powerful schema transformations and refinements inline.

**Independent Test**: Can be fully tested by composing schemas with pipe operators, transformations, and refinements, then validating the composed result.

**Acceptance Scenarios**:

1. **Given** basic schema types, **When** composed using pipe operators with transformations, **Then** the resulting schema applies all transformations in order.
2. **Given** a schema with refinement constraints, **When** data is validated against it, **Then** all refinements are checked and violations reported.
3. **Given** multiple schemas, **When** combined using union, intersection, or extend operations, **Then** the resulting schema correctly represents the combined type.

---

### Edge Cases

- What happens when a table is defined with an invalid column type? System rejects at definition time with clear error message.
- What happens when DDL parsing encounters unsupported BigQuery syntax? Parser returns structured error indicating unsupported construct and position.
- What happens when project_id or dataset names contain invalid characters? Validation fails at definition time with constraint violation error.
- What happens when circular schema references are attempted? System detects cycle and rejects with informative error.
- What happens when parsing DDL with BigQuery-specific extensions not in standard SQL? Parser recognizes BigQuery dialect features or explicitly ignores unknown clauses with warnings.
- What happens when converting BigQuery schema to raggio.schema and BigQuery-specific features (partitioning, clustering) don't map? Adapter-specific metadata is preserved in Type.metadata but marked as non-portable; conversion to other adapters ignores or warns about unmapped features.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow defining BigQuery schemas using a hierarchical composition pattern (project -> dataset -> table)
- **FR-002**: System MUST integrate with raggio.schema types for column definitions, supporting all existing types (string, integer, decimal, datetime, etc.)
- **FR-003**: System MUST support defining table metadata including partitioning strategy, clustering columns, and descriptions
- **FR-004**: System MUST generate valid BigQuery DDL statements from composed schema definitions
- **FR-005**: System MUST support parsing BigQuery CREATE TABLE DDL into schema definitions
- **FR-006**: System MUST support functional composition patterns (pipe, transform, refine) for building complex schemas
- **FR-007**: System MUST provide clear error messages when schema definitions violate constraints
- **FR-008**: System MUST support STRUCT/RECORD nested types in both definition and DDL generation
- **FR-009**: System MUST support REPEATED (array) types in schema definitions
- **FR-010**: System MUST leverage raggio.syntax for AST representation when parsing DDL
- **FR-011**: System MUST treat raggio.schema.Type as the canonical, portable schema format from which all adapter-specific schemas derive
- **FR-012**: System MUST support bidirectional conversion: raggio.schema ↔ BigQuery schema (and future adapters like API/JSON-Schema)
- **FR-013**: System MUST allow deriving a raggio.schema.Type from any BigQuery.TableDef for use with other adapters
- **FR-014**: System MUST allow creating a BigQuery.TableDef from any compatible raggio.schema.Type
- **FR-015**: System MUST define `Raggio.Schema.Adapter` behaviour with `to_schema/1` (adapter format → raggio.schema) and `from_schema/1` (raggio.schema → adapter format) callbacks that future adapters implement
- **FR-016**: System MUST preserve adapter-specific metadata in `Type.metadata` under namespaced keys (e.g., `bigquery: %{partition_by: ...}`) during `to_schema/1` conversion
- **FR-017**: System MUST emit warnings when `from_schema/1` encounters metadata from a different adapter that cannot be mapped to the target format

### Out of Scope (This Feature)

- API endpoint generation adapter (future feature using the established pattern)
- JSON-Schema adapter (future feature using the established pattern)
- Other database adapters (PostgreSQL, MySQL, etc.)

### Key Entities

- **Project**: Top-level container representing a BigQuery project, identified by project_id. Contains datasets.
- **Dataset**: Container within a project that groups related tables. Has a name and optional default settings (location, access controls metadata).
- **Table**: Schema definition for a BigQuery table. Contains columns, partitioning config, clustering config, and metadata.
- **Column**: Individual field within a table, references a raggio.schema type with mode (NULLABLE, REQUIRED, REPEATED).
- **DDL Statement**: Parsed or generated SQL statement representing schema changes.
- **Adapter**: Behaviour defining `to_schema/1` and `from_schema/1` callbacks for bidirectional conversion between raggio.schema.Type and adapter-specific formats. BigQuery adapter is the reference implementation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can define a complete BigQuery project schema (3+ datasets, 10+ tables) in under 100 lines of declarative code
- **SC-002**: 100% of schema definitions produce valid BigQuery DDL when exported
- **SC-003**: DDL parsing correctly handles 95% of real-world BigQuery CREATE TABLE statements
- **SC-004**: Schema composition operations complete validation within 50ms for typical project sizes
- **SC-005**: Error messages identify the exact location and nature of schema violations in 100% of validation failures
- **SC-006**: Round-trip conversion (schema -> DDL -> schema) preserves all semantic information for supported constructs
- **SC-007**: Cross-adapter conversion emits clear warnings listing any adapter-specific features that could not be mapped to the target format

## API Alternatives Analysis

This section documents the explored API alternatives for achieving Drizzle-like composition.

### Alternative A: Nested Module Pattern (Drizzle-inspired)

```
project("my-gcp-project")
|> dataset("analytics", [
     table("events", [...columns...]),
     table("users", [...columns...])
   ])
|> dataset("billing", [
     table("invoices", [...columns...])
   ])
```

**Pros**: Familiar to Drizzle users, clear hierarchy, pipeable
**Cons**: Requires careful macro implementation, module-level state

### Alternative B: Schema Builder Pattern (Effect-TS inspired)

```
Schema.bigquery()
|> Schema.project("my-gcp-project")
|> Schema.dataset("analytics")
|> Schema.table("events")
|> Schema.column("id", Schema.string() |> Schema.required())
|> Schema.column("timestamp", Schema.datetime() |> Schema.partition_by(:day))
|> Schema.end_table()
|> Schema.end_dataset()
```

**Pros**: Very explicit, no hidden state, easy to understand
**Cons**: Verbose, requires explicit end markers

### Alternative C: Struct-based Composition (Current raggio.schema style)

```
%BigQuery.Project{
  project_id: "my-gcp-project",
  datasets: [
    %BigQuery.Dataset{
      name: "analytics",
      tables: [
        %BigQuery.Table{
          name: "events",
          schema: Schema.struct([{:id, Schema.string()}, ...])
        }
      ]
    }
  ]
}
```

**Pros**: Pure data, serializable, pattern-matchable
**Cons**: Less ergonomic for inline definition, nested maps

### Alternative D: Macro-based DSL (Similar to Ecto)

```
defmodule MyProject do
  use Raggio.BigQuery.Project, project_id: "my-gcp-project"

  dataset :analytics do
    table :events do
      column :id, :string, required: true
      column :timestamp, :datetime, partition_by: :day
    end
  end
end
```

**Pros**: Very clean syntax, compile-time validation possible
**Cons**: Magic-heavy, harder to compose dynamically

### DDL Parser Approach Analysis

**NimbleParsec Option**: Create a grammar-based parser using NimbleParsec combinators to parse BigQuery DDL syntax. Similar to how NimbleCSV provides a declarative way to define CSV parsing.

**Pros**: 
- Formal grammar, maintainable
- Good error messages with position
- Extensible for BigQuery dialect features
- Fast, compiled parser

**Cons**:
- Learning curve for parser combinators
- BigQuery DDL is complex (nested structs, options, expressions)
- May be overkill if only CREATE TABLE is needed

**Regex/String Pattern Option**: Use pattern matching and regex to extract DDL components.

**Pros**: Simpler to implement initially
**Cons**: Fragile, poor error messages, hard to extend

**Recommended**: NimbleParsec for formal DDL parsing, as it provides the robustness needed for production use and aligns with the "declarative builder" philosophy.

## Assumptions

- BigQuery DDL parsing will focus on CREATE TABLE/CREATE SCHEMA statements initially; ALTER TABLE and other DDL can be added incrementally.
- The composable API will coexist with the existing `use Raggio.BigQuery.Table` behaviour pattern, not replace it.
- NimbleParsec is an acceptable dependency for the DDL parsing functionality.
- Performance requirements are for development-time operations, not runtime query execution.
- The API should prioritize explicitness and discoverability over brevity.
- **raggio.schema.Type is the canonical schema format** - all adapter-specific schemas (BigQuery, API, JSON-Schema) convert to/from it, enabling "define once, deploy anywhere" workflows.
- Adapter-specific features (e.g., BigQuery partitioning) are stored in Type.metadata and preserved during round-trips but may not be portable to all target adapters.
