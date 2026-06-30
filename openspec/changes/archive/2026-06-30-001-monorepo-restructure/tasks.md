# Tasks: Multi-Package Monorepo Restructure

All tasks are complete — this change has shipped.

## 1. Setup (Shared Infrastructure)

- [x] 1.1 Create `mix.exs` for the single package (`app: :raggio`, `elixir: "~> 1.14"`)
- [x] 1.2 Add `Decimal` dependency to `mix.exs`
- [x] 1.3 Add `Jason` dependency to `mix.exs` for BigQuery JSON export
- [x] 1.4 Create `lib/raggio.ex` root module (minimal — version, config only)
- [x] 1.5 Create `config/config.exs` with shared configuration
- [x] 1.6 Create `.formatter.exs` for code formatting
- [x] 1.7 Create `test/test_helper.exs` for ExUnit setup

## 2. Foundational (Blocking Prerequisites)

- [x] 2.1 Create `Type` struct in `lib/raggio/schema/type.ex` (fields: kind, constraints, inner, fields, elements, key_type, value_type, values, transform, metadata)
- [x] 2.2 Create `Error` struct in `lib/raggio/schema/error.ex` (fields: path, message, value, constraint)
- [x] 2.3 Define `validation_result` type in `lib/raggio/schema.ex` as `{:ok, any()} | {:error, [Error.t()]}`
- [x] 2.4 Create base `Raggio.Schema` module in `lib/raggio/schema.ex` with module-level doc only

## 3. User Story 1 — Core Schema Validation

### Primitive type constructors (`lib/raggio/schema.ex`)

- [x] 3.1 Implement `string/1` with opts (min, max, pattern, default)
- [x] 3.2 Implement `integer/1` with opts (min, max, default)
- [x] 3.3 Implement `float/1` with opts (min, max, default)
- [x] 3.4 Implement `boolean/1` with opts (default)
- [x] 3.5 Implement `date/1` with opts (default)
- [x] 3.6 Implement `datetime/1` with opts (default)
- [x] 3.7 Implement `decimal/1` with opts (min, max, default)
- [x] 3.8 Implement `atom/1` with opts (default)

### Composite type constructors (`lib/raggio/schema.ex`)

- [x] 3.9 Implement `struct/1` with keyword list of tuples `[{:field, schema}]`
- [x] 3.10 Implement `list/2` with inner schema and opts (min, max, unique, default)
- [x] 3.11 Implement `tuple/1` with list of schemas (positional)
- [x] 3.12 Implement `union/1` for union type (multiple alternatives)
- [x] 3.13 Implement `literal/1` variadic for literal type with allowed values
- [x] 3.14 Implement `record/2` for typed maps with dynamic keys (key_schema, value_schema)

### Field descriptors (`lib/raggio/schema.ex`)

- [x] 3.15 Implement `optional/1` wrapper to mark field optional
- [x] 3.16 Implement `nullable/1` wrapper to allow nil values

### Convenience helpers (`lib/raggio/schema.ex`)

- [x] 3.17 Implement `email/0` returning email regex pattern
- [x] 3.18 Implement `url/0` returning URL regex pattern
- [x] 3.19 Implement `uuid/0` returning UUID regex pattern

### Validation engine (`lib/raggio/schema/validator.ex`)

- [x] 3.20 Implement `validate/2` returning `{:ok, data} | {:error, errors}`
- [x] 3.21 Implement `validate/3` with options (mode: :fail_fast | :all_errors, partial: boolean)
- [x] 3.22 Implement `validate!/2` that raises on error
- [x] 3.23 Implement type validation for all primitive types
- [x] 3.24 Implement polymorphic `min` constraint validation (numbers, strings, lists)
- [x] 3.25 Implement polymorphic `max` constraint validation (numbers, strings, lists)
- [x] 3.26 Implement `pattern` constraint validation for strings
- [x] 3.27 Implement `unique` constraint validation for lists
- [x] 3.28 Implement nested struct validation with path accumulation
- [x] 3.29 Implement list validation with index-based error paths
- [x] 3.30 Implement union type validation (try each alternative)
- [x] 3.31 Implement literal type validation
- [x] 3.32 Implement record type validation (key + value schemas)
- [x] 3.33 Implement optional field handling in struct validation
- [x] 3.34 Implement nullable field handling in validation
- [x] 3.35 Implement default value application in validation

## 4. User Story 3 — Working Examples (Schema)

- [x] 4.1 Create `examples/schema/basic_validation/simple_schema.exs` (basic struct validation)
- [x] 4.2 Create `examples/schema/basic_validation/validation_errors.exs` (error structure)
- [x] 4.3 Create `examples/schema/basic_validation/nested_structs.exs` (nested validation)
- [x] 4.4 Create `examples/schema/basic_validation/lists_and_records.exs` (composite types)
- [x] 4.5 Create `examples/schema/basic_validation/literals_and_unions.exs` (literal() and union())
- [x] 4.6 Create `examples/schema/basic_validation/optional_nullable_default.exs` (field descriptors)
- [x] 4.7 Create `test/examples_test.exs` verifying all examples compile and run

