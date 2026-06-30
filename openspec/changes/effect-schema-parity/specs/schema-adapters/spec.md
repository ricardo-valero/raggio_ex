## ADDED Requirements

### Requirement: JSON Schema generation

`Raggio.Schema.Adapters` SHALL provide a JSON Schema generator (e.g.
`Raggio.Schema.Adapters.JsonSchema.to_json_schema/1`) that walks a `Raggio.Schema` `%Type{}`
AST and emits a JSON Schema (draft 2020-12) document. The mapping MUST cover primitives,
composites, constraints, optionality/nullability/defaults, and SHALL incorporate available
annotations (`title`, `description`, `examples`).

#### Scenario: Struct maps to object with properties and required

- **WHEN** generating JSON Schema for `Schema.struct([{:name, Schema.string()}, {:age, Schema.optional(Schema.integer())}])`
- **THEN** the output is `type: "object"` with `properties` for `name` and `age`, and `required` listing `name` only (the optional field is excluded)

#### Scenario: String constraints map to JSON Schema keywords

- **WHEN** generating JSON Schema for `Schema.string(min: 3, max: 20, pattern: ~r/^[a-z]+$/)`
- **THEN** the output has `type: "string"`, `minLength: 3`, `maxLength: 20`, and a `pattern` string

#### Scenario: List and number constraints map correctly

- **WHEN** generating JSON Schema for `Schema.list(Schema.integer(min: 0), min: 1, unique: true)`
- **THEN** the output is `type: "array"` with `items` of `type: "integer"` carrying `minimum: 0`, plus `minItems: 1` and `uniqueItems: true`

#### Scenario: Union and literal map to anyOf and enum/const

- **WHEN** generating JSON Schema for `Schema.union([Schema.string(), Schema.integer()])` and for `Schema.literal(:a, :b)`
- **THEN** the union emits `anyOf` of the member schemas and the literal emits `enum` (or `const` for a single value)

#### Scenario: Annotations flow into the document

- **WHEN** generating JSON Schema for a schema annotated with `title: "Email"` and `description: "User email"`
- **THEN** the emitted schema object includes `title: "Email"` and `description: "User email"`
