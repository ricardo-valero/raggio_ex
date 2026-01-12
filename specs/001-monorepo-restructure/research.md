# Research Findings: Multi-Package Monorepo Restructure

**Date**: 2026-01-12  
**Feature**: Multi-Package Monorepo Restructure  
**Branch**: `001-monorepo-restructure`

This document consolidates research findings from Phase 0 of the implementation plan, resolving all technical unknowns identified in the planning phase.

---

## 1. Effect-TS/Schema API Patterns

### Decision
Adopt Effect-TS/Schema's **pipe-based constraint composition pattern** adapted for Elixir's native pipe operator.

### Rationale
Effect-TS/Schema's constraint composition leverages TypeScript's method chaining which maps naturally to Elixir's pipe operator. This enables readable constraint composition like `Schema.string() |> Schema.min(3) |> Schema.max(5)` while preserving builder/validator separation and maintaining Elixir's functional idioms.

### Key Patterns Identified

**1. Builder-Validator Separation**
- Base type constructors: `Schema.string()`, `Schema.integer()`
- Separate constraint functions: `min/1`, `max/1`, `pattern/1`
- Constraints modify schema without changing core type

**2. Pipe-Based Composition**
- Constraints compose via pipe operator: `|>`
- Each constraint function returns transformed schema
- Natural reading order: base type → constraint 1 → constraint 2

**3. Immutable Schema Values**
- Schemas are immutable structs
- Each constraint application returns new schema
- Enables safe composition without mutation

**4. Structured Validation Results**
- Returns `{:ok, parsed_data}` or `{:error, issues}`
- Errors include `path`, `message`, and `value` fields
- Supports collecting all errors or fail-fast mode

**5. Annotation-Based Metadata**
- Constraints carry metadata (descriptions, custom messages)
- Used for error messages and documentation generation
- Stored in schema struct alongside filters

### Implementation Approach for Raggio.Schema

```elixir
# Core schema struct
%Raggio.Schema{
  type: :string,           # Base type
  encoded: :string,        # Wire format
  filters: [              # Constraint list
    {:min_length, 3},
    {:max_length, 50}
  ],
  annotations: %{         # Metadata
    description: "Username",
    message: "Invalid username format"
  }
}

# Constraint functions return schema transformers
def min_length(length) do
  fn schema ->
    %{schema | filters: [{:min_length, length} | schema.filters]}
  end
end

# Usage via pipes
Schema.string()
|> Schema.min_length(3)
|> Schema.max_length(50)
|> Schema.pattern(~r/^[a-z0-9_]+$/)
```

### Alternatives Considered

**Nested Function Calls**: `Schema.string(Schema.min(3, Schema.max(5)))`
- **Rejected**: Inverts natural reading order, creates deep nesting

**Keyword List Arguments**: `Schema.string(min: 3, max: 5)`
- **Rejected**: Violates single responsibility, doesn't scale for complex compositions

**Macro-Based DSL**: `defschema [username: string() |> min(3)]`
- **Rejected**: Adds complexity, hides composition mechanics, harder to debug

---

## 2. Elixir Umbrella Project Structure

### Decision
Use **Elixir umbrella monorepo** structure for this specific project (not separate repositories).

### Rationale
While Ecto/Phoenix ecosystem packages are maintained as separate repositories for independent library distribution, this restructure explicitly requests "repository in the same style as ecto and phoenix where we have several packages" stored together. The umbrella pattern provides:
- Unified development workflow for related packages
- Shared tooling and configuration
- Simplified local development and testing
- Single repository for both packages per user requirements

### Key Umbrella Conventions

**Directory Structure**:
```
/
├── mix.exs              # Umbrella project definition
├── config/
│   ├── config.exs       # Shared configuration
│   └── test.exs
├── apps/
│   ├── raggio_schema/   # Package 1
│   │   ├── mix.exs
│   │   ├── lib/
│   │   └── test/
│   └── raggio_syntax/   # Package 2
│       ├── mix.exs
│       ├── lib/
│       └── test/
├── examples/            # Shared examples at root
└── test/               # Cross-package integration tests
```

**Dependency Management**:
```elixir
# In apps/raggio_syntax/mix.exs
defp deps do
  [
    {:raggio_schema, in_umbrella: true},  # Umbrella dependency
    # other deps...
  ]
end
```

