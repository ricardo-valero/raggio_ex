## 1. P0 — Test foundation

- [x] 1.1 Add `stream_data` as a `:test` dependency in `mix.exs`; `mix deps.get`
- [x] 1.2 Create `test/raggio/schema/` tree; unit-test every primitive constructor (`string/integer/float/boolean/date/datetime/decimal/atom`): accept valid, reject wrong type, default applied on nil
- [x] 1.3 Unit-test every composite (`struct/list/tuple/union/literal/record`): nesting, ordering, `unique`, tuple size mismatch, union variant selection, record key/value validation
- [x] 1.4 Unit-test constraints (`min/max/pattern/unique`) across string/number/list, and `optional`/`nullable`/`default`
- [x] 1.5 Unit-test validation modes: `:fail_fast` vs `:all_errors` error counts, and `partial: true` `{successes, failures}` shape; assert error `:path` correctness for nested failures
- [x] 1.6 Add property-based tests (`StreamData`): derive a valid-value generator per schema → assert `validate` accepts; targeted invalid generators → assert reject with expected `:constraint`
- [ ] 1.7 Record current coverage baseline; wire into CI alongside Credo

## 2. P0 — JSON Schema generation

- [x] 2.1 Create `lib/raggio/schema/adapters/json_schema.ex` with `to_json_schema/1` walking `%Type{}` (mirror `adapters/bigquery.ex`)
- [x] 2.2 Map primitives + `date`/`datetime`/`decimal` (→ `string` + `format`/convention) and constraints → `minLength`/`maxLength`/`pattern`/`minimum`/`maximum`/`minItems`/`maxItems`/`uniqueItems`
- [x] 2.3 Map composites: `struct` → object/properties/required (exclude optional & defaulted), `list` → array/items, `tuple` → prefixItems, `record` → additionalProperties, `union` → anyOf, `literal` → enum/const, `nullable` → `type: [..., "null"]`, `default` → `default`
- [x] 2.4 Target draft 2020-12; emit `$schema`; read annotations (`title`/`description`/`examples`) from the metadata channel
- [x] 2.5 Structural golden tests of generated documents; runnable `examples/schema/adapters/json_schema_export.exs` (smoke-tested by `examples_test`)

## 3. Foundational — uniform-node + checks engine (architecture pivot, D11)

> **Do this before P1/P2.** Swap the internal engine from the bespoke `%Type{kind, constraints,
> …}` model to an effect-smol-shaped **uniform node + checks** AST, while keeping the macro-less
> combinator **surface** identical. This is what makes refinements (P1) and the codec (P2) native
> instead of bolt-ons. The public API and the P0 tests are the safety net for the swap.

- [x] 3.1 Introduce `Raggio.Schema.AST`: one uniform node = `kind` + a single payload slot per
      kind (`inner` / `fields` / `elements` / `key_type` / `value_type` / `values` / `module`) + the
      uniform slots `checks: [%Check{}]`, `encoding: []`, `context: %Context{}`, `metadata: %{}`
- [x] 3.2 Introduce `%Raggio.Schema.Check{}` (constraint tag + `run` + machine-readable JSON-Schema
      `meta`) and `%Context{}` (per-field `optional?`/`nullable?`/`default: :none`); port existing
      `min/max/pattern/unique` from `%Type{}` fields to Checks and move `optional`/`nullable`/`default`
      to `context`
- [x] 3.3 Surface unchanged: `Schema.string(min: 1)`, `Schema.struct/1`, `Schema.list/2`,
      `s |> Schema.optional()` build the new AST + push Checks / set context. No public API change;
      the P0 tests stayed green unmodified.
- [x] 3.4 Rewrote `Validator` as an interpreter over the uniform AST; preserves
      `{:ok, _} | {:error, [Error]}`, `:fail_fast`/`:all_errors`, and `partial: true`
- [x] 3.5 Rewrote the JSON Schema adapter to walk the AST (folds `checks[].meta` into keywords);
      golden tests green
