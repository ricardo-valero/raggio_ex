# Research: Multi-Package Monorepo Restructure

**Date**: 2026-01-13  
**Feature**: 001-monorepo-restructure

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