**Testing Strategy**:
- Each app has own `test/` directory for unit tests
- Root-level `test/` for integration tests across packages
- `mix test` from root runs all tests
- `mix test` from app directory runs only that app's tests

### Umbrella Project Configuration

**Root mix.exs**:
```elixir
defmodule Raggio.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      test: ["test --cover"],
      "format.all": ["format", "cmd mix format"]
    ]
  end
end
```

### Implementation Notes
- Each package maintains independent version numbers
- Packages can be published to Hex independently later
- Shared configuration in root `config/` directory
- Examples at root level for easy access
- No circular dependencies enforced at package level

---

## 3. BigQuery DDL Generation

### Decision
Generate **BigQuery Standard SQL DDL** using CREATE TABLE statements with explicit column definitions, type specifications, and mode constraints.

### Rationale
BigQuery Standard SQL DDL supports strongly-typed columns, nested STRUCT types, ARRAY types, and column modes (NULLABLE/REQUIRED). This aligns well with Raggio.Schema's structured type definitions and validation rules.

### Type Mappings

| Raggio Type | BigQuery Type | Notes |
|-------------|---------------|-------|
| string      | STRING        | Variable-length character data |
| integer     | INT64         | 64-bit signed integer |
| decimal     | NUMERIC       | Exact decimal (38 digits precision) |
| float       | FLOAT64       | 64-bit floating point |
| boolean     | BOOL          | TRUE/FALSE values |
| datetime    | DATETIME      | Calendar date and time (no timezone) |
| timestamp   | TIMESTAMP     | Absolute point in time (with timezone) |
| date        | DATE          | Calendar date only |
| time        | TIME          | Time of day only |
| binary      | BYTES         | Variable-length binary data |
| json        | JSON          | Native JSON type |

### DDL Template

```sql
CREATE TABLE `project.dataset.table_name` (
  id INT64 NOT NULL,
  name STRING NOT NULL,
  email STRING,
  tags ARRAY<STRING>,
  address STRUCT<
    street STRING,
    city STRING NOT NULL,
    geo STRUCT<
      lat FLOAT64,
      lng FLOAT64
    >
  >
)
PARTITION BY DATE(created_at)
CLUSTER BY id;
```

### Nested Structure Handling

**STRUCT Syntax**:
```sql
-- Simple nested structure
address STRUCT<
  street STRING,
  city STRING NOT NULL
>

-- Deeply nested
location STRUCT<
  address STRUCT<
    geo STRUCT<
      lat FLOAT64,
      lng FLOAT64
    >
  >
>
```

**ARRAY Syntax**:
```sql
-- Array of primitives
tags ARRAY<STRING>

-- Array of structs
orders ARRAY<STRUCT<
  id INT64 NOT NULL,
  amount NUMERIC NOT NULL
>>
```

### Constraint Mapping

| Raggio Constraint | BigQuery Representation | Support Level |
|-------------------|-------------------------|---------------|
| required=true     | `NOT NULL` column mode  | Full support |
| required=false    | Default (nullable)      | Full support |
| default value     | `DEFAULT value`         | Full support |
| min/max           | Not supported           | Document in comments |
| pattern           | Not supported           | Document in comments |

### Implementation Strategy

