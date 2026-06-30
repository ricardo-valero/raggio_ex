# Design: Effect Schema (effect-smol) Parity

## Context

`effect-smol` is the in-progress rewrite of Effect (the "smol" core). Its `Schema` module
(`packages/effect/SCHEMA.md`) is the reference we benchmark against. Effect `Schema` is
built on three ideas Raggio only partially shares:

1. **A schema is a codec, not a predicate.** `Schema<Type, Encoded>` carries both a runtime
   type and an encoded representation, with `decode` (Encoded → Type) and `encode`
   (Type → Encoded). Validation is just decoding from `unknown`.
2. **Everything is an AST + derivations.** A schema is an AST; `ToParser`, `ToJsonSchema`,
   `ToArbitrary`, `ToEquivalence` are *derivations* that walk that AST. Raggio already has an
   AST (`Raggio.Schema.Type`) and one derivation pattern (the BigQuery `to_ddl/2` walk), so
   the architecture is compatible — we're just missing most of the derivations and the codec.
3. **Open extension.** Filters, refinements, transformations, and annotations are
   first-class and user-supplied. Raggio's constraint set is currently *closed* (a fixed
   `min/max/pattern/unique` reduce in `validator.ex`).

Current Raggio surface (from `lib/raggio/schema.ex`, `type.ex`, `validator.ex`):
primitives `string/integer/float/boolean/date/datetime/decimal/atom`; composites
`struct/list/tuple/union/literal/record`; modifiers `optional/nullable/default`; constraints
`min/max/pattern/unique`; helpers `email/url/uuid`; `validate/validate!` with
`:fail_fast | :all_errors` modes and `partial: true`; adapters BigQuery DDL + SheetSchema.

## Goals / Non-Goals

**Goals:**
- Produce an honest, maintained parity matrix (this document) — the assessment the request
  asked for.
- Stand up a real test foundation for `Raggio.Schema` (it has none today).
- Ship JSON Schema generation (explicitly requested) as the first new derivation.
- Define a prioritized, additive roadmap to close the rest, with the codec decision made
  explicitly rather than by accident.

**Non-Goals:**
- 1:1 API mimicry of Effect (TypeScript idioms like branded types, `Symbol`, `BigInt`,
  class-based schemas, template literals) where Elixir has a better-fitting idiom or no need.
- Implementing every derivation now. `ToEquivalence`/`ToPretty` and exotic type constructors
  are documented in the matrix but deferred.
- Touching `Raggio.Syntax`, `Raggio.Tabular`, or the BigQuery kit beyond the shared schema
  adapter surface.

## The Parity Matrix

Legend: ✅ have · 🟡 partial · ❌ missing · ⬜ N/A or low-value in Elixir

### A. Core model
| Effect `Schema` | Raggio | Status | Notes |
|---|---|---|---|
| `Schema<Type, Encoded>` codec | validation-only | ❌ | The defining gap. See "Decisions: codec". |
| `decode`/`decodeUnknownSync` | `validate/2` (≈ decode-from-unknown) | 🟡 | Validates + applies defaults/`float` widening, but output ≈ input; no Encoded type. |
| `encode`/`encodeSync` | — | ❌ | No serialization direction. |
| `make`/constructor | — | 🟡 | `validate!` is the closest; no `.make` with constructor defaults. |
| AST introspection | `%Type{}` struct | ✅ | Already an inspectable AST (enables derivations). |

### B. Primitive & literal constructors
| Effect | Raggio | Status |
|---|---|---|
| String, Number, Boolean | `string`, `integer`/`float`, `boolean` | ✅ |
| Date / DateValid | `date`, `datetime` | ✅ |
| Decimal (via `Number`/BigDecimal) | `decimal` | ✅ |
| BigInt | (Elixir ints are arbitrary precision) | ⬜ |
| Symbol / UniqueSymbol | `atom` | 🟡 (atom ≈ symbol) |
| Undefined / Null / Void | `nil` via `nullable` | 🟡 |
| Unknown / Any | — | ❌ (no passthrough/any type) |
| Finite | — | ❌ (no NaN/Inf guard on float) |
| Literal / Literals(array) | `literal/1..3` | 🟡 (capped at 3 args; no list form) |
| TemplateLiteral | — | ❌ (niche) |

### C. Composite constructors
| Effect | Raggio | Status |
|---|---|---|
| Struct | `struct` | ✅ |
| Record | `record` | ✅ |
| Tuple / TupleWithRest | `tuple` | 🟡 (fixed only; no rest) |
| Array / UniqueArray | `list` (+`unique`) | ✅ |
| Union (+ `oneOf` mode) | `union` | 🟡 (linear try-each; no exclusive/oneOf) |
| StructWithRest (index sigs) | — | ❌ |
| TaggedStruct / TaggedUnion | — | ❌ (no discriminant fast-path) |

