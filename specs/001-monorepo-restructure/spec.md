# Feature Specification: Multi-Package Monorepo Restructure

**Feature Branch**: `001-monorepo-restructure`  
**Created**: 2026-01-12  
**Status**: Draft  
**Input**: User description: "Lets create a repository in the same style as ecto and phoenix where we have several packages. Let's try to keep documentation in code at a minimum, we should prefer having working and compilable examples! We should base it from our /old_code folder. Our main two packages for now should be DataSchema and Syntax, but I want to rename them both to be Raggio.Schema and Raggio.Syntax respectively. We should investigate how does Effect-TS/Schema is doing their API under the hood both for Schema and their Syntax for inspiration. We should try to keep macros to a minimum and composability to a maximum"

## Clarifications

### Session 2026-01-12

- Q: Should schema import/export adapters be included in this restructure? → A: Include schema import/export as separate user stories with clear adapters for BigQuery export and SheetSchema import
- Q: What terminology should be used instead of "AST" (Abstract Syntax Tree)? → A: Use "Syntax" alone (not "AST" or "Syntax Tree") throughout spec, code, and examples
- Q: Should the implementation constraint API be fixed to match the spec? → A: Yes - fix implementation to match spec (superseded by Session 2026-01-13 clarification on argument composition syntax)
- Q: What data formats should BigQuery exporter and SheetSchema importer use? → A: BigQuery: Standard SQL DDL output; SheetSchema: Google Sheets with columns [field_name, type, required, constraints]
- Q: How should example file be organized in the repository structure? → A: Two-level hierarchy: examples/[package]/[use_case] (e.g., examples/raggio_schema/basic_validation, examples/raggio_syntax/syntax_building)
- Q: How should the system handle incompatible schema type composition? → A: Return descriptive error with type mismatch detail at composition time (when combining schema)
- Q: How should circular dependencies between packages be handled? → A: Prevent circular dependency through architecture (package should be layered, no circular reference allowed)
- Q: What test strategy should be used to verify example remain accurate? → A: Automated test suite that executes all example and verifies output
- Q: What is the minimal inline documentation standard? → A: Module-level purpose only, no function docs (example serve as documentation)
- Q: Should schema validation follow "parse, don't validate" principle? → A: Yes - validation should parse input into well-typed domain data, not just check and pass through
- Q: Which constraint syntax style should Raggio.Schema adopt for its API? → A: (Superseded by Session 2026-01-13) Argument composition with keyword options
- Q: How should schema validation handle partial success/failure in composite types (structs, arrays)? → A: Mode-based behavior - Default mode returns binary {:ok, data} | {:error, errors_with_paths} (Zod/Effect-TS style, fail-fast or collect all errors). Opt-in {:partial, true} mode returns {:ok, {successes, failures}} for composites allowing partial results
- Q: What structure should error objects use for representing validation failures? → A: Structured map with %{path: [...], message: "...", value: actual_value} - includes the path to failed field, error message, and the invalid value for debugging context
- Q: What is the minimum Elixir version requirement for the packages? → A: Elixir 1.14+ - provides modern features while maintaining good compatibility with current ecosystem
- Q: What dependency relationships are allowed between Raggio.Schema and Raggio.Syntax packages? → A: One-way dependency allowed - Raggio.Syntax can depend on Raggio.Schema (layered architecture), but Raggio.Schema must not depend on Raggio.Syntax, ensuring no circular dependencies
- Q: How should old_code feature parity be verified before deletion? → A: Create explicit feature parity checklist comparing old_code capabilities to new spec, mark each as "migrate", "defer", or "drop" with rationale
- Q: Should Excel/CSV/tabular parsing capabilities from old_code be included in the restructure? → A: Migrate full Excel/CSV/tabular parsing capabilities (SheetSchema DSL, Tabular adapter, header detection, row ranges, Excel transforms) in a separate package
- Q: Should the coercion system from old_code be included in Raggio.Schema? → A: Migrate coercion system to Raggio.Schema as core functionality with coerce() builders
- Q: Should bidirectional transforms from old_code be included in Raggio.Schema? → A: Migrate full bidirectional transform system with decode (parse-time) and encode (serialization-time) operations in Raggio.Schema
- Q: Should the Record type from old_code be included in Raggio.Schema? → A: Migrate Record type to Raggio.Schema for typed maps with dynamic keys