**Code Generation Approach**:
```elixir
defmodule Raggio.Schema.Exporter.BigQuery do
  def to_ddl(schema, table_name, opts \\ []) do
    columns = generate_columns(schema)
    clauses = generate_clauses(opts)
    
    """
    CREATE TABLE `#{table_name}` (
    #{columns}
    )#{clauses}
    """
  end
  
  defp map_type({:struct, fields}) do
    field_defs = Enum.map(fields, fn {name, spec} ->
      type = map_type(spec.type)
      mode = if spec.required, do: " NOT NULL", else: ""
      "  #{name} #{type}#{mode}"
    end)
    
    "STRUCT<\n#{Enum.join(field_defs, ",\n")}\n>"
  end
  
  defp map_type({:array, inner_type}) do
    "ARRAY<#{map_type(inner_type)}>"
  end
  
  defp map_type(:string), do: "STRING"
  defp map_type(:integer), do: "INT64"
  # ... other mappings
end
```

---

## 4. Functional Composition Patterns

### Decision
**Pipe-First Design + Higher-Order Functions + Protocol-Based Extension**

### Rationale
This combination provides maximum composability through Elixir's native pipe operator, enables flexible composition through functions that return functions, and allows extensibility via protocols without requiring users to write macros. Satisfies the "90% of use cases without macros" requirement.

### Core Patterns

**Pattern 1: Pipe-First Data Pipeline**
```elixir
# Natural Elixir style
schema =
  Schema.new()
  |> Schema.field(:name, :string)
  |> Schema.field(:age, :integer)
  |> Schema.constraint(:age, &(&1 > 0))
```

**Pattern 2: Higher-Order Function Builders**
```elixir
# Constraint builders return functions
defmodule Constraints do
  def min(value), do: fn x -> x >= value end
  def max(value), do: fn x -> x <= value end
  def range(min, max), do: fn x -> x >= min and x <= max end
end

# Usage
Schema.field(:age, :integer, Constraints.range(0, 120))
```

**Pattern 3: Combinator Pattern**
```elixir
# Combining validators
defmodule Combinators do
  def all(validators) do
    fn value ->
      Enum.reduce_while(validators, :ok, fn validator, :ok ->
        case validator.(value) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end
end

# Usage
age_validator = Combinators.all([
  Constraints.min(0),
  Constraints.max(120)
])
```

**Pattern 4: Protocol-Based Extension**
```elixir
# Define protocol for custom constraints
defprotocol Raggio.Schema.Constraint do
  def validate(constraint, value)
  def error_message(constraint)
end

# Users extend without modifying library
defmodule EmailConstraint do
  defstruct [:domain]
end

defimpl Raggio.Schema.Constraint, for: EmailConstraint do
  def validate(%{domain: d}, value) do
    if String.ends_with?(value, "@#{d}"), do: :ok, else: :error
  end
  def error_message(%{domain: d}), do: "must be @#{d}"
end
```

### Trade-offs Analysis

| Pattern | Pros | Cons | Use When |
|---------|------|------|----------|
| Pipe-First | Natural Elixir, easy to read | Requires data-first arg | Always (default) |
| Higher-Order Functions | Flexible, composable | Harder to debug closures | Building reusable constraints |
| Combinators | Powerful composition | Learning curve | Complex validation logic |
| Protocols | Type-safe extension | Requires struct definitions | Advanced extensions |

### Implementation for Both Packages

**Raggio.Schema**:
- Core module with struct for field/constraint accumulation
- Pipe-first builder functions
- `Constraints` module with common builders
- `Combinators` module for composition
- `Raggio.Schema.Constraint` protocol

**Raggio.Syntax**:
- Core module with struct for transform accumulation
- Pipe-first transform registration
- `Transformers` module with common patterns
- `Combinators` for chaining transformers
- `Raggio.Syntax.Transformer` protocol (optional)

---

## 5. SheetSchema Format Definition

### Decision
Define **SheetSchema** as a custom spreadsheet format with columns: `[field_name, type, required, constraints, description, example, default, parent_path]`

### Rationale
No existing standard adequately addresses Elixir schema generation with composable validation. SheetSchema is purpose-built for Raggio.Schema's pipe-based API while remaining accessible to non-technical stakeholders.

### Column Definitions

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| field_name | string | yes | Field identifier (snake_case) |
| type | string | yes | Elixir type or complex type expression |
| required | boolean | no | Whether field must be present (default: false) |
| constraints | string | no | Pipe-separated validation functions |
| description | string | no | Human-readable documentation |
| example | string | no | Sample valid value |
| default | string | no | Default value if not provided |
| parent_path | string | no | Dot-notation path for nesting |

### Constraint Syntax

Constraints use Raggio.Schema function notation separated by pipes, matching code:

```
min_length(3) | max_length(50) | pattern(^[a-z]+$)
one_of(["active", "inactive", "suspended"])
positive() | even()
email()
```

**Common Constraints**:
- String: `min_length/1`, `max_length/1`, `pattern/1`, `email/0`, `url/0`, `uuid/0`
- Number: `min/1`, `max/1`, `positive/0`, `negative/0`, `even/0`, `odd/0`
- Collection: `min_items/1`, `max_items/1`, `unique/0`
- Universal: `one_of/1`, `custom/2`

### Type Syntax

**Primitives**: `string`, `integer`, `float`, `boolean`, `atom`, `date`, `datetime`, `time`

**Complex Types**:
- `list(type)` - homogeneous list
- `map` - key-value map (fields via parent_path)
- `tuple(type1, type2)` - fixed-length tuple
- `union(type1, type2)` - one of multiple types
- `nullable(type)` - type or nil

### Example Sheet

| field_name | type | required | constraints | description | example | default | parent_path |
|------------|------|----------|-------------|-------------|---------|---------|-------------|
| id | integer | yes | positive() | Unique identifier | 12345 | | |
| email | string | yes | email() \| max_length(255) | Email address | alice@example.com | | |
| username | string | yes | min_length(3) \| max_length(30) \| pattern(^[a-z0-9_]+$) | Login username | alice_j | | |
| age | integer | no | min(13) \| max(120) | Age in years | 28 | | |
| street | string | no | max_length(100) | Street address | 123 Main St | | address |
| city | string | no | max_length(50) | City name | Portland | | address |
| latitude | float | no | min(-90) \| max(90) | Latitude | 45.5231 | | address.geo |
| longitude | float | no | min(-180) \| max(180) | Longitude | -122.6765 | | address.geo |

### Nested Structure Representation

Use `parent_path` column with dot notation:
- Empty = top-level field
- `address` = nested in `address` map
- `address.geo` = nested in `geo` map inside `address`

**Generated Code Example**:
```elixir
Raggio.Schema.struct([
  {:id, Raggio.Schema.integer() |> Raggio.Schema.positive()},
  {:email, Raggio.Schema.string() |> Raggio.Schema.email() |> Raggio.Schema.max_length(255)},
  {:username, Raggio.Schema.string() 
    |> Raggio.Schema.min_length(3) 
    |> Raggio.Schema.max_length(30) 
    |> Raggio.Schema.pattern(~r/^[a-z0-9_]+$/)},
  {:age, Raggio.Schema.integer() 
    |> Raggio.Schema.min(13) 
    |> Raggio.Schema.max(120) 
    |> Raggio.Schema.optional()},
  {:address, Raggio.Schema.struct([
    {:street, Raggio.Schema.string() |> Raggio.Schema.max_length(100) |> Raggio.Schema.optional()},
    {:city, Raggio.Schema.string() |> Raggio.Schema.max_length(50) |> Raggio.Schema.optional()},
    {:geo, Raggio.Schema.struct([
      {:latitude, Raggio.Schema.float() |> Raggio.Schema.min(-90) |> Raggio.Schema.max(90) |> Raggio.Schema.optional()},
      {:longitude, Raggio.Schema.float() |> Raggio.Schema.min(-180) |> Raggio.Schema.max(180) |> Raggio.Schema.optional()}
    ]) |> Raggio.Schema.optional()}
  ]) |> Raggio.Schema.optional()}
])
```

### Implementation Considerations

**Parser Requirements**:
1. CSV/TSV reading with `NimbleCSV`
2. Type parsing with regex for complex types
3. Constraint parsing: split on `|`, parse function calls
4. Nesting resolution: build path tree, construct bottom-up
5. Boolean parsing: accept `true/false/yes/no/1/0` (case-insensitive)
6. Code generation via Raggio.Syntax for correctness
7. Validation: duplicate fields, required columns, type syntax, circular nesting
8. Error handling: row-level errors, collect all before failing

**Google Sheets Integration**:
- Google Sheets API v4 for direct import
- Support sharing link format
- Handle multiple sheets (specify name or use first)
- Cache with TTL for repeated imports

---

## Summary of Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| **API Pattern** | Pipe-based composition like Effect-TS | Natural Elixir idiom, readable, composable |
| **Project Structure** | Elixir umbrella monorepo | Matches user requirements, unified development |
| **BigQuery Export** | Standard SQL DDL with STRUCT/ARRAY | Full BigQuery compatibility, supports nesting |
| **Composition Style** | Pipe-first + Higher-order functions + Protocols | 90% cases without macros, extensible |
| **SheetSchema Format** | Custom format with 8 columns | User-friendly, parseable, maps to Raggio.Schema API |

---

## Next Steps

1. ✅ Phase 0 Research - Complete
2. ⏳ Phase 1 Design: Create data-model.md, contracts/, quickstart.md
3. ⏳ Update agent context with new technologies
4. ⏳ Phase 2: Generate tasks.md via `/speckit.tasks`

---

*Research phase complete. All technical unknowns resolved. Ready for Phase 1 design artifacts.*
