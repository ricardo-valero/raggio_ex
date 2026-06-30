# Effect Schema (effect-smol) Parity

## Why

`Raggio.Schema` is consciously modeled on Effect-TS `Schema`, but it currently implements
only a small slice of that surface and has **zero automated tests** — every test in the
repo targets the BigQuery kit. Before building more on top of it (more adapters, codegen,
downstream kits), we need an honest baseline: *what does Effect's `Schema` (the
`effect-smol` rewrite) offer, what do we already cover, and what are the highest-value
gaps to close — for both implementation and testing.*

Two gaps are strategic rather than cosmetic:

1. **`Raggio.Schema` is validation-only; Effect `Schema` is a bidirectional codec.**
   Effect schemas are `Schema<Type, Encoded>` with `decode`/`encode` and composable
   transformations. Ours checks a value and (mostly) passes it through. Notably, the
   archived 001 spec *claims* coercion + bidirectional transforms as part of the schema
   capability, but `lib/raggio/schema/validator.ex` implements neither — so we have a
   documented-vs-shipped gap to reconcile, not just a parity gap.
2. **No JSON Schema generation.** This was called out explicitly. We already prove the
   "walk the `Type` AST → emit a target format" pattern in
   `Raggio.Schema.Adapters.BigQuery` (`to_ddl/2`), so a JSON Schema exporter is tractable
   and high-value — and it doubles as the cleanest external contract for the whole library.

## What Changes

This change establishes a parity baseline and proposes a prioritized roadmap to close the
gaps. The design document holds the full Effect-vs-Raggio feature matrix; the spec deltas
and tasks scope the concrete near-term work:

- **Test foundation (P0):** unit coverage for every constructor / constraint / error path /
  validation mode, plus property-based tests via `StreamData` (the analog of Effect's
  `ToArbitrary`). This is prerequisite to safely changing anything else.
- **JSON Schema generation (P0):** a `Raggio.Schema.Adapters.JsonSchema` exporter
  (draft 2020-12) mirroring the BigQuery adapter.
- **Custom refinements + expanded checks (P1):** open the closed constraint set with a
  user-supplied predicate/filter (with message), and add the common Effect checks
  (exclusive bounds, `multiple_of`, `int`, `non_empty`, `starts_with`/`ends_with`/
  `includes`, case checks, `length`).
- **Bidirectional transforms / codec (P2):** a `Transform` node giving `decode`/`encode`,
  enabling real coercion (e.g. `number_from_string`, currency strings, `trim`) and JSON
  round-tripping — making "parse, don't validate" actually true.
- **Composition + recursion + annotations (P3):** struct `pick`/`omit`/`partial`/rename,
  tagged unions, recursive schemas (`suspend`), strict/excess-property handling, and a
  populated annotation channel (title/description/examples) that also enriches JSON Schema.

## Capabilities

### New Capabilities

None — this extends existing capabilities rather than introducing a new top-level one.

### Modified Capabilities

- `schema`: adds custom refinements, an expanded built-in check set, bidirectional
  transforms (decode/encode), recursive schemas, strict/excess-property handling, and a
  usable annotation channel.
- `schema-adapters`: adds a JSON Schema (draft 2020-12) generator alongside the existing
  BigQuery DDL exporter and SheetSchema importer.

## Impact

- `lib/raggio/schema/type.ex` — likely new node kinds/fields (`refine`, `transform`,
  `suspend`, populated `metadata`/annotations, strict flag).
- `lib/raggio/schema/validator.ex` — refinement evaluation, new checks, decode/encode path.
- `lib/raggio/schema.ex` — new public constructors/combinators.
- `lib/raggio/schema/adapters/json_schema.ex` — **new** exporter.
- `test/raggio/schema/**` — **new** test tree (currently nonexistent), incl. property-based
  tests; add `stream_data` as a `:test` dependency.
- Backwards compatibility: additive. Strict-struct mode and any default-semantics change
  must be opt-in to avoid breaking current `validate/2` behavior.
