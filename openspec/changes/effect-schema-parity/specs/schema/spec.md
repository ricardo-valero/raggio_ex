## ADDED Requirements

### Requirement: Custom refinements

`Raggio.Schema` SHALL allow attaching a user-supplied predicate to any schema via a
refinement combinator (e.g. `Schema.refine/3`), so the constraint set is open rather than
closed. A refinement SHALL run after the base type/constraints pass, MUST produce a
structured error carrying a caller-supplied message and a `:refine` (or caller-named)
constraint tag on failure, and MUST compose with `:fail_fast` / `:all_errors` modes.

#### Scenario: Refinement narrows an already-typed value

- **WHEN** validating `4` against `Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even")`
- **THEN** validation succeeds

#### Scenario: Refinement failure yields a structured error

- **WHEN** validating `3` against `Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even")`
- **THEN** validation returns `{:error, errors}` where an error has `message: "must be even"` and a refinement constraint tag

### Requirement: Expanded built-in checks

`Raggio.Schema` SHALL provide first-class checks beyond `min`/`max`/`pattern`/`unique`,
covering the common Effect `Schema` checks: exclusive bounds (`greater_than`/`less_than`),
`multiple_of`, `int` (integral float), `non_empty`, string content checks
(`starts_with`/`ends_with`/`includes`), case checks, and grapheme `length`. Each check MUST
emit an error with a distinct constraint tag.

#### Scenario: Exclusive lower bound rejects the boundary value

- **WHEN** validating `0` against an integer schema with a `greater_than: 0` check
- **THEN** validation fails because `0` is not strictly greater than `0`

#### Scenario: multiple_of accepts a multiple

- **WHEN** validating `15` against an integer schema with a `multiple_of: 5` check
- **THEN** validation succeeds

#### Scenario: starts_with check

- **WHEN** validating `"hello"` against a string schema with a `starts_with: "he"` check
- **THEN** validation succeeds, and `"world"` fails the same check

### Requirement: Bidirectional transforms (decode/encode)

`Raggio.Schema` SHALL support transformation nodes that define a `decode` (encoded → typed)
and an `encode` (typed → encoded) function, enabling coercion and round-tripping. `validate/2`
SHALL apply the decode direction. A separate encode entrypoint SHALL apply the reverse.
Transformations MUST compose and MUST report decode failures as structured errors.

#### Scenario: Decode coerces a numeric string

- **WHEN** decoding `"42"` through a `number_from_string` transform wrapping `Schema.integer()`
- **THEN** the result is `{:ok, 42}`

#### Scenario: Encode reverses decode

- **WHEN** a value decoded through a transform is then encoded
- **THEN** the encoded output equals the original encoded input (round-trip identity)

#### Scenario: Decode failure is structured

- **WHEN** decoding `"abc"` through `number_from_string`
- **THEN** the result is `{:error, errors}` with a transform/decode constraint tag

### Requirement: Recursive schemas

`Raggio.Schema` SHALL allow self-referential schemas via a lazy combinator (e.g.
`Schema.suspend/1`) so recursive structures such as trees can be expressed and validated to
arbitrary depth without infinite construction.

#### Scenario: Validate a recursive tree

- **WHEN** a `tree` schema is defined with `children` as `Schema.list(Schema.suspend(fn -> tree end))` and validated against a nested node
- **THEN** validation recurses through every level and succeeds for a well-formed tree

### Requirement: Strict struct / excess-property handling

`Raggio.Schema` SHALL provide an opt-in strict mode for structs that rejects keys not declared
in the schema. The default behavior SHALL remain lenient (unknown keys ignored) to preserve
existing `validate/2` semantics.

#### Scenario: Strict mode rejects unknown keys

- **WHEN** validating `%{name: "A", extra: 1}` against a strict struct schema declaring only `:name`
- **THEN** validation fails with an error identifying the unexpected key `:extra`

#### Scenario: Default mode ignores unknown keys

- **WHEN** validating `%{name: "A", extra: 1}` against a non-strict struct schema declaring only `:name`
- **THEN** validation succeeds

### Requirement: Schema annotations

`Raggio.Schema` SHALL expose the existing `%Type{}` metadata channel via an annotation
combinator (e.g. `Schema.annotate/2`) supporting at least `identifier`, `title`, `description`,
and `examples`. Annotations MUST NOT affect validation outcomes and SHALL be readable by
derivations (e.g. JSON Schema generation) and error formatting.

#### Scenario: Annotations are preserved and inert

- **WHEN** a schema is annotated with `title: "Age"` and `description: "Years"` and then used to validate a value
- **THEN** the validation outcome is identical to the un-annotated schema, and the annotation values are retrievable from the schema