### Session 2026-01-13

- Q: Which constraint syntax style should Raggio.Schema actually use? → A: Argument composition - constraints as keyword options to type constructors (e.g., Schema.string(min: 3, max: 5), Schema.list(Schema.string(), min: 1))
- Q: What should be the core constraint set for Raggio.Schema? → A: 4 core constraints only: min (numbers/strings/lists), max (numbers/strings/lists), pattern (strings), unique (lists). All other validations (email, url, uuid, positive, negative, range, min_items, max_items, min_length, max_length) are removed - they can be expressed via these 4 or as helper functions returning pattern()
- Q: How should optional/nullable/default be expressed? → A: Mixed approach - optional() and nullable() are wrapper functions (field descriptors, not constraints), while default: value is a keyword option on type constructors. Example: Schema.optional(Schema.string(min: 1)), Schema.nullable(Schema.string()), Schema.integer(default: 0)
- Q: What syntax should struct definitions use? → A: Keyword list of tuples - Schema.struct([{:name, Schema.string()}, {:age, Schema.integer(min: 0)}]). Preserves field order, supports dynamic construction, avoids reserved keyword conflicts
- Q: How should enum/literal values be expressed? → A: Schema.literal(:pending, :approved, :rejected) - variadic arguments for allowed literal values. Replaces Schema.enum(). Works with any literal types (atoms, strings, integers)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer imports and uses Raggio.Schema package (Priority: P1)

A developer working on a data validation project needs to define schemas for their data structures. They import the Raggio.Schema package and use its composable API to build type-safe schemas without learning complex macro syntax.

**Why this priority**: This is the core value proposition - developers must be able to use the schema definition functionality. Without this, there is no product.

**Independent Test**: Can be fully tested by installing the Raggio.Schema package, importing it into a new project, defining a simple schema (e.g., a user record with name and age), and successfully validating data against it. This delivers immediate value for data validation use cases.

**Acceptance Scenarios**:

1. **Given** a new Elixir project, **When** developer adds Raggio.Schema as a dependency and runs mix deps.get, **Then** the package installs successfully without errors
2. **Given** Raggio.Schema is installed, **When** developer imports Raggio.Schema and defines a basic schema using composition functions, **Then** the schema compiles without requiring macro knowledge
3. **Given** a defined schema, **When** developer validates valid data against it, **Then** validation succeeds and returns the expected result
4. **Given** a defined schema, **When** developer validates invalid data against it, **Then** validation fails with clear error messages

---

### User Story 2 - Developer uses Raggio.Syntax for syntax manipulation (Priority: P2)

A developer building code generation or transformation tools needs to work with syntax structures. They use Raggio.Syntax to construct, traverse, and transform syntax trees using composable functions rather than pattern matching on complex macro-generated structures.

**Why this priority**: This enables advanced use cases like metaprogramming and code generation, building on the foundation of P1. It's essential for the complete product vision but can be used independently of schema validation.

**Independent Test**: Can be fully tested by installing Raggio.Syntax, creating syntax nodes programmatically, traversing them with provided combinators, and transforming them. Delivers value for developers building DSLs or code generators.

**Acceptance Scenarios**:

1. **Given** Raggio.Syntax is installed, **When** developer creates syntax nodes using the builder API, **Then** nodes are created with proper structure and can be composed together
2. **Given** a syntax structure, **When** developer applies a transformation function, **Then** the syntax is transformed correctly and maintains structural integrity
3. **Given** a syntax structure, **When** developer traverses it using provided combinators, **Then** they can access and process all nodes in a predictable order

---

### User Story 3 - Developer learns through working examples (Priority: P1)

A new developer encountering the Raggio packages for the first time needs to understand how to use them. Instead of reading extensive inline documentation, they access a collection of working, compilable examples that demonstrate common patterns and use cases.

**Why this priority**: This is critical for adoption - developers must be able to learn the library quickly. This is P1 because without good examples, even perfect code will not be adopted. This can be tested independently of any specific feature implementation.

**Independent Test**: Can be fully tested by navigating to the examples directory, running any example with mix run, and observing that it compiles and executes successfully, demonstrating the intended functionality. Each example should be self-contained and teach one concept.