- [x] 3.6 Updated the BigQuery DDL adapter + `Raggio.BigQuery.Table` that read `%Type{}` to read the
      AST + `context` (Sheet adapter emits code strings, reads no `%Type{}`); their tests green
- [x] 3.7 Full suite green through the swap (247 tests + 6 properties); deleted `%Type{}` (one
      white-box test reference `%Schema.Type{}` → `%Schema.AST{}`)

## 4. P1 — Checks + refinements (native to the uniform model)

- [x] 4.1 `Schema.refine/3` (predicate + message) → a custom `%Check{}` (constraint `:refine`);
      runs after the type matches, honors `:fail_fast`/`:all_errors`. Also `Schema.check/2` to
      attach a prebuilt `%Check{}`.
- [x] 4.2 Check builders: exclusive bounds (`greater_than`/`less_than` + `gt`/`lt` aliases),
      `multiple_of`, `int`, `non_empty` (string + list), `starts_with`/`ends_with`/`includes`,
      `uppercase`/`lowercase`, grapheme `length` — each carrying JSON-Schema `meta`
- [x] 4.3 `format: :email | :url | :uuid` named checks (good messages + JSON Schema `format`);
      `email`/`url`/`uuid` regex helpers retained as the underlying patterns
- [x] 4.4 Tests (unit + property) for every new check, custom refinements, and their JSON Schema meta

## 5. P2 — Codec: the encoding chain (decoded ↔ encoded)

- [x] 5.1 `encoding` slot populated: a `:transform` node carries a `%Transformation{decode, encode}`
      (pure getters; no effect runtime). `Schema.transform/3` builds one.
- [x] 5.2 `validate/2` (and `decode/2` alias) run the decode direction; `encode/2` (`Raggio.Schema.Encoder`)
      reverses transforms, recursing through `:struct`/`:list`
- [x] 5.3 Built-in transforms: `number_from_string`, `trim`, `downcase`/`upcase`, `datetime_from_iso8601`;
      composition via nesting `Schema.transform/3`
- [x] 5.4 Reconciled the 001 "coercion and bidirectional transforms" claim — now really implemented
      (decode coercion + encode). Note: propagation **through struct fields** is gated on
      struct-building decode (§7.1); top-level and list propagation work now.
- [x] 5.5 Tests (`codec_test.exs`): decode coercion, structured `:transform` decode-failure,
      list propagation, composition, JSON-Schema encoded-side, and `encode |> decode == id` property

## 6. P3 — Composition, recursion, strictness, annotations

- [ ] 6.1 Struct utilities: `pick`/`omit`/`partial`/`assign`/`rename_keys` (schema-level derivations)
- [ ] 6.2 Recursive schemas: `Schema.suspend/1` (the reserved `:suspend` kind); JSON Schema `$defs`/`$ref` for recursive types
- [ ] 6.3 Strict struct mode (`Schema.strict/1` or `:strict` option); default stays lenient
- [ ] 6.4 `Schema.annotate/2` (`identifier`/`title`/`description`/`examples`) over the `annotations` slot; readable by JSON Schema + error formatting
- [ ] 6.5 Tests for all of the above

## 7. Consumer-driven parity — back integration-hub's `Domain.Schema`

> Driver: `integration-hub` PR #60 (merged) built `Domain.Schema`, an effect-smol-shaped
> Elixir engine (uniform AST + checks + encoding chain + Issue tree + tagged unions +
> literals + declarations + transforms + JSON Schema/OpenAPI). The goal is for raggio to
> back a **thin macro shim** there. These items are what that shim concretely needs; they
> re-prioritize P1–P3 (declarations + tagged unions become table-stakes, not "someday").
> **Acceptance gate:** integration-hub's `Domain.Schema` test suite (domain 150) stays green
> against a raggio-backed shim.

