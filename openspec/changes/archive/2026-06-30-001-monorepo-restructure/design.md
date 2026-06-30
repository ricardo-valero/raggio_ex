# Design: Multi-Package Monorepo Restructure

## Context

The original code lived in `old_code/data_schema` as a macro-heavy `DataSchema` library plus a separate syntax/AST manipulation layer. It used pipe-based builders (`string() |> min(1) |> max(100)`), a `use DataSchema` macro pattern, `@schema` module attributes, `tuple(...)` for structs, and a large set of overlapping constraints (email, url, uuid, positive, negative, range, min_items, max_items, min_length, max_length, etc.).

This change reshapes that work into a single Elixir package named `raggio`, following Ecto's single-package-with-submodules architecture (explicitly NOT an umbrella project). The two in-scope submodules are `Raggio.Schema` and `Raggio.Syntax`. Submodules are the primary entry points (`Raggio.Schema.string()`, `Raggio.Syntax.transform()`); the root `Raggio` module is minimal. The API design is influenced by Effect-TS/Schema for composability and "parse, don't validate" semantics, adapted to idiomatic Elixir (functions rather than values, keyword options rather than `.pipe()` chains).

External research informed two main reference points: Effect-TS/Schema (constraint chaining, struct definitions, structured errors with paths, decode/encode) and Ecto (single package, `lib/<pkg>.ex` + `lib/<pkg>/<submodule>.ex` layout, `elixirc_paths` for test support, protocol consolidation). A migration analysis of 41 files in `old_code/data_schema` classified each component as migrate / defer / drop.

## Goals / Non-Goals

**Goals:**

- Single Elixir package with submodules (Ecto-style), not an umbrella; root module minimal.
- `Raggio.Schema` and `Raggio.Syntax` as the renamed, restructured replacements for `DataSchema` and the syntax layer.
- Argument-composition API: constraints are keyword options on type constructors.
- Minimize macros in the public API; maximize composability with composition-time errors for incompatible types.
- Layered architecture with one-way dependencies (`Raggio.Syntax` may depend on `Raggio.Schema`; `Raggio.Schema` depends on no other Raggio submodule).
- "Parse, don't validate": validation parses input into well-typed domain data, not a boolean pass-through.
- Working, compilable examples as primary documentation, verified by an automated test suite; module-level docs only.
- Include BigQuery DDL exporter and SheetSchema importer adapters.
- Explicit feature-parity verification before `old_code` deletion.

**Non-Goals:**

- Umbrella project structure (rejected per user requirement).
- Backward compatibility or migration tooling for old `DataSchema` code (clean break, FR-013).
- Publishing to Hex.pm (separate concern).
- Performance optimization or benchmarking (explicitly out of scope).
- Raggio.Tabular / Excel/CSV parsing (SheetSchema DSL, Tabular adapter, Excel transforms) — deferred to a follow-up iteration.
- A comprehensive API documentation website (examples are the docs).
- Support for languages other than Elixir.

## Decisions

- **Elixir 1.14+ baseline.** Minimum supported version; provides modern features while keeping good ecosystem compatibility. `mix.exs` uses `elixir: "~> 1.14"`, `elixirc_paths/1` adding `test/support` in `:test`, and `consolidate_protocols: Mix.env() != :test`.

- **Minimal external dependencies.** Only `Decimal` (precise numerics) and `Jason` (JSON encoding for the BigQuery exporter). No heavyweight framework dependencies.

- **Single package, submodules as entry points.** Layout mirrors Ecto: `lib/raggio.ex` (minimal root), `lib/raggio/schema.ex` + `lib/raggio/schema/*`, `lib/raggio/syntax.ex` + `lib/raggio/syntax/*`. Submodules are independently usable within one dependency.

- **Schema `Type` struct as internal AST.** A single `%Raggio.Schema.Type{}` struct (fields such as `type`/`kind`, `constraints`, `fields`, `inner_type`, `types`, `values`, `optional`, `nullable`, `default`, `annotations`, `transform`, `metadata`) is the immutable internal representation produced by every constructor. Constructors return new structs; wrapper functions (`optional/1`, `nullable/1`) return modified copies. Validation is stateless over `{Type, value}`.

- **Argument composition over pipes.** Constraints are keyword options to type constructors (`Schema.string(min: 3, max: 20)`, `Schema.list(Schema.string(), min: 1, unique: true)`), not pipe chains and not nested function composition. Single call site for type + constraints; idiomatic Elixir keyword args. Rejected: Effect-TS `.pipe()` style and `Schema.string(Schema.min(3))` nesting.