**Acceptance Scenarios**:

1. **Given** the repository is cloned, **When** developer navigates to the example directory, **Then** they find multiple working example organized by package and use case in a two-level hierarchy (examples/raggio_schema/basic_validation, examples/raggio_syntax/syntax_building)
2. **Given** an example file, **When** developer runs it with the appropriate command, **Then** it compiles and executes successfully, showing expected output that is verified by an automated test suite
3. **Given** an example file, **When** developer reads the code, **Then** the code is clear and demonstrates one specific pattern or use case without extensive comment (module-level purpose only)

---

### User Story 4 - Developer extends functionality through composition (Priority: P2)

A developer with specific domain requirements needs to extend the base functionality of Raggio.Schema or Raggio.Syntax. Using the composable API design, they create custom validators, transformers, or combinators by composing existing primitives without touching the library's source code.

**Why this priority**: This validates the composability goal and enables long-term extensibility. It's P2 because it builds on the core functionality but is essential for the library's design philosophy.

**Independent Test**: Can be fully tested by using the public API to create a custom composite function (e.g., a custom validator that combines existing validators, or a custom AST transformer), using it in a real scenario, and verifying it works correctly. This demonstrates the composability principle.

**Acceptance Scenarios**:

1. **Given** base primitive functions are available, **When** developer composes them into a custom function, **Then** the custom function works correctly without requiring library modifications
2. **Given** a custom composed function, **When** developer uses it alongside built-in functions, **Then** it integrates seamlessly with the rest of the API
3. **Given** common extension patterns, **When** developer follows the compositional approach shown in examples, **Then** they can solve their domain-specific needs without macro magic (applies to both schema validators and syntax transformers)

---

### User Story 5 - Developer exports schema to BigQuery (Priority: P2)

A developer building a data pipeline needs to generate BigQuery table definitions from their Raggio.Schema definitions. They use the BigQuery exporter adapter to automatically convert schema definitions into BigQuery DDL, ensuring consistency between validation rules and database schema.

**Why this priority**: This enables integration with external systems and demonstrates the practical utility of schema definitions beyond validation. It's P2 because it builds on the core schema functionality and provides concrete value for data engineering use cases.

**Independent Test**: Can be fully tested by defining a Raggio.Schema, passing it to the BigQuery exporter, and verifying the generated DDL is valid and accurately represents the schema structure and constraints.

**Acceptance Scenarios**:

1. **Given** a Raggio.Schema definition, **When** developer calls the BigQuery exporter adapter, **Then** valid BigQuery standard SQL DDL is generated representing the schema structure
2. **Given** schema constraints (min/max, required fields), **When** exporting to BigQuery, **Then** appropriate BigQuery column constraints (e.g., NOT NULL) are included in the SQL DDL
3. **Given** nested schema structures, **When** exporting to BigQuery, **Then** they are converted to appropriate BigQuery STRUCT or RECORD types in the DDL output

---

### User Story 6 - Developer imports schema from SheetSchema (Priority: P2)

A developer working with non-technical stakeholders who define data structures in spreadsheets needs to convert SheetSchema definitions into Raggio.Schema. They use the SheetSchema importer adapter to automatically generate schema code from spreadsheet definitions, bridging the gap between business requirements and code.

**Why this priority**: This enables collaboration with non-technical stakeholders and reduces manual translation errors. It's P2 because it builds on the core functionality and provides value for teams with spreadsheet-based workflows.

**Independent Test**: Can be fully tested by providing a valid SheetSchema definition (spreadsheet format), running it through the importer, and verifying the generated Raggio.Schema code compiles and validates data correctly according to the spreadsheet specification.

**Acceptance Scenarios**:

1. **Given** a valid SheetSchema spreadsheet with columns [field_name, type, required, constraints], **When** developer runs the importer, **Then** valid Raggio.Schema code is generated
2. **Given** type specifications in the "type" column of SheetSchema, **When** importing, **Then** they are converted to appropriate Raggio.Schema type functions (e.g., "string" → Schema.string())
3. **Given** validation rules in the "constraints" column of SheetSchema, **When** importing, **Then** they are parsed and converted to equivalent Raggio.Schema constraint functions (e.g., "min:3,max:5" → Schema.min(3), Schema.max(5))

---

