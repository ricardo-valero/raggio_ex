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

## Consumer-driven parity: integration-hub's `Domain.Schema`

`integration-hub` PR #60 (merged, change `replace-ecto-domain-with-schema`) built
`Domain.Schema` — an effect-smol-shaped Elixir engine (uniform AST + `checks`/`encoding`/
`context`/`annotations` slots, Issue tree, tagged unions, literals-as-primitive,
Declarations, Transforms, and a JSON Schema/OpenAPI compiler). It is, on the effect-smol
axis, *ahead* of raggio's current `%Type{}`/Validator model on nearly every dimension.

The intended end-state is **not** two engines: `Domain.Schema` becomes a **thin macro shim**
that lowers its `schema do field … end` DSL onto `Raggio.Schema`, and the *engine logic*
lives in raggio. This makes `Domain.Schema`'s test suite (domain 150 green) the concrete
**acceptance gate** for "raggio is on par": fuzzy parity → green-or-not.

This reframes the roadmap: parity is driven by what a real consumer uses, not an abstract
checklist. Items the domain never uses (brand, template literals, `ToEquivalence`,
`suspend`/recursion) stay deferred — *as they are in `Domain.Schema` itself*.

### Decision D8 — `@type t` / struct generation is macro territory; ship it opt-in
A runtime value (`Schema.struct([...])` returning data) **cannot** emit an `@type t` or a
`defstruct` — those are compile-time. Only a macro can, and a macro sees the field
declarations literally, so it can derive an accurate typespec (`{:float, gt: 0}` → `float()`,
module-typed → `Mod.t()`, union → `A.t() | B.t()`). Therefore the runtime core stays
macro-free, and an **optional `use Raggio.Schema.Struct`** macro provides the Ecto-like
call-site, `defstruct`, `@type t`, `__schema__/0`, and `decode`/`encode` wrappers. integration-
hub's `Domain.Schema` then collapses to ~a re-export of that macro.

### Decision D9 — `decode` builds the struct (effect's Type projection), opt-in via a bound module
effect-smol's `decode`/`make` yield the **Type** projection; for a `Class`/struct schema that
is the typed value, and `Domain.Schema.parse` returns the member struct. A validated *map* is
the weaker model. So a `:struct` node may carry a **bound `:module`** (mirroring
`Domain.Schema.AST`'s `:module` slot); the interpreter returns `struct(Mod, decoded)` when
bound and a plain map otherwise. The macro (D8) binds the module; the runtime API stays
map-based. This is both more powerful and more effect-aligned.

### Decision D10 — promote Declarations and tagged unions to table-stakes
The consumer uses **Declarations** (opaque custom types, e.g. `Json`) and **tagged unions**
(carrier `{name, service}` made unrepresentable-when-invalid). These move out of the deferred
tier / P3 into the consumer-driven tier (task group 6). Untagged unions and literal *sets*
with normalizing decode (`:downcase`/`:upcase`) come along.

### Decision D11 — uniform-node + checks *engine*, behind the macro-less combinator *surface*
Engine architecture and construction surface are **orthogonal axes**:

```
                  SURFACE (declare)       macro DSL          macro-less combinators
ENGINE (AST)   bespoke node + fields          —              raggio TODAY
               uniform node + checks     Domain.Schema        ⭐ TARGET = effect-smol itself
```

effect-smol lives in the bottom-right: its `Schema` is **macro-less combinators**
(`Schema.String.pipe(minLength(2))`, `Schema.Struct({…})`, `decodeUnknownSync`) over a
**uniform** AST. So raggio's macro-less surface is *already* the effect-faithful surface;
what's wrong is the **engine** — raggio stores `min: 1` as a *field* on a per-kind struct
(the `data_schema` bespoke-node model), where effect stores it as a `Check` on a uniform node.

**Decision:** keep raggio's column (macro-less combinators — `Schema.string(min: 1)`,
`Schema.struct/1`, `s |> Schema.optional()`), drop one row — replace the bespoke `%Type{kind,
constraints, inner, fields, optional, …}` with a **uniform `%AST{kind, checks, encoding,
context, annotations}`** (shaped like `Domain.Schema.AST`). Constructors become thin builders
that push `Check`s and set `context`; `Validator` becomes an interpreter over the uniform AST
(one AST, many projections). This lands raggio exactly where effect-smol is.

Consequences:
- **Refinements (P1) and the codec (P2) become native, not bolt-ons.** A refinement *is* a
  `Check`; the codec *is* the `encoding` chain. Adopting the uniform AST de-risks the rest of
  the roadmap instead of piling onto the bespoke base. This **supersedes** the earlier
  "grow the current model" framing (D1/D3) — those become *projections of* the uniform model.
