# Raggio — Agent Guide

Raggio is a single Elixir library (Ecto-style layout, **not** an umbrella) providing
composable data-schema definition, validation, and adjacent tooling.

## Submodules

| Module | Responsibility |
|---|---|
| `Raggio.Schema` | Composable schema definition + validation ("parse, don't validate"; Effect-TS/Schema-inspired; functions over macros). |
| `Raggio.Syntax` | Building and transforming syntax/AST trees. |
| `Raggio.Tabular` | CSV/XLSX/TSV parsing with schema-driven row parsing. |
| `Raggio.BigQuery` | BigQuery repo / migrations / DDL kit (with `mix raggio.bigquery.*` tasks). |
| `Raggio.Schema.Adapters` | Export/import adapters (BigQuery DDL, SheetSchema). |

## Commands

```bash
mix deps.get        # fetch dependencies
mix compile         # compile
mix test            # run the suite (ExUnit)
mix format          # format (see .formatter.exs)
mix credo           # static analysis (runs in CI on PRs)
```

Run an example:

```bash
mix run examples/schema/basic_validation/simple_schema.exs
```

A Nix dev shell is provided (`flake.nix`, auto-loaded via direnv / `.envrc`): Elixir,
`git`, `gh`, and tooling. `nix develop` if you don't use direnv.

## Conventions

- **Elixir `~> 1.14`** minimum.
- **Minimal runtime deps:** `decimal`, `jason`, `telemetry`. Parsing libraries
  (`nimble_csv`, an XLSX reader) are **dev/test-only** — the core bundles no parser
  (bring-your-own-parser); parser adapters live under `examples/`.
- **Prefer function composition and plain data over macros.** Schema constraints are
  keyword options on type constructors, e.g. `Schema.string(min: 3, max: 20)`. Keep the
  constraint set small and orthogonal (`min`, `max`, `pattern`, `unique`).
- **Validation contract:** `{:ok, parsed} | {:error, errors}`; errors are structured maps
  with `:path`, `:message`, `:value`, `:constraint`. Modes: `:fail_fast` (default),
  `:all_errors`, and `partial: true`.
- **Examples are primary documentation.** Working, compilable scripts under
  `examples/<submodule>/<use_case>` are exercised by `test/examples_test.exs`.

## Spec workflow

This project uses **OpenSpec** (it migrated off GitHub spec-kit / Specify).

- Active and archived changes: `openspec/changes/` (shipped 001/002/003 features are under
  `openspec/changes/archive/`).
- Living capability specs: `openspec/specs/` (`schema`, `syntax`, `schema-adapters`,
  `bigquery`, `tabular`).
- Project context for AI artifact generation: `openspec/config.yaml`.
- Useful: `openspec list`, `openspec list --specs`, `openspec validate <change>`.