### User Story 7 - Developer parses Excel/CSV data with SheetSchema (Priority: P2)

A developer working with real-world Excel or CSV files from business users needs to parse, validate, and extract structured data. They use Raggio.Tabular with the SheetSchema DSL to declaratively define column mappings, handle header variations, filter row ranges, and apply Excel-specific transforms (currency, IDs). The system tracks row numbers and separates valid from invalid rows for error reporting.

**Why this priority**: This addresses a common real-world use case (parsing messy Excel/CSV data from business users) that is distinct from general schema validation. It's P2 because it builds on Raggio.Schema but provides specialized functionality for tabular data workflows.

**Independent Test**: Can be fully tested by providing an Excel/CSV file with messy data, defining a SheetSchema with column mappings and transforms, running the parser, and verifying that valid rows are extracted correctly while invalid rows are reported with row numbers and detailed errors.

**Acceptance Scenarios**:

1. **Given** an Excel/CSV file with known column structure, **When** developer defines a SheetSchema with column definitions and runs the parser, **Then** valid rows are extracted into structured data and invalid rows are separated with row-level error details
2. **Given** Excel files with header variations (different column orders or naming), **When** SheetSchema uses header detection with multiple variants, **Then** the parser correctly identifies columns regardless of header variation
3. **Given** messy Excel data with currency symbols and float IDs, **When** developer applies Excel-specific transforms (excel_decimal, excel_integer, excel_string), **Then** data is cleaned and validated correctly (e.g., "$1,234.56" → 1234.56, 123.0 → "123")
4. **Given** a large Excel file where only certain rows are relevant, **When** developer specifies row range filters in SheetSchema, **Then** only the specified rows are processed
5. **Given** union schemas for multiple format variants, **When** parsing data that matches one of the variants, **Then** the correct schema is applied and data is validated accordingly

---

### Edge Cases