### D. Filters / checks
| Effect | Raggio | Status |
|---|---|---|
| min/maxLength, lengthBetween | `min`/`max` (string byte_size) | 🟡 (byte_size, not grapheme length) |
| greaterThan(OrEqualTo)/lessThan(OrEqualTo) | `min`/`max` (inclusive only) | 🟡 (no exclusive bounds) |
| between | `min`+`max` | ✅ |
| multipleOf | — | ❌ |
| int / int32 | (`integer` type) | 🟡 |
| pattern | `pattern` | ✅ |
| startsWith/endsWith/includes | — | ❌ |
| uppercased/lowercased | — | ❌ |
| nonEmpty | — | ❌ |
| uuid/base64/base64url | `uuid` regex helper only | 🟡 |
| isUnique (array) | `unique` | ✅ |
| `check`/`makeFilter` (custom predicate + message) | — | ❌ (constraint set is closed) |
| `.abort()` (stop on first) | `mode: :fail_fast` (global) | 🟡 (global, not per-check) |

### E. Transformations / encoding
| Effect | Raggio | Status |
|---|---|---|
| decodeTo/encodeTo, transform/transformOrFail | — | ❌ |
| trim / toLowerCase / toUpperCase | — | ❌ |
| numberFromString / coercions | — | ❌ (claimed in 001 spec, not implemented) |
| snakeToCamel, encodeKeys | — | ❌ |
| transformation `compose` | — | ❌ |

### F. Optionality, nullability, defaults
| Effect | Raggio | Status |
|---|---|---|
| optional / optionalKey | `optional` | 🟡 (no key-vs-undefined distinction) |
| NullOr / UndefinedOr | `nullable` | 🟡 |
| OptionFromOptional* (→ `Option`) | — | ⬜ (no `Option` type in Elixir) |
| withDecodingDefault vs withConstructorDefault | single `default` | 🟡 (one flavor, applied on nil) |

### G. Refinement, branding, composition
| Effect | Raggio | Status |
|---|---|---|
| refine (narrow type) | — | ❌ |
| brand (nominal types) | — | ⬜ (no compile-time brands in Elixir) |
| Struct.pick/omit/assign/evolve/map | — | ❌ |
| partial / mutableKey | `partial: true` (validate-time) | 🟡 (runtime flag, not a schema deriv) |
| renameKeys / encodeKeys | — | ❌ |
| Tuple/Union utilities (match, guards) | — | ❌ |
| suspend (recursive schemas) | — | ❌ (cannot express self-referential schemas) |
| declare / instanceOf / Class / Opaque | — | 🟡 (`atom`/`struct` cover some; no guard-based custom type) |

### H. Strictness & annotations
| Effect | Raggio | Status |
|---|---|---|
| onExcessProperty error/preserve/ignore | silently ignores unknown keys | ❌ (no strict mode) |
| annotate (identifier/title/description/examples) | unused `metadata` field on `%Type{}` | ❌ |
| custom messages (expected/messageMissingKey/...) | fixed English messages | 🟡 |

### I. Derivations
| Effect | Raggio | Status |
|---|---|---|
| ToParser | `validator.ex` | ✅ |
| BigQuery DDL (Raggio-specific) | `adapters/bigquery.ex` | ✅ (no Effect analog) |
| SheetSchema import (Raggio-specific) | `adapters/sheet_schema.ex` | ✅ |
| **ToJsonSchema** | — | ❌ **(requested deliverable)** |
| ToArbitrary (property test data) | — | ❌ (pairs with the testing gap) |
| ToEquivalence | — | ❌ (deferred) |

### J. Testing posture
| | Status |
|---|---|
| `Raggio.Schema` unit tests | ❌ **zero** (only BigQuery + examples are tested) |
| Property-based tests (`StreamData`) | ❌ |
| JSON Schema golden/conformance tests | ❌ (n/a until generator exists) |
| Maintained parity conformance suite | ❌ |

## Decisions

### D1. Make the codec decision explicitly — adopt a minimal `Transform` node (P2, not P0)
The single biggest fork is whether Raggio stays a validator or becomes a codec. Recommendation:
**become a codec, incrementally.** Add a `transform` node carrying `decode`/`encode` functions
and let `validate/2` run the decode direction. This is what makes the existing "parse, don't
validate" claim real and unlocks coercion (`number_from_string`, currency, `trim`) and JSON
round-tripping. Sequence it *after* the test foundation so we change the engine with a net.
Until then, the 001 spec's coercion/transform claims should be treated as **proposed**, not
shipped, and this doc is the reconciliation.