- **The P0 behavioral tests are the safety net.** They assert through the public API, so they
  survive the engine swap; the JSON Schema adapter (reads `%Type{}` directly) is the one piece
  that must be rewritten to walk the AST, gated by its own golden tests.
- **The opt-in `use Raggio.Schema.Struct` macro (D8) is effect's `Schema.Class` analog** — the
  single place effect itself reaches for a class. Combinators for the 95%, a Class-like macro
  for named structs + `@type t`. Fully consistent.
- **Cost:** a breaking *internal* rewrite (`Type` → `AST`, `Validator` → interpreter, rewrite
  the BigQuery/Sheet/JSON-Schema readers). It lands as a **foundational task group (§3)** that
  runs *before* P1/P2. Public surface + tests shield callers.

### Revised priority (consumer-driven, D11-sequenced)
```
P0   done — tests + JSON Schema adapter (#7)
F    FOUNDATIONAL — uniform-node + checks engine swap (§3, D11)          ← everything builds on this
P1   refine + expanded checks (gt/lt/multiple_of/string-content)        ← now native Checks
P2   codec: decode/encode + transforms via the encoding chain            ← now native encoding slot
C    consumer table-stakes: struct-building decode, struct macro,        ← group 7, gated by
     declarations, tagged unions, literal sets, OpenAPI-grade JSON          integration-hub tests
P3   strictness, annotations, struct utilities, recursion (suspend)     ← ergonomics
deferred  brand, template literals, ToEquivalence                        ← domain doesn't use them
```

### Out of scope here (lives in integration-hub)
The actual swap — adding the `raggio_ex` dep, rewriting `Domain.Schema` as the shim, deleting
the 8 engine modules, and the OpenAPI assembly — is a **separate change in integration-hub**
(`back-domain-schema-with-raggio`) that depends on this one. Not captured in this repo.

## Appendix — §3 AST shape spike (de-risks the foundational swap)

Concrete target structs, so §3 is a mechanical port rather than an open rewrite.

```elixir
%Raggio.Schema.AST{
  kind: :string|:integer|:float|:boolean|:atom|:date|:datetime|:decimal
      | :literal|:struct|:array|:tuple|:record|:union|:declaration|:suspend,
  # payload — only the slot for `kind` is meaningful:
  literal:  term(),            # :literal → value, or list = closed set
  element:  t(),               # :array   → inner
  elements: [t()],             # :tuple   → positional
  variants: [t()],             # :union   → members
  key:      t(), value: t(),   # :record
  fields:   [{atom, t()}],     # :struct  → ordered
  module:   module(),          # :struct (bound target) | :declaration (opaque)
  discriminator: atom() | nil, # :union   → nil untagged / field tagged
  thunk:    (-> t()),          # :suspend
  # uniform slots — on every node:
  checks:      [Check.t()],    # was %Type.constraints
  encoding:    [Link.t()],     # codec chain (P2; [] today)
  context:     Context.t()|nil,# was node flags optional/nullable/default
  annotations: %{}             # title/description/examples/format/json_schema
}

%Raggio.Schema.Check{ name: atom, run: (term -> :ok | {:error, msg}),
                      meta: %{}, aborted: false }   # meta = JSON-Schema descriptor
%Raggio.Schema.Context{ optional?: false, nullable?: false, default: :none }  # :none ≠ nil
```

Lowering (public API unchanged):
- `Schema.string(min: 3)` → `%AST{kind: :string, checks: [%Check{name: :min_length,
  meta: %{"minLength" => 3}}]}`
- `s |> Schema.optional()` → sets `s.context.optional?: true` (NOT a node flag); `struct/1`
  reads each field's `context`. `nullable`/`default` likewise → `context`.
- `Schema.list(inner, unique: true)` → `%AST{kind: :array, element: inner, checks: [unique]}`

Interpreter: type-match `kind` → run `checks` (honor `aborted`/mode) → run `encoding` decode
(P2 no-op) → recurse composites (struct reads field `context`) → if `:struct` + `module`,
`struct(mod, map)` else map. JSON Schema adapter: `base_type(kind) |> fold(checks[].meta) |>
merge(annotations) |> required_from(contexts)` — i.e. the per-constraint mapping moves into
each check's `meta`, and the adapter becomes check-agnostic (shorter).

Scope guardrails for §3 (keep it behavior-preserving):
- **Error shape stays flat** (`%Error{path, message, value, constraint}`). The richer Issue
  *tree* is a later step, NOT part of §3 — this is what keeps the P0 tests green unmodified.
- No public API change; `Type` deleted only once nothing reads it; adapters re-pointed to `AST`.
