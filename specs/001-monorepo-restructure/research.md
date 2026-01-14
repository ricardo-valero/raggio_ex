# Research: Single-Package Restructure (Ecto-style)

**Date**: 2026-01-13  
**Feature**: 001-monorepo-restructure  
**Updated**: Phase 0 research completed with Effect-TS/Schema patterns and Ecto structure analysis

## API Design Decisions

### 1. Constraint Syntax Style

**Decision**: Argument composition - constraints as keyword options to type constructors

**Rationale**: 
- Concise, declarative syntax without pipe chains
- Natural Elixir idiom (keyword arguments)
- Single call site for type + constraints
- Aligns with user preference over Effect-TS pipe style

**Alternatives Considered**:
- Pipe composition (`Schema.string() |> Schema.min(3)`) - rejected: more verbose, Effect-TS style not preferred
- Nested function composition (`Schema.string(Schema.min(3))`) - rejected: confusing nesting, not Elixir-idiomatic

**Examples**:
```elixir
# Approved syntax
Schema.string(min: 3, max: 20)
Schema.integer(min: 0, default: 0)
Schema.list(Schema.string(), min: 1, unique: true)
```

### 2. Core Constraint Set

**Decision**: 4 core constraints only: `min`, `max`, `pattern`, `unique`

**Rationale**:
- Minimal, orthogonal constraint set
- Polymorphic min/max reduces API surface (works on numbers, strings, lists)
- All other validations derivable from these 4
- Convenience helpers (email, url, uuid) can be functions returning pattern()

**Alternatives Considered**:
- 14+ constraints (current implementation) - rejected: bloated, redundant
- 3 constraints (drop unique) - rejected: unique not expressible via other constraints

**Constraint Semantics**:
| Constraint | Numbers | Strings | Lists |
|------------|---------|---------|-------|
| `min: n` | value >= n | length >= n | length >= n |
| `max: n` | value <= n | length <= n | length <= n |
| `pattern: regex` | N/A | must match | N/A |
| `unique: true` | N/A | N/A | no duplicates |

### 3. Field Descriptors vs Constraints

**Decision**: Separate concepts - optional()/nullable() are wrapper functions, default: is keyword option

**Rationale**:
- Constraints validate values; field descriptors describe field presence
- Wrapper functions compose naturally: `Schema.optional(Schema.string(min: 1))`
- default: as keyword option keeps type definition in one place

**Alternatives Considered**:
- All as keyword options - rejected: conflates value validation with presence semantics
- All as wrapper functions - rejected: default(schema, value) awkward vs `default: value`

**Examples**:
```elixir
Schema.struct([
  {:name, Schema.string(min: 1)},                      # required
  {:bio, Schema.optional(Schema.string())},            # can be missing
  {:middle_name, Schema.nullable(Schema.string())},    # can be nil
  {:age, Schema.integer(min: 0, default: 0)}           # has default
])
```

### 4. Struct Definition Syntax

**Decision**: Keyword list of tuples - `Schema.struct([{:name, Schema.string()}, ...])`

**Rationale**:
- Preserves field order (important for serialization, error messages)
- Supports dynamic field construction via list concatenation
- No reserved keyword conflicts
- Handles large structs cleanly

**Alternatives Considered**:
- Map syntax `%{name: Schema.string()}` - rejected: no order guarantee
- Keyword args `Schema.struct(name: Schema.string())` - rejected: reserved word conflicts, no dynamic construction

### 5. Literal/Enum Type

**Decision**: `Schema.literal(:a, :b, :c)` - variadic arguments

**Rationale**:
- Clean syntax for defining allowed values
- Works with any literal types (atoms, strings, integers)
- Variadic more natural than list argument

**Alternatives Considered**:
- `Schema.enum([:a, :b, :c])` - rejected: enum implies atoms only
- `Schema.union([Schema.literal(:a), ...])` - rejected: verbose

### 6. Package Dependency Structure

**Decision**: Layered architecture with one-way dependencies

