# Feature Specification: Composable BigQuery Schema API

**Feature Branch**: `001-bigquery-schema-api`  
**Created**: 2026-01-17  
**Status**: Draft  
**Input**: User description: "Align the BigQuery adapter with a modern schema-first DSL; enable composition of project, dataset, and table schemas; explore alternative API shapes; optionally support generating DDL from the composed schema."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compose Project + Dataset + Tables (Priority: P1)

As a developer, I want to define a BigQuery project, one or more datasets, and their table schemas using composable building blocks, so I can reuse schema definitions across environments and keep schema definitions consistent.

**Why this priority**: This is the core capability required to make the adapter feel “schema-first” and reduce duplication.

**Independent Test**: Can be fully tested by defining a project with one dataset and one table, then producing a complete, deterministic schema representation.

**Acceptance Scenarios**:

1. **Given** a project identifier and a dataset definition, **When** a table schema is attached to the dataset, **Then** the resulting composed schema includes all identifiers and table definitions.
2. **Given** a reusable table schema definition, **When** it is used in two separate dataset definitions, **Then** both datasets contain equivalent table schemas without duplicating the schema definition.

---

### User Story 2 - Validate Schema Definitions Early (Priority: P2)

As a developer, I want schema definitions to be validated at definition time (or at a single explicit “finalize/compile” step), so schema mistakes are caught before deployment.

**Why this priority**: Early validation reduces runtime surprises and supports confident iteration.

**Independent Test**: Can be tested by attempting to define an invalid schema (e.g., invalid names, conflicting columns) and confirming the system reports actionable errors.

**Acceptance Scenarios**:

1. **Given** a schema with an invalid identifier, **When** validation is executed, **Then** the system reports a clear error describing the invalid field.
2. **Given** a schema with conflicting definitions (e.g., duplicate table name in the same dataset), **When** validation is executed, **Then** the system reports the conflict and points to the source definition.

---

### User Story 3 - Generate DDL From Schema (Priority: P3)

As a developer, I want to generate BigQuery DDL statements from the composed schema, so I can review changes, run migrations, or apply them in CI.

**Why this priority**: DDL generation is the most direct “output artifact” and bridges the schema DSL to real usage.

**Independent Test**: Can be tested by defining a simple schema and verifying the produced DDL contains the expected dataset/table creation statements.

**Acceptance Scenarios**:

1. **Given** a composed project + dataset + table schema, **When** DDL generation is requested, **Then** a deterministic set of DDL statements is produced.
2. **Given** a schema update (e.g., adding a column), **When** DDL generation is requested, **Then** the output includes the expected DDL reflecting the change.

---

### Edge Cases

- What happens when the project identifier is missing or empty?
- What happens when dataset/table names are invalid for the target platform?
- How does the system handle duplicate table names within the same dataset?
- How does the system handle duplicate column names within the same table?
- How does the system handle unsupported or ambiguous column types?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow defining a “project scope” that can contain one or more datasets.
- **FR-002**: System MUST allow defining a dataset schema that can contain one or more table schemas.
- **FR-003**: System MUST allow composing (reusing) table schema definitions across multiple datasets without duplicating the table schema source.
- **FR-004**: System MUST provide an explicit validation step that returns actionable, user-facing errors for invalid schemas.
- **FR-005**: System MUST provide a deterministic “compiled schema representation” (stable ordering and stable output for identical inputs).
- **FR-006**: System MUST provide a way to generate DDL statements for the composed schema.
- **FR-007**: System MUST include a documented API surface that feels familiar to developers coming from popular “schema-first” database toolchains.
- **FR-008**: System MUST document at least 2 alternative API shapes for composing project/dataset/table schemas, including tradeoffs and a recommended default.

- **FR-009**: The feature MUST clarify whether the deliverable includes updating the existing BigQuery adapter implementation or only designing the new schema API.
  - [NEEDS CLARIFICATION: Do we implement a working adapter integration now, or only design/prototype the schema API?]

- **FR-010**: The DDL generation capability MUST clarify whether the output is:
  - only DDL strings, or
  - a structured intermediate representation plus DDL rendering.
  - [NEEDS CLARIFICATION: What is the expected DDL output form(s)?]

- **FR-011**: The “modern schema-first toolchain” alignment MUST clarify which scope of parity is intended.
  - [NEEDS CLARIFICATION: Is the goal limited to schema definition + DDL, or does it include query-building concepts too?]

### Acceptance Mapping

- **Story 1** validates **FR-001**, **FR-002**, **FR-003**, **FR-005**
- **Story 2** validates **FR-004**
- **Story 3** validates **FR-006**, and helps validate **FR-005**
- Documentation review validates **FR-007** and **FR-008**

### Key Entities *(include if feature involves data)*

- **Project Schema**: Identifies a BigQuery project and groups datasets.
- **Dataset Schema**: Identifies a dataset and groups tables.
- **Table Schema**: Defines a table name, columns, and constraints.
- **Column Definition**: Defines column name, type, nullability, and optional metadata.
- **Validation Result**: Captures success/failure and human-readable error details.
- **DDL Plan**: A deterministic set of DDL statements derived from a composed schema.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can define one project, one dataset, and two tables using the API in a single, readable module/file without duplicating table definitions.
- **SC-002**: Validation catches at least the following before any DDL is produced: invalid names, duplicate table names, duplicate column names.
- **SC-003**: Given the same inputs, schema compilation and DDL generation produce byte-for-byte identical output across repeated runs.
- **SC-004**: The spec includes at least 2 alternative API designs plus one recommended default, and a reviewer can understand tradeoffs without reading implementation code.

## Assumptions

- This feature is focused on schema definition and schema-to-DDL output for BigQuery.
- This feature is primarily for library users (developers), not end-users.
- The project should remain composable and reusable across environments (e.g., dev/staging/prod).

## Out of Scope

- Executing DDL against BigQuery automatically (running migrations) unless required by later planning.
- Full query-builder parity with any specific external library beyond what is needed to define schemas and produce DDL.