### D2. JSON Schema generation mirrors the BigQuery adapter (P0)
`Raggio.Schema.Adapters.JsonSchema.to_json_schema/1` walks `%Type{}` exactly like
`to_ddl/2`. Mapping:
- kinds → `type` (`string`, `integer`, `number`, `boolean`; `date`/`datetime`/`decimal` →
  `string` + `format`/annotation);
- `min`/`max` → `minLength`/`maxLength` (string), `minimum`/`maximum` (number),
  `minItems`/`maxItems` (list); `pattern` → `pattern`; `unique` → `uniqueItems`;
- `struct` → `{type: object, properties, required}` (required = non-`optional`, non-`default`);
- `list` → `{type: array, items}`; `tuple` → `prefixItems`; `record` →
  `{type: object, additionalProperties: <value schema>}`; `union` → `anyOf`;
  `literal` → `const`/`enum`; `nullable` → `type: [..., "null"]`; `default` → `default`.
- Target draft 2020-12. Annotations (D4) flow into `title`/`description`/`examples`.
This is low-risk, high-value, and gives the library an external, testable contract.

### D3. Open the constraint set with custom refinements + the common checks (P1)
Add `Schema.refine(schema, predicate, message)` (or a `check` combinator) so users aren't
limited to the built-ins, plus first-class checks for the high-frequency Effect ones:
exclusive bounds, `multiple_of`, `int`, `non_empty`, `starts_with`/`ends_with`/`includes`,
`length`. Promote `email`/`url`/`uuid` from raw regexes to named checks so they surface good
messages and annotate JSON Schema `format`.

### D4. Activate the dormant annotation channel (P3, but unblock JSON Schema early)
`%Type{}` already has an unused `metadata` map. Define `Schema.annotate/2` writing
`identifier`/`title`/`description`/`examples`, and have JSON Schema + error messages read it.
Even a thin version (title/description/examples) materially improves the JSON Schema output.

### D5. Recursive schemas via `suspend` (P3)
Add `Schema.suspend(fn -> schema end)` so self-referential structures (trees, nested JSON)
are expressible. Required before JSON Schema `$ref`/`$defs` for recursive types is meaningful.

### D6. Strict structs are opt-in (P3)
Add `Schema.strict/1` (or a `:strict` validate option) for `onExcessProperty: error`.
Default stays lenient to preserve current `validate/2` behavior — this is a compatibility line.

### D7. Property-based tests are part of the foundation, not an extra (P0)
Add `stream_data` (`:test` dep). Derive generators from schemas (a minimal `ToArbitrary`):
valid-value generation → assert `validate` accepts; targeted invalid generation → assert
rejects with the expected `:constraint`. Once the codec lands, add `encode |> decode == id`
round-trip properties. This is how we keep the matrix honest over time.

## Priority Roadmap

```
P0  Test foundation (unit + StreamData)        ── prerequisite, de-risks everything
P0  JSON Schema generation (adapter)            ── requested, isolated, high value
P1  Custom refine + expanded checks             ── unlocks extensibility, small surface
P2  Bidirectional transforms / codec           ── the architectural decision; needs P0 net
P3  Composition (pick/omit/partial/rename),
    recursive suspend, tagged unions,
    strict structs, annotations                 ── ergonomics + completeness
deferred  brand, Symbol/BigInt, class-based,
          template literals, ToEquivalence       ── documented, low ROI in Elixir
```

## Risks / Trade-offs

- **Engine churn without tests = regressions.** Mitigated by sequencing P0 first; no
  behavior-changing work (D1/D3/D6) merges before the test tree exists.
- **Scope creep toward "reimplement Effect."** Mitigated by the Non-Goals and the
  deferred tier — we copy ideas, not the TypeScript API.
- **Codec migration is invasive** (touches `Type` + `Validator` + every adapter). Keeping it
  additive (new `transform` node, decode path optional) limits blast radius, but encode for
  existing adapters (BigQuery/Sheet) needs a compatibility check.
- **Default-semantics divergence.** Effect separates constructor vs decoding defaults; if we
  later split ours, current `default` behavior must remain the decoding default to avoid a
  breaking change.
- **JSON Schema fidelity for Elixir-only types** (`decimal`, `atom`, `date`) requires
  annotation/`format` conventions that no external validator enforces natively — document the
  chosen representation.