**Rationale**:
- Raggio.Schema is foundational (no dependencies on other Raggio packages)
- Raggio.Syntax may depend on Raggio.Schema
- Raggio.Tabular depends on Raggio.Schema
- Prevents circular dependencies

```
┌─────────────────┐     ┌─────────────────┐
│ Raggio.Tabular  │     │ Raggio.Syntax   │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │    depends on         │
         ▼                       ▼
┌─────────────────────────────────────────┐
│            Raggio.Schema                │
│         (no external Raggio deps)       │
└─────────────────────────────────────────┘
```

## Type System Design

### Primitive Types

| Type | Constructor | Constraints | Default |
|------|-------------|-------------|---------|
| String | `Schema.string()` | min, max, pattern | N/A |
| Integer | `Schema.integer()` | min, max | N/A |
| Float | `Schema.float()` | min, max | N/A |
| Boolean | `Schema.boolean()` | N/A | N/A |
| Decimal | `Schema.decimal()` | min, max | N/A |
| Date | `Schema.date()` | N/A | N/A |
| DateTime | `Schema.datetime()` | N/A | N/A |
| Atom | `Schema.atom()` | N/A | N/A |

### Composite Types

| Type | Constructor | Constraints |
|------|-------------|-------------|
| Struct | `Schema.struct([{:field, schema}, ...])` | N/A |
| List | `Schema.list(inner_schema)` | min, max, unique |
| Tuple | `Schema.tuple([schema1, schema2, ...])` | N/A |
| Record | `Schema.record(key_schema, value_schema)` | N/A |
| Union | `Schema.union([schema1, schema2, ...])` | N/A |
| Literal | `Schema.literal(value1, value2, ...)` | N/A |

### Field Descriptors

| Descriptor | Function | Effect |
|------------|----------|--------|
| Optional | `Schema.optional(schema)` | Field can be missing from struct |
| Nullable | `Schema.nullable(schema)` | Field value can be nil |
| Default | `schema(default: value)` | Use value when field is nil/missing |

## Validation Behavior

### Error Structure

```elixir
%{
  path: [:user, :address, :zip],  # Location of error
  message: "minimum length is 5", # Human-readable description
  value: "123",                   # The invalid value
  constraint: :min                # Which constraint failed
}
```

### Validation Modes

| Mode | Option | Behavior |
|------|--------|----------|
| Fail-fast | `mode: :fail_fast` (default) | Stop at first error |
| All errors | `mode: :all_errors` | Collect all errors |
| Partial | `partial: true` | Return `{successes, failures}` |

## Convenience Helpers

These are NOT constraints - they return pattern() with predefined regex:

```elixir
def email, do: pattern(~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/)
def url, do: pattern(~r/^https?:\/\/.+/)
def uuid, do: pattern(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
```

Usage:
```elixir
Schema.string(pattern: Schema.email())
Schema.string(pattern: Schema.uuid())
```

## Open Questions (Resolved)

All NEEDS CLARIFICATION items from spec have been resolved through clarification sessions.

---

## External Research Findings

### Effect-TS/Schema API Patterns

**Source**: Effect-TS/Schema library documentation and real-world usage

**Key Findings**:

1. **Type Constructors**: Effect-TS uses values, not factory functions (`Schema.String` not `Schema.String()`). Raggio will use functions (`Schema.string()`) - more idiomatic Elixir.

2. **Constraint Chaining**: Effect-TS uses `.pipe()` for constraints:
   ```typescript
   Schema.String.pipe(Schema.minLength(1)).pipe(Schema.maxLength(200))
   ```
   **Raggio Decision**: Inline keyword options instead: `Schema.string(min: 1, max: 200)`

3. **Struct Definition**:
   ```typescript
   Schema.Struct({ name: Schema.String, age: Schema.Number })
   ```
   **Raggio Equivalent**: `Schema.struct([{:name, Schema.string()}, {:age, Schema.integer()}])`

4. **Error Structure**: Effect-TS provides structured errors with paths:
   ```typescript
   { path: ["user", "email"], message: "...", actual: "invalid" }
   ```
   **Raggio Match**: `%{path: [:user, :email], message: "...", value: "invalid"}`

