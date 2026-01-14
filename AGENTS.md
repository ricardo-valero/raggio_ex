# raggio_ex Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-12

## Active Technologies
- Elixir 1.14+ + None initially (both packages are foundational libraries with no external dependencies beyond Elixir stdlib) (001-monorepo-restructure)
- N/A (libraries for data validation and AST manipulation, not data storage) (001-monorepo-restructure)
- Elixir 1.14+ (minimum supported version per spec clarifications) + None initially (both packages are foundational libraries with no external dependencies beyond Elixir stdlib) (001-monorepo-restructure)
- N/A (libraries for data validation and syntax manipulation, not data storage) (001-monorepo-restructure)
- Elixir 1.14+ (minimum version for modern features with good ecosystem compatibility) + Decimal (precise numeric types), Jason (JSON encoding for BigQuery exporter), standard Elixir libraries (Date, DateTime, Regex) (001-monorepo-restructure)
- Elixir 1.14+ (minimum supported version per spec) + Decimal (precise numeric types), Jason (JSON encoding for BigQuery exporter), standard Elixir libraries (Date, DateTime, Regex) (001-monorepo-restructure)
- Elixir 1.14+ (minimum supported version per spec) + Decimal (precise numerics), Jason (JSON encoding for BigQuery exporter) (001-monorepo-restructure)
- N/A (library for data validation and syntax manipulation, not data storage) (001-monorepo-restructure)
- Elixir 1.14+ (per existing mix.exs) + Raggio.Schema (internal), Raggio.Syntax (internal), Decimal, Jason (existing deps) (002-bigquery-kit-migration)
- BigQuery (external service via adapters) - no local storage (002-bigquery-kit-migration)
- Elixir 1.14+ (per existing mix.exs) + Decimal ~> 2.0, Jason ~> 1.4, Telemetry ~> 1.0 (to add) (002-bigquery-kit-migration)
- Elixir `~> 1.14` (per `mix.exs`) + `decimal`, `jason`, `telemetry` (existing); add `nimble_csv` for CSV parsing; add one XLSX reader (`xlsx_reader` or `spreadsheet`) (003-sheet-adapter)

- Elixir 1.14+ (compatible with current Elixir ecosystem) + None initially (both package are foundational library with no external dependency beyond Elixir stdlib) (001-monorepo-restructure)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Elixir 1.14+ (compatible with current Elixir ecosystem)

## Code Style

Elixir 1.14+ (compatible with current Elixir ecosystem): Follow standard conventions

## Recent Changes
- 003-sheet-adapter: Added Elixir `~> 1.14` (per `mix.exs`) + `decimal`, `jason`, `telemetry` (existing); add `nimble_csv` for CSV parsing; add one XLSX reader (`xlsx_reader` or `spreadsheet`)
- 002-bigquery-kit-migration: Added Elixir 1.14+ (per existing mix.exs) + Decimal ~> 2.0, Jason ~> 1.4, Telemetry ~> 1.0 (to add)
- 002-bigquery-kit-migration: Added Elixir 1.14+ (per existing mix.exs) + Raggio.Schema (internal), Raggio.Syntax (internal), Decimal, Jason (existing deps)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