- [x] 7.1 Struct-building decode (effect's Type projection): struct decode **rebuilds** the output
      (decoded/transformed field values + applied defaults; undeclared keys dropped; absent optional
      fields stay absent). `Schema.struct(fields, module: Mod)` binds a target struct — decode returns
      `%Mod{}` via `struct!/2` (loud on schema/struct mismatch, no silent drop). Also closes the P2
      gap: transforms now propagate through struct fields.
- [x] 7.2 Module-backed schemas via one entry point (core stays macro-free): `use Raggio.Schema`
      + `schema do <combinator> end` where the block holds ONE expression in raggio's own
      vocabulary and the macro dispatches on its head — `struct fields` (defstruct + `@type t` +
      bound decode), `literal values[, decode: :downcase|:upcase]` (`values/0` + `@type t`),
      `union [A, B]` / any other expression (generic: the module IS that schema). Fields stay
      data (the same keyword list `Schema.struct/1` takes); the Ecto-like `field` DSL was
      deliberately rejected (D8 amendments) — that opinion lives in integration-hub's shim. Plus:
      **any module exporting `__schema__/0` is usable as a schema** (module-typed fields compose,
      embedded modules decode to their own structs).
- [x] 7.3 **Declarations / opaque custom types**: `Raggio.Schema.Declaration` behaviour
      (`decode/1`, `encode/1`, `json_schema/0` override) + `Schema.declare/1`; `use` provides
      `__schema__/0` so declarations compose via the module convention. Errors carry the
      `:declaration` constraint. (Mirrors Domain.Schema Decision 6.)
- [x] 7.4 **Tagged/discriminated unions**: `Schema.union(:name, [Fedex, Imile])` (and the
      `union(:name, [...])` schema-block head). Members MUST declare the discriminator as a
      literal field (raises at construction — invalid pairs unrepresentable); decode dispatches
      on the tag so errors come from the matched member; unknown tags report the allowed values
      (`:discriminator` constraint); encode flattens the member struct back to a wire map.
- [x] 7.5 Normalizing literals + literal set form: `Schema.literals(values)` (lifts the 3-arg cap)
      and `Schema.literals(values, decode: :downcase | :upcase)` (wire lenient, decoded canonical);
      surfaced as modules via `use Raggio.Schema.Literal`.
- [ ] 7.6 OpenAPI-grade JSON Schema coverage — largely landed alongside 7.3/7.4: tagged unions →
      `oneOf` + `discriminator`, untagged → `anyOf`, literal sets → `enum`, declarations → module
      override, transforms → encoded-side. Remaining: `$defs`/`$ref` for named/recursive schemas
      (pairs with P3 `suspend`). (The OpenAPI assembly itself stays in integration-hub's `:api`.)
- [x] 7.7 Acceptance: mirrored the consumer's full engine behaviour suite (40 cases) into
      `test/raggio/schema/acceptance_test.exs` with **anonymized fixture names** — green.
      Drove three wire-convention engine fixes: string-keyed input maps (`fetch_wire`), atom
      literals decoding from their string wire form (incl. tagged-union dispatch + normalizing
      sets), nil fields omitted on encode. Added `Schema.default/2` (pipe-friendly default for
      any schema, incl. modules). **Deliberately shim-level (NOT raggio):** cross-field
      `validate/1` refinement (runs post-decode around raggio in the consumer), `parse!`'s
      flattened error-map format, and the Issue-*tree* error shape (raggio keeps flat
      path-carrying errors; the shim can fold them into a tree).

## 8. Wrap-up

- [ ] 8.1 Update the parity matrix in `design.md` to reflect shipped items; keep it as the living conformance reference
- [ ] 8.2 README: document JSON Schema export, refinements, transforms, and the optional struct macro
- [ ] 8.3 Confirm deferred items (brand, Symbol/BigInt, template literals, `ToEquivalence`) remain explicitly out of scope with rationale — note these are *also* deferred by Domain.Schema (domain doesn't use them)
- [ ] 8.4 **Revisit `Raggio.Syntax` (D12):** propose the follow-up change deciding retire-vs-repoint
      for its superseded schema node types (`SchemaNode`/`FieldNode`/`TypeNode`) — preferred
      direction: re-point the generic `Node` protocol + `traverse`/`find`/`transform` at
      `%Schema.AST{}` as the shared traversal layer for derivations. Owns the `syntax` capability
      spec delta. This change must NOT be archived with this box unchecked and no follow-up filed.
