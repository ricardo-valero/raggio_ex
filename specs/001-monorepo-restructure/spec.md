# Feature Specification: Multi-Package Monorepo Restructure

**Feature Branch**: `001-monorepo-restructure`  
**Created**: 2026-01-12  
**Status**: Draft  
**Input**: User description: "Lets create a repository in the same style as ecto and phoenix where we have several packages. Let's try to keep documentation in code at a minimum, we should prefer having working and compilable examples! We should base it from our /old_code folder. Our main two packages for now should be DataSchema and AST, but I want to rename them both to be Raggio.Schema and Raggio.Syntax respectively. We should investigate how does Effect-TS/Schema is doing their API under the hood both for Schema and their AST for inspiration. We should try to keep macros to a minimum and composability to a maximum"

## Clarifications

### Session 2026-01-12

- Q: How should example file be organized in the repository structure? → A: Two-level hierarchy: examples/[package]/[use_case] (e.g., examples/raggio_schema/basic_validation, examples/raggio_syntax/ast_building)
- Q: How should the system handle incompatible schema type composition? → A: Return descriptive error with type mismatch detail at composition time (when combining schema)
- Q: How should circular dependencies between packages be handled? → A: Prevent circular dependency through architecture (package should be layered, no circular reference allowed)
- Q: What test strategy should be used to verify example remain accurate? → A: Automated test suite that executes all example and verifies output
- Q: What is the minimal inline documentation standard? → A: Module-level purpose only, no function docs (example serve as documentation)
- Q: Should schema validation follow "parse, don't validate" principle? → A: Yes - validation should parse input into well-typed domain data, not just check and pass through

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

### User Story 2 - Developer uses Raggio.Syntax for AST manipulation (Priority: P2)

A developer building code generation or transformation tools needs to work with abstract syntax trees. They use Raggio.Syntax to construct, traverse, and transform ASTs using composable functions rather than pattern matching on complex macro-generated structures.

**Why this priority**: This enables advanced use cases like metaprogramming and code generation, building on the foundation of P1. It's essential for the complete product vision but can be used independently of schema validation.

**Independent Test**: Can be fully tested by installing Raggio.Syntax, creating AST nodes programmatically, traversing them with provided combinators, and transforming them. Delivers value for developers building DSLs or code generators.

**Acceptance Scenarios**:

1. **Given** Raggio.Syntax is installed, **When** developer creates AST nodes using the builder API, **Then** nodes are created with proper structure and can be composed together
2. **Given** an AST structure, **When** developer applies a transformation function, **Then** the AST is transformed correctly and maintains structural integrity
3. **Given** an AST structure, **When** developer traverses it using provided combinators, **Then** they can access and process all nodes in a predictable order

---

### User Story 3 - Developer learns through working examples (Priority: P1)

A new developer encountering the Raggio packages for the first time needs to understand how to use them. Instead of reading extensive inline documentation, they access a collection of working, compilable examples that demonstrate common patterns and use cases.

**Why this priority**: This is critical for adoption - developers must be able to learn the library quickly. This is P1 because without good examples, even perfect code will not be adopted. This can be tested independently of any specific feature implementation.

**Independent Test**: Can be fully tested by navigating to the examples directory, running any example with mix run, and observing that it compiles and executes successfully, demonstrating the intended functionality. Each example should be self-contained and teach one concept.

**Acceptance Scenarios**:

1. **Given** the repository is cloned, **When** developer navigates to the example directory, **Then** they find multiple working example organized by package and use case in a two-level hierarchy (examples/raggio_schema/basic_validation, examples/raggio_syntax/ast_building)
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
3. **Given** common extension patterns, **When** developer follows the compositional approach shown in examples, **Then** they can solve their domain-specific needs without macro magic

---

### Edge Cases

- When a developer tries to compose incompatible schema type, the system returns a descriptive error with type mismatch detail at composition time (before validation is attempted)
- Circular dependency between package are prevented through layered architecture (no circular reference allowed)
- What happens when a developer tries to import both old DataSchema and new Raggio.Schema in the same project?
- How are version conflicts handled when different packages have different dependency requirements?
- What happens when examples reference features that are not yet implemented or have changed?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Repository MUST be structured as a monorepo containing multiple independent packages in the style of Ecto and Phoenix
- **FR-002**: Repository MUST contain a package named Raggio.Schema (migrated from old_code/data_schema)
- **FR-003**: Repository MUST contain a package named Raggio.Syntax (migrated from AST components in old_code/data_schema/ast)
- **FR-004**: Each package MUST be independently compilable and publishable with no circular dependency (package should be layered)
- **FR-005**: Each package MUST have minimal inline code documentation limited to module-level purpose only (no function doc), preferring working example over comment
- **FR-006**: Repository MUST include a collection of working, compilable example organized in a two-level hierarchy (examples/[package]/[use_case])
- **FR-007**: Package APIs MUST favor function composition over macro-based DSLs
- **FR-008**: Package APIs MUST prioritize composability, allowing developer to combine small function into larger behavior with composition-time error for incompatible type
- **FR-009**: Example MUST compile and run successfully as part of an automated test suite that verifies output
- **FR-010**: Raggio.Schema MUST provide functionality for defining and validating data schemas following the "parse, don't validate" principle - validation should parse input into well-typed domain data structures, not merely check validity and pass through
- **FR-011**: Raggio.Syntax MUST provide functionality for building and manipulating abstract syntax trees
- **FR-012**: Package design SHOULD be influenced by Effect-TS/Schema patterns for API ergonomics and composability
- **FR-013**: Packages are a clean break from old_code - no backward compatibility layer or migration support will be provided

### Key Entities

- **Raggio.Schema Package**: A composable library for defining data schemas, providing validation, and transformation capabilities. Contains builders, validators, and composable schema primitives migrated and refactored from old DataSchema.
- **Raggio.Syntax Package**: A library for working with abstract syntax trees through composable functions. Contains AST node builders, traversal functions, and transformation utilities migrated from the AST components.
- **Example Projects**: Self-contained, executable code examples that demonstrate package usage patterns. Each example focuses on one specific use case and is independently runnable.
- **Monorepo Structure**: The organizational pattern that contains multiple packages, shared tooling, and cross-package development workflows similar to Elixir's Ecto and Phoenix projects.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can clone the repository and successfully compile all packages within 5 minutes on a machine with Elixir installed
- **SC-002**: A developer can run any example in the examples directory and see working output within 30 seconds
- **SC-003**: Each package can be added as a dependency to a new project and used independently without requiring the other packages
- **SC-004**: 90% of common use cases for schema definition and AST manipulation can be accomplished through function composition without writing custom macros
- **SC-005**: The repository structure matches the organizational patterns of established Elixir monorepos (Ecto/Phoenix style) as verified by presence of package-specific mix.exs files and umbrella project structure
- **SC-006**: Developers can understand basic usage of either package by reading and running examples without consulting extensive API documentation

## Assumptions & Constraints

### Assumptions

- The Elixir programming language and Mix build tool will continue to be used
- The /old_code folder contains the current implementation that needs to be restructured
- The existing functionality in DataSchema and AST is valuable and should be preserved in the new packages
- Effect-TS/Schema's approach to composability and API design is compatible with Elixir's functional programming paradigm
- Developers using this library are familiar with functional composition concepts
- The monorepo will be managed using standard Elixir umbrella project conventions

### Constraints

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