- When a developer tries to compose incompatible schema type, the system returns a descriptive error with type mismatch detail at composition time (before validation is attempted)
- Circular dependency between package are prevented through layered architecture - Raggio.Syntax may depend on Raggio.Schema, but not vice versa
- What happens when a developer tries to import both old DataSchema and new Raggio.Schema in the same project?
- How are version conflicts handled when different packages have different dependency requirements?
- What happens when examples reference features that are not yet implemented or have changed?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Repository MUST be structured as a monorepo containing multiple independent packages in the style of Ecto and Phoenix
- **FR-002**: Repository MUST contain a package named Raggio.Schema (migrated from old_code/data_schema)
- **FR-003**: Repository MUST contain a package named Raggio.Syntax (migrated from syntax manipulation components in old_code/data_schema/ast)
- **FR-003a**: Repository MUST contain a package named Raggio.Tabular for Excel/CSV/tabular data parsing (migrated from old_code/data_schema SheetSchema, ExcelSchema, Tabular adapter, and Excel transform modules)
- **FR-004**: Each package MUST be independently compilable and publishable with no circular dependency - packages follow layered architecture where Raggio.Syntax may depend on Raggio.Schema, Raggio.Tabular may depend on Raggio.Schema, but Raggio.Schema must not depend on other Raggio packages
- **FR-005**: Each package MUST have minimal inline code documentation limited to module-level purpose only (no function doc), preferring working example over comment
- **FR-006**: Repository MUST include a collection of working, compilable example organized in a two-level hierarchy (examples/[package]/[use_case])
- **FR-007**: Package APIs MUST favor function composition over macro-based DSLs
- **FR-008**: Package APIs MUST prioritize composability, allowing developer to combine small function into larger behavior with composition-time error for incompatible type
- **FR-014**: Raggio.Schema API MUST use argument composition syntax where constraints are keyword options to type constructors (e.g., Schema.string(min: 3, max: 5), Schema.list(Schema.string(), min: 1)). Type constructors accept the element/field schema as first argument and optional constraint keywords. This provides a concise, declarative API without requiring pipe chains
- **FR-015**: Raggio.Schema validation MUST return binary results by default: {:ok, parsed_data} on success or {:error, errors} on failure, where each error is a structured map with :path (list showing location like [:user, :addresses, 2, :zipcode]), :message (human-readable description), and :value (the actual invalid value that failed validation)
- **FR-016**: Raggio.Schema MUST support two error collection modes: fail-fast (default, stops at first error returning single error) and all-errors (collects all validation errors, returning list of error maps)
- **FR-017**: Raggio.Schema MUST provide opt-in partial validation mode (via {:partial, true} option) that returns {:ok, {successes, failures}} for composite types, allowing recovery of valid fields even when some fields fail validation
- **FR-009**: Example MUST compile and run successfully as part of an automated test suite that verifies output
- **FR-010**: Raggio.Schema MUST provide functionality for defining and validating data schemas following the "parse, don't validate" principle - validation should parse input into well-typed domain data structures, not merely check validity and pass through
- **FR-011**: Raggio.Syntax MUST provide functionality for building and manipulating syntax structures (nodes, trees, and transformations)
- **FR-012**: Package design SHOULD be influenced by Effect-TS/Schema patterns for API ergonomics and composability
- **FR-013**: Packages are a clean break from old_code - no backward compatibility layer or migration support will be provided
- **FR-018**: Raggio.Schema MUST provide a BigQuery exporter adapter that converts schema definitions to valid BigQuery standard SQL DDL, including appropriate column types, constraints, and nested STRUCT/RECORD types for composite schemas
- **FR-019**: Raggio.Schema MUST provide a SheetSchema importer adapter that parses Google Sheets with columns [field_name, type, required, constraints] and converts them into valid Raggio.Schema code, including type mappings and constraint conversions
- **FR-020**: Implementation MUST include an explicit feature parity checklist comparing old_code/data_schema capabilities against new package specifications, with each feature marked as "migrate" (included in new implementation), "defer" (postponed to future iteration), or "drop" (intentionally excluded) with documented rationale for verification before old_code deletion
- **FR-021**: Raggio.Tabular MUST provide SheetSchema DSL for declarative tabular data parsing with column definitions, header detection supporting multiple variants, row range filtering, and union schemas for format variance
- **FR-022**: Raggio.Tabular MUST provide Tabular adapter for batch row parsing with row number tracking, separating valid and invalid rows with detailed error reporting per row
- **FR-023**: Raggio.Tabular MUST provide Excel-specific transform functions for common data cleaning patterns (currency formatting, float-to-integer IDs, decimal absolutes/negatives, whitespace trimming)
- **FR-024**: Raggio.Schema MUST provide explicit coercion builders that convert types before validation (e.g., Schema.coerce(Schema.to_decimal(), Schema.decimal(Schema.min(0)))), supporting conversions: any → string, any → integer, any → float, any → decimal, handling common formats like currency strings and float-represented integers
- **FR-025**: Raggio.Schema MUST support bidirectional transforms with decode operations (applied during parsing/validation) and encode operations (applied during serialization), allowing round-trip data transformation for use cases like API clients, database adapters, and data pipelines
- **FR-026**: Raggio.Schema MUST provide transform composition capabilities (e.g., abs(), negate() for numeric types) that work with the bidirectional transform system
- **FR-027**: Raggio.Schema MUST support Record type for typed maps with dynamic keys (e.g., %{user_id => user_schema}), validating both key and value types while allowing arbitrary key values at runtime, distinct from struct types with fixed keys
- **FR-028**: Raggio.Schema MUST use exactly 4 core constraints: min (polymorphic - validates minimum value for numbers, minimum length for strings/lists), max (polymorphic - validates maximum value for numbers, maximum length for strings/lists), pattern (validates string matches regex), unique (validates list has no duplicates). Convenience helpers like email(), url(), uuid() MAY be provided as functions that return pattern() with predefined regex
- **FR-029**: Raggio.Schema MUST distinguish between constraints (validate values) and field descriptors (describe field presence): optional() and nullable() are wrapper functions for field descriptors, while default: value is a keyword option on type constructors. Example usage: Schema.optional(Schema.string(min: 1)), Schema.nullable(Schema.string()), Schema.integer(default: 0)
- **FR-030**: Raggio.Schema MUST provide Schema.literal() with variadic arguments for defining allowed literal values: Schema.literal(:pending, :approved, :rejected). Replaces Schema.enum(). Works with any literal types (atoms, strings, integers)

### Key Entities

