## 1. P0 — Test foundation

- [ ] 1.1 Add `stream_data` as a `:test` dependency in `mix.exs`; `mix deps.get`
- [ ] 1.2 Create `test/raggio/schema/` tree; unit-test every primitive constructor (`string/integer/float/boolean/date/datetime/decimal/atom`): accept valid, reject wrong type, default applied on nil
- [ ] 1.3 Unit-test every composite (`struct/list/tuple/union/literal/record`): nesting, ordering, `unique`, tuple size mismatch, union variant selection, record key/value validation
- [ ] 1.4 Unit-test constraints (`min/max/pattern/unique`) across string/number/list, and `optional`/`nullable`/`default`
- [ ] 1.5 Unit-test validation modes: `:fail_fast` vs `:all_errors` error counts, and `partial: true` `{successes, failures}` shape; assert error `:path` correctness for nested failures
- [ ] 1.6 Add property-based tests (`StreamData`): derive a valid-value generator per schema → assert `validate` accepts; targeted invalid generators → assert reject with expected `:constraint`
- [ ] 1.7 Record current coverage baseline; wire into CI alongside Credo

## 2. P0 — JSON Schema generation

- [ ] 2.1 Create `lib/raggio/schema/adapters/json_schema.ex` with `to_json_schema/1` walking `%Type{}` (mirror `adapters/bigquery.ex`)
- [ ] 2.2 Map primitives + `date`/`datetime`/`decimal` (→ `string` + `format`/convention) and constraints → `minLength`/`maxLength`/`pattern`/`minimum`/`maximum`/`minItems`/`maxItems`/`uniqueItems`
- [ ] 2.3 Map composites: `struct` → object/properties/required (exclude optional & defaulted), `list` → array/items, `tuple` → prefixItems, `record` → additionalProperties, `union` → anyOf, `literal` → enum/const, `nullable` → `type: [..., "null"]`, `default` → `default`
- [ ] 2.4 Target draft 2020-12; emit `$schema`; read annotations (`title`/`description`/`examples`) once 5.5 lands
- [ ] 2.5 Golden-file tests of generated documents; validate sample data against the generated schema with an external JSON Schema validator (or structural assertions); add an `examples/schema/adapters/json_schema_export.exs`

## 3. P1 — Custom refinements + expanded checks

- [ ] 3.1 Add a `refine` node kind to `Type` and `Schema.refine/3` (predicate + message); evaluate after base validation in `validator.ex`, compatible with both modes
- [ ] 3.2 Add checks: exclusive bounds (`greater_than`/`less_than`), `multiple_of`, `int`, `non_empty`, `starts_with`/`ends_with`/`includes`, case checks, grapheme `length`
- [ ] 3.3 Promote `email`/`url`/`uuid` to named checks (good messages + JSON Schema `format`); keep regex helpers as the underlying patterns
- [ ] 3.4 Tests (unit + property) for every new check and for custom refinements

## 4. P2 — Bidirectional transforms / codec

- [ ] 4.1 Decide & document codec scope (per design D1); add a `transform` node carrying `decode`/`encode`
- [ ] 4.2 Make `validate/2` run the decode direction through transforms; add an `encode/2` entrypoint
- [ ] 4.3 Built-in transforms: `number_from_string`, `trim`, case transforms; transform composition
- [ ] 4.4 Reconcile the 001 spec's coercion/transform claims with the implementation (update the archived note or the schema spec)
- [ ] 4.5 Tests: decode coercion, decode-failure errors, and `encode |> decode == id` round-trip properties

## 5. P3 — Composition, recursion, strictness, annotations

- [ ] 5.1 Struct utilities: `pick`/`omit`/`partial`/`assign`/`rename_keys` (schema-level derivations)
- [ ] 5.2 Recursive schemas: `Schema.suspend/1`; validation depth tests; JSON Schema `$defs`/`$ref` for recursive types
- [ ] 5.3 Tagged/discriminated union with discriminant fast-path; `literal` list form (lift the 3-arg cap)
- [ ] 5.4 Strict struct mode (`Schema.strict/1` or `:strict` option); default stays lenient
- [ ] 5.5 `Schema.annotate/2` (`identifier`/`title`/`description`/`examples`) over the existing `metadata`; readable by JSON Schema + error formatting
- [ ] 5.6 Tests for all of the above

## 6. Wrap-up

- [ ] 6.1 Update the parity matrix in `design.md` to reflect shipped items; keep it as the living conformance reference
- [ ] 6.2 README: document JSON Schema export, refinements, and transforms
- [ ] 6.3 Confirm deferred items (brand, Symbol/BigInt, class-based, template literals, ToEquivalence) remain explicitly out of scope with rationale
