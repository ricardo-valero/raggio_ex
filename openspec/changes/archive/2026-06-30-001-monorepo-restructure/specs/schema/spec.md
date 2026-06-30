# Schema Capability

## ADDED Requirements

### Requirement: Primitive type constructors

`Raggio.Schema` SHALL provide function-based constructors for primitive types — `string/0,1`, `integer/0,1`, `float/0,1`, `boolean/0,1`, `decimal/0,1`, `date/0,1`, `datetime/0,1`, and `atom/0,1` — each returning an immutable schema value. Constraints and a `default:` value MUST be passable as keyword options on the constructor (argument composition), with no macros required.

#### Scenario: Build a string schema with constraints

- **WHEN** a developer calls `Schema.string(min: 3, max: 20)`
- **THEN** a schema value of type `:string` is returned carrying the `min` and `max` constraints, with no macro expansion involved

#### Scenario: Build an integer schema with a default

- **WHEN** a developer calls `Schema.integer(min: 0, default: 0)`
- **THEN** a schema value of type `:integer` is returned carrying the `min` constraint and a default value of `0`

### Requirement: Composite type constructors

`Raggio.Schema` SHALL provide composite type constructors: `struct/1` (a keyword list of `{field_name, schema}` tuples preserving field order), `list/2` (an inner element schema plus opts `min`, `max`, `unique`, `default`), `tuple/1` (a positional list of schemas), `record/2` (a key schema and value schema for dynamically-keyed maps), `union/1` (a list of at least two alternative schemas), and `literal/1` (variadic allowed literal values).

#### Scenario: Define a struct preserving field order

- **WHEN** a developer calls `Schema.struct([{:name, Schema.string()}, {:age, Schema.integer(min: 0)}])`
- **THEN** a `:struct` schema is returned with fields in the declared order

#### Scenario: Define a list with element schema and constraints

- **WHEN** a developer calls `Schema.list(Schema.string(min: 1), max: 10, unique: true)`
- **THEN** a `:list` schema is returned whose element schema is the string schema and which carries the `max` and `unique` constraints

#### Scenario: Define a record with dynamic keys

- **WHEN** a developer calls `Schema.record(Schema.string(), Schema.integer(min: 0))`
- **THEN** a `:record` schema is returned that validates string keys and non-negative integer values while permitting arbitrary runtime keys

#### Scenario: Define literal allowed values variadically

- **WHEN** a developer calls `Schema.literal(:pending, :approved, :rejected)`
- **THEN** a `:literal` schema is returned whose allowed values are exactly those three atoms

### Requirement: Four core constraints

`Raggio.Schema` SHALL support exactly four core constraints: `min` and `max` (polymorphic — bounding numeric value, or string/list length), `pattern` (regex match for strings only), and `unique` (no duplicate elements, lists only). No other built-in constraints are provided.

#### Scenario: Polymorphic min on a string

- **WHEN** validating `"ab"` against `Schema.string(min: 3)`
- **THEN** validation fails because the string length is below the minimum of 3

#### Scenario: Polymorphic min on a number

- **WHEN** validating `-1` against `Schema.integer(min: 0)`
- **THEN** validation fails because the value is below the minimum of 0

#### Scenario: Unique constraint on a list

- **WHEN** validating `["a", "a"]` against `Schema.list(Schema.string(), unique: true)`
- **THEN** validation fails because the list contains duplicate elements

### Requirement: Convenience pattern helpers

`Raggio.Schema` SHALL provide `email/0`, `url/0`, and `uuid/0` helper functions that return predefined `Regex` values for use with the `pattern:` option. These are helpers, not constraints.

#### Scenario: Use the email helper as a pattern

- **WHEN** a developer calls `Schema.string(pattern: Schema.email())`
- **THEN** a string schema is returned whose `pattern` constraint is the predefined email regex

### Requirement: Field descriptors distinct from constraints