- **Raggio.Schema Package**: A composable library for defining data schemas, providing validation, bidirectional transformation, and coercion capabilities. Uses argument composition syntax where constraints are keyword options to type constructors (e.g., Schema.string(min: 3, max: 5), Schema.list(Schema.string(), min: 1)). Supports primitive types (string, integer, float, boolean, decimal, datetime, date), composite types (list, tuple, struct with fixed keys, record with dynamic keys), and literal types via Schema.literal(). Core constraints are minimal: min, max (polymorphic for numbers/strings/lists), pattern (regex for strings), unique (for lists). Field descriptors optional() and nullable() are wrapper functions; default: is a keyword option. Struct definitions use keyword list of tuples: Schema.struct([{:name, Schema.string()}, ...]). Validation returns binary results by default ({:ok, data} | {:error, errors_with_paths}), with support for fail-fast or all-errors modes, and optional partial validation mode for composites. Supports bidirectional transforms with decode (parse-time) and encode (serialization-time) operations for round-trip data handling. Includes explicit coercion builders for type conversion before validation and transform composition. Includes adapters for exporting schemas to BigQuery DDL and importing from SheetSchema spreadsheet definitions.
- **BigQuery Exporter**: An adapter that converts Raggio.Schema definitions to BigQuery standard SQL DDL, mapping schema types to BigQuery column types, constraints to column constraints, and nested structures to STRUCT/RECORD types.
- **SheetSchema Importer**: An adapter that parses Google Sheets with columns [field_name, type, required, constraints] and generates valid Raggio.Schema code, including type mappings and constraint conversions.
- **Raggio.Syntax Package**: A library for working with syntax structures through composable functions. Contains syntax node builders, traversal functions, and transformation utilities migrated from the syntax manipulation components.
- **Raggio.Tabular Package**: A library for parsing and validating Excel/CSV/tabular data with composable schema definitions. Contains SheetSchema DSL for declarative column mapping, Tabular adapter for batch row parsing with error tracking, header detection with multiple variant support, row range filtering, and Excel-specific transforms (currency, IDs, decimals). Depends on Raggio.Schema for type definitions and validation. Migrated from old_code SheetSchema, ExcelSchema, Tabular adapter, and Excel transform modules.
- **Example Projects**: Self-contained, executable code examples that demonstrate package usage patterns. Each example focuses on one specific use case and is independently runnable.
- **Monorepo Structure**: The organizational pattern that contains multiple packages, shared tooling, and cross-package development workflows similar to Elixir's Ecto and Phoenix projects.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can clone the repository and successfully compile all packages within 5 minutes on a machine with Elixir installed
- **SC-002**: A developer can run any example in the examples directory and see working output within 30 seconds
- **SC-003**: Each package can be added as a dependency to a new project and used independently without requiring the other packages
- **SC-004**: 90% of common use cases for schema definition and syntax manipulation can be accomplished through function composition without writing custom macros
- **SC-005**: The repository structure matches the organizational patterns of established Elixir monorepos (Ecto/Phoenix style) as verified by presence of package-specific mix.exs files and umbrella project structure
- **SC-006**: Developers can understand basic usage of either package by reading and running examples without consulting extensive API documentation

## Assumptions & Constraints

### Assumptions

- Elixir 1.14 or newer is available on target systems
- The Elixir programming language and Mix build tool will continue to be used
- The /old_code folder contains the current implementation that needs to be restructured
- The existing functionality in DataSchema and syntax manipulation is valuable and should be preserved in the new packages
- Effect-TS/Schema's approach to composability and API design is compatible with Elixir's functional programming paradigm
- Developers using this library are familiar with functional composition concepts
- The monorepo will be managed using standard Elixir umbrella project conventions

### Constraints

- Must support Elixir 1.14 or newer as minimum version
- Must minimize use of Elixir macros in the public API
- Must maintain compilable example as first-class documentation (module-level purpose only, no function doc)
- Must preserve existing functionality from old_code during migration
- Package names are fixed as Raggio.Schema and Raggio.Syntax

## Out of Scope

- Migration tooling or scripts to automatically convert old DataSchema code to Raggio.Schema
- Publishing packages to Hex.pm (this spec covers only the repository restructure)
- Performance optimization or benchmarking (focus is on structure and API design)
- Integration with other Raggio packages beyond Schema and Syntax
- Comprehensive API documentation website (examples serve as primary documentation)
- Support for languages other than Elixir
