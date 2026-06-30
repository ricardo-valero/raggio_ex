# Schema Adapters Specification

## Purpose

The schema adapters bridge `Raggio.Schema` definitions to external systems. The BigQuery exporter converts a schema into valid BigQuery Standard SQL DDL with type and constraint mapping, while the SheetSchema importer parses CSV files and Google Sheets URLs into valid Raggio.Schema code, including type, constraint, and nested-struct parsing plus format validation.

## Requirements

### Requirement: BigQuery DDL export

The BigQuery exporter adapter SHALL convert a `Raggio.Schema` definition into valid BigQuery Standard SQL DDL via `to_ddl/2` (schema and table name) and `to_ddl/3` (with opts `partition_by`, `cluster_by`, `description`). The table name MAY use `project.dataset.table` form.

#### Scenario: Generate a CREATE TABLE statement

- **WHEN** `BigQuery.to_ddl(schema, "users")` is called for a struct schema with `id` and `email` fields
- **THEN** a `CREATE TABLE` DDL string for `users` is returned listing those columns

#### Scenario: Generate DDL with partitioning and clustering options

- **WHEN** `BigQuery.to_ddl(schema, "users", partition_by: "DATE(created_at)", cluster_by: ["status", "id"])` is called
- **THEN** the returned DDL includes the corresponding PARTITION BY and CLUSTER BY clauses

### Requirement: BigQuery type and constraint mapping

The BigQuery exporter SHALL map Raggio types to BigQuery column types: `:string`→STRING, `:integer`→INT64, `:float`→FLOAT64, `:boolean`→BOOL, `:decimal`→NUMERIC, `:date`→DATE, `:datetime`→DATETIME, list→`ARRAY<...>`, and struct→`STRUCT<...>`. Required fields SHALL map to `NOT NULL` and `default:` to `DEFAULT value`; constraints not expressible in DDL (`min`, `max`, `pattern`) SHALL be emitted as comments rather than dropped silently.

#### Scenario: Map primitive types to BigQuery types

- **WHEN** exporting a schema with string, integer, float, and boolean fields
- **THEN** the DDL emits STRING, INT64, FLOAT64, and BOOL columns respectively

#### Scenario: Map a nested struct to a STRUCT column

- **WHEN** exporting a schema containing a nested struct field
- **THEN** the DDL emits a `STRUCT<...>` column reflecting the nested fields

#### Scenario: Map a list to an ARRAY column

- **WHEN** exporting a schema containing a list field
- **THEN** the DDL emits an `ARRAY<type>` column for the element type

#### Scenario: Required field becomes NOT NULL

- **WHEN** exporting a required field
- **THEN** the corresponding column carries `NOT NULL`

### Requirement: SheetSchema import from CSV

The SheetSchema importer adapter SHALL parse a CSV file via `from_csv/1` and `from_csv/2` (opts `module_name`, `format`) and return `{:ok, generated_code}` containing valid Raggio.Schema code, or `{:error, reason}` on failure. The CSV SHALL require `field_name` and `type` columns and MAY include `required`, `constraints`, `description`, `example`, `default`, and `parent_path` columns.

#### Scenario: Generate schema code from a CSV

- **WHEN** `SheetSchema.from_csv("schema.csv")` is called with a well-formed CSV
- **THEN** the call returns `{:ok, code}` where `code` is valid Raggio.Schema Elixir code

#### Scenario: Wrap generated code in a module

- **WHEN** `SheetSchema.from_csv("schema.csv", module_name: "MyApp.UserSchema")` is called
- **THEN** the generated code is wrapped in the named module definition

### Requirement: SheetSchema type and constraint parsing

The SheetSchema importer SHALL parse the `type` column into Raggio.Schema type constructors (e.g. `"string"`→`Schema.string()`, `list(type)`, `tuple(...)`, `union(...)`, `nullable(type)`) and parse the pipe-separated `constraints` column into the corresponding keyword options (e.g. `min:3`→`min: 3`). Fields with a `parent_path` SHALL be grouped into nested structs using dot notation.

#### Scenario: Convert a type string to a constructor

- **WHEN** importing a row whose `type` column is `string`
- **THEN** the generated code uses `Schema.string()` for that field

#### Scenario: Convert constraints to keyword options

- **WHEN** importing a row whose `constraints` column is `min:3|max:5`
- **THEN** the generated code includes `min: 3, max: 5` on the field's constructor

#### Scenario: Nest fields via parent_path

- **WHEN** importing rows whose `parent_path` is `address` (and `address.geo`)
- **THEN** the generated code groups those fields under a nested `address` struct (with a further nested `geo` struct)

### Requirement: SheetSchema import from URL and format validation

The SheetSchema importer SHALL provide `from_url/1` and `from_url/2` to import from a Google Sheets sharing URL (opts include `sheet_name`, `cache_ttl`, and all `from_csv/2` options), and a format-validation function that checks the SheetSchema format without generating code, returning `:ok` or `{:error, errors}` with row-level details.

#### Scenario: Import from a Google Sheets URL

- **WHEN** `SheetSchema.from_url("https://docs.google.com/spreadsheets/d/abc123/edit")` is called
- **THEN** the sheet is fetched and converted, returning `{:ok, code}` or `{:error, reason}`

#### Scenario: Validate format reports row-level errors

- **WHEN** the importer validates a malformed sheet (e.g. missing the required `field_name` column)
- **THEN** it returns `{:error, errors}` where each error identifies the offending row and a message, rather than generating code