5. **"Parse, Don't Validate"**: Effect-TS returns `Either<ParseError, Type>`, not booleans. Decoding transforms input into typed output with branded types.
   **Raggio Adoption**: `{:ok, parsed} | {:error, errors}` - data is transformed, not just validated

6. **Bidirectional Transforms**: Effect-TS supports both `decode` (input→output) and `encode` (output→input).
   **Raggio Match**: FR-025 requires decode/encode operations

### Ecto Package Structure

**Source**: elixir-ecto/ecto repository analysis

**Key Findings**:

1. **Single Package with Submodules**: Ecto is one package containing:
   - `Ecto` (root module - documentation + utilities)
   - `Ecto.Schema` (macro-based schema definition)
   - `Ecto.Changeset` (validation & casting)
   - `Ecto.Query` (query DSL)
   - `Ecto.Repo` (repository behavior)

2. **File Structure Pattern**:
   ```
   lib/
     ecto.ex                 # Root module (minimal - docs + utilities)
     ecto/
       schema.ex             # Submodule entry point
       schema/               # Internal implementation
         loader.ex
         metadata.ex
       changeset.ex          # Another submodule
       changeset/            # Its internals
   ```

3. **mix.exs Configuration** (key elements):
   ```elixir
   def project do
     [
       app: :raggio,
       version: "0.1.0",
       elixir: "~> 1.14",
       deps: deps(),
       elixirc_paths: elixirc_paths(Mix.env()),
       consolidate_protocols: Mix.env() != :test
     ]
   end
   
   defp elixirc_paths(:test), do: ["lib", "test/support"]
   defp elixirc_paths(_), do: ["lib"]
   ```

4. **Entry Point Pattern**: Each submodule can have a `__using__/1` macro for importing its API, but Raggio will minimize macros per FR-007.

**Raggio Structure Decision**:
```
lib/
  raggio.ex                    # Root (minimal - version, config)
  raggio/
    schema.ex                  # Raggio.Schema entry point
    schema/
      type.ex                  # Type struct
      types/                   # Type constructors
      validator.ex             # Validation logic
      adapters/                # BigQuery, SheetSchema
    syntax.ex                  # Raggio.Syntax entry point
    syntax/
      node.ex                  # Syntax node struct
      builder.ex               # Node builders
```

### old_code/data_schema Migration Analysis

**Files Analyzed**: 41 Elixir files in old_code/data_schema

**Migration Status**:

| Component | Files | Status | Target |
|-----------|-------|--------|--------|
| Builders (type constructors) | 1 (890 lines) | MIGRATE | Raggio.Schema |
| Parser | 1 | MIGRATE | Raggio.Schema.Validator |
| Transformer | 1 | MIGRATE | Raggio.Schema.Validator |
| AST nodes | 12 | MIGRATE | Raggio.Syntax |
| Types | 8 | MIGRATE | Raggio.Schema.Type |
| BigQuery exporter | 1 | MIGRATE | Raggio.Schema.Adapters.BigQuery |
| SheetSchema | 5 | DEFER | Raggio.Tabular |
| Tabular adapter | 1 | DEFER | Raggio.Tabular |
| Excel transforms | 1 | DEFER | Raggio.Tabular |

**API Changes (old → new)**:
```elixir
# OLD: Pipe-based builders
import DataSchema.Builders
tuple(
  name: string() |> min(1) |> max(100),
  age: integer() |> optional()
)

# NEW: Argument composition
alias Raggio.Schema
Schema.struct([
  {:name, Schema.string(min: 1, max: 100)},
  {:age, Schema.optional(Schema.integer())}
])
```

**Breaking Changes**:
- `use DataSchema` macro pattern → removed (direct function calls)
- `@schema` attribute pattern → removed
- `tuple()` for structs → `Schema.struct()`
- Positional `tuple()` stays for fixed-size tuples
- `literal([...])` with list → `literal(...)` variadic
