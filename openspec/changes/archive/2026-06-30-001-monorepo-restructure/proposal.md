# Multi-Package Monorepo Restructure

## Why

The existing `old_code/data_schema` codebase grew into a sprawling, macro-heavy library (`DataSchema`, plus a separate syntax/AST manipulation layer) that was hard to learn and hard to extend. It relied on pipe-based builders, `use`-macro patterns, `@schema` attributes, and 14+ overlapping constraints, with documentation scattered across inline docstrings rather than runnable examples.

The goal is to restructure this into a single Elixir package (Ecto-style, NOT an umbrella) with clearly layered submodules `Raggio.Schema` and `Raggio.Syntax`, renamed from the old `DataSchema` and syntax components. The new API favors function composition over macros, uses argument-composition syntax for constraints (e.g. `Schema.string(min: 3, max: 5)`), collapses constraints down to a minimal orthogonal set, and treats working/compilable examples as primary documentation. The design draws on Effect-TS/Schema for ergonomics and "parse, don't validate" semantics, and on Ecto for package layout.

## What Changes

- Introduce a single Elixir package `raggio` with submodules as primary API entry points; the root `Raggio` module stays minimal.
- Add `Raggio.Schema`: a composable schema definition and validation library using argument-composition syntax (constraints as keyword options on type constructors).
- Provide primitive type constructors: `string`, `integer`, `float`, `boolean`, `decimal`, `date`, `datetime`, `atom`.
- Provide composite type constructors: `struct` (keyword list of tuples), `list`, `tuple`, `record` (typed map with dynamic keys), `union`, and `literal` (variadic).
- Collapse to exactly 4 core constraints: `min`, `max` (polymorphic across numbers/strings/lists), `pattern` (strings), `unique` (lists). Convenience helpers `email/0`, `url/0`, `uuid/0` return predefined regex patterns.
- Distinguish field descriptors (`optional/1`, `nullable/1` wrapper functions) from the `default:` keyword option.
- Validation returns binary results by default (`{:ok, parsed}` | `{:error, errors}`) following "parse, don't validate", with structured error maps (`:path`, `:message`, `:value`, `:constraint`).
- Support validation modes: `:fail_fast` (default) and `:all_errors`, plus opt-in `partial: true` mode returning `{:ok, {successes, failures}}` for composites.
- Add `Raggio.Syntax`: composable builders, traversal combinators, and transformation utilities for syntax trees (nodes, fields, types, trees), replacing macro-generated AST pattern matching.
- Add schema import/export adapters: a BigQuery DDL exporter and a SheetSchema (CSV / Google Sheets) importer.
- Add a two-level `examples/[submodule]/[use_case]` hierarchy with an automated test suite that compiles and runs every example.
- Clean break from `old_code` — no backward-compatibility or migration layer. Raggio.Tabular (Excel/CSV parsing) is explicitly deferred to a follow-up iteration.

## Capabilities

### New Capabilities

- `schema`: Composable data-schema definition and validation (`Raggio.Schema`) — primitive and composite type constructors, the 4 core constraints, field descriptors, convenience pattern helpers, and the `validate`/`validate!` engine with fail-fast, all-errors, and partial modes following "parse, don't validate".
- `syntax`: Composable syntax-tree manipulation (`Raggio.Syntax`) — node/field/type/tree builders, depth-first and breadth-first traversal combinators, find/find_all queries, and transform/filter/replace transformations via a `Node` protocol, minimizing macros.
- `schema-adapters`: Import/export adapters layered on `Raggio.Schema` — a BigQuery Standard SQL DDL exporter (`to_ddl/2,3` with type mapping and NOT NULL / DEFAULT handling) and a SheetSchema importer (`from_csv`, `from_url`, `validate_format`) that converts spreadsheet column definitions into Raggio.Schema code.

### Modified Capabilities

None — this is the initial introduction of the Raggio package. The work supersedes the prior `old_code/data_schema` implementation via a clean break rather than modifying an existing OpenSpec capability.

## Impact

- New single package `raggio` with `mix.exs` (`app: :raggio`, `elixir: "~> 1.14"`), `config/config.exs`, `.formatter.exs`, `test/test_helper.exs`.
- New dependencies: `Decimal` (precise numerics) and `Jason` (JSON for the BigQuery exporter).
- New modules under `lib/raggio/schema/*`: `type.ex`, `error.ex`, `validator.ex`, primitive/composite type constructors, `constraints`, `descriptors`, `coercion`, `transform`, and `adapters/{bigquery,sheet_schema}.ex`.
- New modules under `lib/raggio/syntax/*`: `node.ex`, `builder.ex`, `traversal.ex`, `transform.ex`.
- Root `lib/raggio.ex` reduced to version/config only.
- New `examples/schema/*` and `examples/syntax/*` directories plus `test/examples_test.exs`.
- Removal of the `old_code/data_schema` implementation (moved to `old_code/umbrella_apps`); no compatibility shim.
- Raggio.Tabular (SheetSchema DSL, Tabular adapter, Excel transforms) deferred — not part of this change.