`Raggio.Schema` SHALL distinguish field descriptors from constraints. `optional/1` SHALL wrap a schema so the field may be missing from a struct, and `nullable/1` SHALL wrap a schema so its value may be `nil`. The `default:` keyword option SHALL supply a value used when the field is missing or `nil`.

#### Scenario: Optional field may be absent

- **WHEN** validating `%{name: "Alice"}` against `Schema.struct([{:name, Schema.string()}, {:bio, Schema.optional(Schema.string())}])`
- **THEN** validation succeeds even though `:bio` is absent

#### Scenario: Nullable field accepts nil

- **WHEN** validating a `nil` value against `Schema.nullable(Schema.string())`
- **THEN** validation succeeds because nil is permitted

#### Scenario: Default applied when value missing or nil

- **WHEN** validating data where a field declared `Schema.integer(default: 0)` is missing or nil
- **THEN** the parsed result uses `0` for that field

### Requirement: Parse, don't validate

`Raggio.Schema.validate/2` SHALL parse input into well-typed domain data rather than merely checking and passing the input through. On success it MUST return `{:ok, parsed_data}`; on failure it MUST return `{:error, errors}`.

#### Scenario: Successful validation returns parsed data

- **WHEN** valid data is validated against a schema
- **THEN** the call returns `{:ok, parsed_data}` containing the parsed/typed domain value

#### Scenario: Failed validation returns errors

- **WHEN** invalid data is validated against a schema
- **THEN** the call returns `{:error, errors}` with at least one structured error

### Requirement: Structured errors with paths

Each validation error SHALL be a map containing `:path` (a list of atoms/integers locating the failure, e.g. `[:user, :addresses, 2, :zipcode]`), `:message` (a human-readable description), `:value` (the actual invalid value), and `:constraint` (which constraint failed, e.g. `:min`, `:max`, `:pattern`, `:unique`, `:type`, `:required`).

#### Scenario: Error includes the path to a nested field

- **WHEN** a nested field fails validation inside a struct/list composite
- **THEN** the returned error's `:path` lists the keys and indices leading to the failing field, and `:value` holds the invalid value

### Requirement: Validation modes

`Raggio.Schema.validate/3` SHALL support a `mode:` option of `:fail_fast` (default, returning at the first error) or `:all_errors` (collecting all errors), and a `partial: true` option that returns `{:ok, {successes, failures}}` for composite types so valid fields are recoverable. `validate!/2` SHALL raise `Raggio.Schema.ValidationError` on failure.

#### Scenario: Fail-fast stops at the first error

- **WHEN** validating invalid data with the default mode
- **THEN** the call returns `{:error, errors}` after the first failure is found

#### Scenario: All-errors collects every failure

- **WHEN** validating invalid data with `mode: :all_errors`
- **THEN** the call returns `{:error, errors}` containing one error map per failed field

#### Scenario: Partial mode recovers valid fields

- **WHEN** validating a composite with `partial: true` where some fields are valid and some are not
- **THEN** the call returns `{:ok, {successes, failures}}` exposing both the valid fields and the per-field errors

#### Scenario: validate! raises on failure

- **WHEN** `Schema.validate!/2` is called with invalid data
- **THEN** a `Raggio.Schema.ValidationError` is raised

### Requirement: Coercion and bidirectional transforms

`Raggio.Schema` SHALL provide explicit coercion builders that convert input types before validation (any → string/integer/float/decimal, including currency strings and float-represented integers), and SHALL support bidirectional transforms with decode (parse-time) and encode (serialization-time) operations plus transform composition (e.g. `abs`, `negate`) for round-trip data handling.

#### Scenario: Coerce a currency string before validation

- **WHEN** a coercion builder for decimal is applied to an input like `"$1,234.56"` ahead of a `Schema.decimal(min: 0)` validation
- **THEN** the input is converted to the decimal `1234.56` and then validated against the constraint

#### Scenario: Round-trip via decode and encode

- **WHEN** a value is decoded through a bidirectional transform and then encoded
- **THEN** the encode operation reverses the decode, yielding the original wire representation