- **Exactly 4 core constraints.** `min` and `max` are polymorphic (numeric value vs string/list length); `pattern` applies to strings; `unique` applies to lists. All other validations are derivable. Convenience helpers `email/0`, `url/0`, `uuid/0` are plain functions returning predefined regexes, used via `pattern:` — they are not constraints. Rejected: the 14+ constraint set (bloated/redundant) and dropping `unique` (not otherwise expressible).

- **Field descriptors vs constraints separated.** `optional/1` (field may be missing) and `nullable/1` (value may be nil) are wrapper functions describing field presence; `default: value` is a keyword option on the type constructor. Keeps value-validation distinct from presence semantics and keeps the type definition in one place.

- **Struct syntax = keyword list of tuples.** `Schema.struct([{:name, Schema.string()}, {:age, Schema.integer(min: 0)}])`. Preserves field order (matters for serialization and error messages), supports dynamic construction via list concatenation, and avoids reserved-keyword conflicts. Rejected: map syntax (no order guarantee) and keyword-args form (reserved-word conflicts, no dynamic construction).

- **Literal type is variadic.** `Schema.literal(:pending, :approved, :rejected)` replaces `enum`, working with atoms, strings, or integers. Rejected: `enum([...])` (implies atoms only) and a `union` of literals (verbose).

- **Record type for dynamic-keyed maps.** `Schema.record(key_schema, value_schema)` validates both key and value types while allowing arbitrary runtime keys, distinct from `struct` with fixed keys.

- **Structured errors with paths.** Each error is a map `%{path: [...], message: ..., value: ..., constraint: ...}` where `path` is a list of atoms/integers locating the failure (e.g. `[:user, :addresses, 2, :zipcode]`). Mirrors Effect-TS structured errors.

- **Validation modes.** Default binary result `{:ok, parsed} | {:error, errors}`. Two error-collection modes via `mode:` — `:fail_fast` (default, single error) and `:all_errors` (list of all errors). Opt-in `partial: true` returns `{:ok, {successes, failures}}` for composites so valid fields are recoverable. `validate!/2` raises `Raggio.Schema.ValidationError`.

- **Bidirectional transforms and coercion.** Schema supports decode (parse-time) and encode (serialization-time) operations for round-trip transformation, transform composition (`abs`, `negate`), and explicit coercion builders (any → string/integer/float/decimal, handling currency strings and float-represented integers) applied before validation.

- **Syntax via protocol + plain structs.** `Raggio.Syntax.Node` protocol (`node_type/1`, `children/1`) over `Node`/`SchemaNode`/`FieldNode`/`TypeNode`/`SyntaxTree` structs; builders, traversal (depth-first, breadth-first, find/find_all), and transform/filter/replace are plain functions, avoiding macro-generated AST pattern matching.

- **Examples as documentation, automated.** Two-level `examples/[submodule]/[use_case]` hierarchy; `test/examples_test.exs` compiles and runs every example so broken examples fail CI. Inline docs limited to module-level purpose.

- **Migration classification.** Builders, parser, transformer, AST nodes, types, and the BigQuery exporter are migrated; SheetSchema DSL, Tabular adapter, and Excel transforms are deferred to Raggio.Tabular. The `old_code` is removed only after parity is verified (it was moved to `old_code/umbrella_apps`).

## Risks / Trade-offs

- **Clean break breaks existing callers.** No compatibility layer means any code on the old `DataSchema` API must be rewritten (e.g. `use DataSchema`/`@schema`/pipe builders → direct function calls and argument composition). Accepted per FR-013; mitigated by the migration analysis and worked old→new examples.
- **4-constraint minimalism shifts work to helpers.** Dropping built-ins like `email`/`url`/`uuid`/`range`/`min_length` means users compose them from `pattern`/`min`/`max`. Mitigated by shipping `email/0`, `url/0`, `uuid/0` helpers; remaining cases are expressible via the core set.
- **Polymorphic min/max ambiguity.** A single `min`/`max` meaning value-vs-length depending on type could surprise users. Mitigated by a documented semantics table and examples.
- **Adapter fidelity gaps.** BigQuery DDL cannot express `min`/`max`/`pattern` constraints (emitted as comments; only `required → NOT NULL` and `default → DEFAULT` map cleanly). SheetSchema import generates code that must still compile/validate. Mitigated by `validate_format/1` and the example test suite.
- **Examples-as-docs maintenance cost.** Relying on runnable examples instead of API docs requires the example test suite to stay green; stale examples fail CI by design, which is the intended guard.
- **Deferring Raggio.Tabular.** Real-world Excel/CSV parsing (a common use case) is postponed, so spreadsheet-data workflows are not yet served. Accepted scoping decision; the layered architecture leaves room to add it on top of `Raggio.Schema` later.