## 5. User Story 2 — Syntax Manipulation

### Node struct (`lib/raggio/syntax/node.ex`)

- [x] 5.1 Create `Node` struct (fields: kind, name, children, metadata, source)

### Builder functions (`lib/raggio/syntax.ex`)

- [x] 5.2 Create `Raggio.Syntax` module with module-level doc
- [x] 5.3 Implement `schema/1` creating schema node from fields list
- [x] 5.4 Implement `field/2` and `field/3` creating field nodes
- [x] 5.5 Implement `type/1` and `type/2` creating type nodes

### Tree wrapper (`lib/raggio/syntax.ex`)

- [x] 5.6 Implement `ast/1` and `ast/2` wrapping node in tree with metadata

### Traversal functions (`lib/raggio/syntax/traversal.ex`)

- [x] 5.7 Implement `traverse/2` for depth-first traversal with visitor
- [x] 5.8 Implement `traverse/3` for traversal with accumulator
- [x] 5.9 Implement `find/2` to find first matching node
- [x] 5.10 Implement `find_all/2` to find all matching nodes

### Query functions (`lib/raggio/syntax.ex`)

- [x] 5.11 Implement `get_fields/1` to extract field nodes from schema
- [x] 5.12 Implement `get_field/2` to get specific field by name
- [x] 5.13 Implement `get_children/1` to get immediate children

### Syntax examples (`examples/syntax/`)

- [x] 5.14 Create `examples/syntax/node_building/basic_nodes.exs` (node creation)
- [x] 5.15 Create `examples/syntax/tree_traversal/depth_first.exs` (traversal)

## 6. User Story 4 — Extension Through Composition

### Transformation functions (`lib/raggio/syntax/transform.ex`)

- [x] 6.1 Implement `transform/2` to apply transformation to all nodes
- [x] 6.2 Implement `filter/2` to remove non-matching nodes
- [x] 6.3 Implement `replace/3` to replace specific node

### Extension examples

- [x] 6.4 Create `examples/schema/composition/custom_validator.exs` (custom validation)
- [x] 6.5 Create `examples/syntax/transformation/custom_transformer.exs` (transformer extension)

## 7. User Story 5 — BigQuery Export

### BigQuery exporter (`lib/raggio/schema/adapters/bigquery.ex`)

- [x] 7.1 Create `lib/raggio/schema/adapters/bigquery.ex` with module-level doc
- [x] 7.2 Implement `to_ddl/2` converting schema to BigQuery DDL string
- [x] 7.3 Implement `to_ddl/3` with options (partition_by, cluster_by, description)
- [x] 7.4 Implement type mapping: string→STRING, integer→INT64, float→FLOAT64, boolean→BOOL
- [x] 7.5 Implement type mapping: decimal→NUMERIC, datetime→DATETIME, date→DATE
- [x] 7.6 Implement nested struct to STRUCT<...> conversion
- [x] 7.7 Implement list to ARRAY<type> conversion

### BigQuery examples

- [x] 7.8 Create `examples/schema/adapters/bigquery_export.exs` (DDL generation)

## 8. User Story 6 — SheetSchema Import

### SheetSchema importer (`lib/raggio/schema/adapters/sheet_schema.ex`)

- [x] 8.1 Create `lib/raggio/schema/adapters/sheet_schema.ex` with module-level doc
- [x] 8.2 Implement `from_csv/1` parsing CSV and returning generated Schema code string
- [x] 8.3 Implement `from_csv/2` with options (module_name, format)
- [x] 8.4 Implement CSV column parsing: field_name, type, required, constraints
- [x] 8.5 Implement type parsing to generate constructors (string→Schema.string())
- [x] 8.6 Implement constraint parsing to generate keyword options (min:3→min: 3)
- [x] 8.7 Implement `validate_format/1` for format validation with row-level errors

### SheetSchema examples

- [x] 8.8 Create `examples/schema/adapters/sheet_import.exs` (CSV import)

## 9. Polish & Cross-Cutting Concerns

- [x] 9.1 Create feature parity checklist comparing old_code to new package (old_code moved to `old_code/umbrella_apps`)
- [x] 9.2 Run `mix format` to format all code
- [x] 9.3 Run `mix compile --warnings-as-errors` to verify clean compilation
- [x] 9.4 Run `mix test` to verify all tests pass (11 tests, 0 failures)
- [x] 9.5 Validate all examples in `examples/` compile and run via `test/examples_test.exs`
- [x] 9.6 Verify no macros in public API (only functions)
