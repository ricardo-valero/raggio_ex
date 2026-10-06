# Research: Drizzle-like Composable BigQuery API

**Feature**: 004-drizzle-bq-api  
**Date**: 2026-01-17

## Executive Summary

This research consolidates findings on API design patterns for a Drizzle-inspired, Effect-TS/Schema-influenced composable BigQuery schema API. The recommended approach combines:

1. **Function-based composition** (Drizzle pattern) - no classes/decorators
2. **Pipe-based refinement** (Effect-TS pattern) - chainable constraints
3. **NimbleParsec DDL parser** - formal grammar with good error messages
4. **Pure data structs** - leverage existing raggio.schema Type struct
5. **Canonical schema model** - raggio.schema.Type is THE portable format; adapters convert to/from it
6. **Behaviour-based adapters** - extensible pattern for future adapters (API, JSON-Schema)

---

## Decision 1: API Composition Style

### Decision: Hybrid Function + Struct Pattern

Combine Drizzle's function-based approach with Elixir's struct ergonomics.

### Rationale

- Drizzle uses plain objects created by factory functions - aligns well with Elixir structs
- Elixir's pipe operator naturally supports Effect-TS-style composition
- Existing raggio.schema already uses `%Type{}` structs - extend rather than replace

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Macro DSL (Ecto-style) | Clean syntax, compile-time checks | Magic-heavy, hard to compose dynamically | Rejected |
| Builder pattern with end markers | Explicit state | Verbose, error-prone | Rejected |
| Pure nested structs | Serializable, pattern-matchable | Less ergonomic for inline definition | Partial - use for data, add functions for ergonomics |
| Function pipeline | Familiar to Drizzle/Effect users | Needs careful design | **Selected** |

### Recommended API Pattern

```elixir
# Define project hierarchy using pipeable functions
import Raggio.BigQuery.Composer

project("my-gcp-project")
|> dataset("analytics")
|> table("events",
     schema: [
       column(:id, Schema.string() |> required()),
       column(:event_type, Schema.string()),
       column(:user_id, Schema.string()),
       column(:payload, Schema.struct([
         {:action, Schema.string()},
         {:metadata, Schema.record(Schema.string(), Schema.string())}
       ])),
       column(:created_at, Schema.datetime())
     ],
     partition_by: {:field, :created_at, :day},
     cluster_by: [:user_id, :event_type]
   )
|> table("users", schema: [...])
|> dataset("billing")
|> table("invoices", schema: [...])
|> build()
```

---

## Decision 2: Schema Composition Functions

### Decision: Extend raggio.schema with BigQuery-specific combinators

### Rationale

- Effect-TS/Schema uses `.pipe()` with filters/transforms - Elixir `|>` is identical
- Existing `Raggio.Schema` already has `optional/1`, `nullable/1` - extend this pattern
- Keep column-level modifiers separate from type-level modifiers

### New Functions to Add

```elixir
# Column mode modifiers (BigQuery-specific)
def required(type), do: %{type | metadata: Map.put(type.metadata, :mode, :required)}
def repeated(type), do: %{type | metadata: Map.put(type.metadata, :mode, :repeated)}

# Column metadata
def description(type, desc), do: %{type | metadata: Map.put(type.metadata, :description, desc)}

# Partitioning hint (stored in metadata, applied at table level)
def partition_by(type, granularity) when granularity in [:hour, :day, :month, :year],
  do: %{type | metadata: Map.put(type.metadata, :partition_by, granularity)}

# Type refinements (Effect-TS style)
def constrain(type, constraint_fn),
  do: %{type | constraints: type.constraints ++ [constraint_fn]}

def transform(type, decode_fn, encode_fn),
  do: %{type | metadata: Map.merge(type.metadata, %{decode: decode_fn, encode: encode_fn})}
```

---

## Decision 3: DDL Parser Implementation

### Decision: Use NimbleParsec for BigQuery DDL parsing

### Rationale

- Formal grammar → maintainable, extensible
- Position tracking → excellent error messages with line/column
- Recursive types (STRUCT, ARRAY) → `parsec/2` handles elegantly
- Compiled parser → fast performance
- Aligns with "declarative builder" philosophy from spec

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Regex/string matching | Simple to start | Fragile, poor errors, can't handle nesting | Rejected |
| Leex/Yecc (Erlang tools) | Mature, proven | Separate files, less Elixir-idiomatic | Rejected |
| NimbleParsec | Pure Elixir, combinators, compiled | Learning curve | **Selected** |

### Parser Structure

```elixir
defmodule Raggio.BigQuery.DDL.Parser do
  import NimbleParsec
  
  # Recursive type parser using defcombinatorp + parsec
  defcombinatorp :data_type, choice([
    simple_types(),      # STRING, INT64, BOOL, etc.
    array_type(),        # ARRAY<element_type>
    struct_type()        # STRUCT<field1 type1, ...>
  ])
  
  defcombinatorp :struct_type,
    ignore(string("STRUCT<"))
    |> concat(struct_fields())
    |> ignore(string(">"))
    |> tag(:struct)
  
  defcombinatorp :array_type,
    ignore(string("ARRAY<"))
    |> concat(parsec(:data_type))  # Recursion
    |> ignore(string(">"))
    |> tag(:array)
  
  defparsec :parse_create_table, create_table_statement()
end
```

### Error Message Pattern

```elixir
# Parser returns position info for errors
{:error, "expected data type", _rest, _context, {line, col_offset}, byte_offset}

# Transform to user-friendly message
"Parse error at line #{line}, column #{byte_offset - col_offset + 1}: expected data type"
```

---

## Decision 4: Integration with raggio.syntax

### Decision: Generate raggio.syntax AST from parsed DDL

### Rationale

- raggio.syntax already has `SchemaNode`, `FieldNode`, `TypeNode` structures
- Enables traversal, transformation, and analysis of parsed schemas
- Round-trip: DDL → Syntax AST → raggio.schema Type → DDL

### Integration Flow

```
BigQuery DDL String
        ↓
  NimbleParsec Parser
        ↓
  Raw Parse Tree [{:struct, [...]}, ...]
        ↓
  Transform to Raggio.Syntax AST
        ↓
  %SchemaNode{fields: [%FieldNode{...}, ...]}
        ↓
  Convert to Raggio.Schema.Type
        ↓
  %Type{kind: :struct, fields: [...]}
```

### Existing Patterns to Leverage

```elixir
# From raggio.syntax - AST construction
Syntax.schema(:events, [
  Syntax.field(:id, Syntax.type(:string)),
  Syntax.field(:payload, Syntax.type(:struct, [nested_fields]))
])

# From raggio.schema - Type construction  
Schema.struct([
  {:id, Schema.string()},
  {:payload, Schema.struct([{:action, Schema.string()}])}
])

# Existing BigQuery adapter (to extend)
Raggio.Schema.Adapters.BigQuery.to_ddl(schema, "table_name", opts)
```

---

## Decision 5: Project/Dataset/Table Hierarchy

### Decision: Implement as nested structs with builder functions

### Rationale

- Mirrors BigQuery's actual hierarchy (project → dataset → table)
- Enables qualified name generation: `project.dataset.table`
- Supports both inline definition and module-based definition

### Data Structures

```elixir
defmodule Raggio.BigQuery.Project do
  defstruct [:project_id, :datasets, :metadata]
  
  @type t :: %__MODULE__{
    project_id: String.t(),
    datasets: [Dataset.t()],
    metadata: map()
  }
end

defmodule Raggio.BigQuery.Dataset do
  defstruct [:name, :tables, :location, :metadata]
  
  @type t :: %__MODULE__{
    name: String.t(),
    tables: [Table.t()],
    location: String.t() | nil,
    metadata: map()
  }
end

# Extend existing Raggio.BigQuery.Table or create parallel struct
defmodule Raggio.BigQuery.TableDef do
  defstruct [:name, :schema, :partition_by, :cluster_by, :description, :metadata]
end
```

### Builder Context Pattern

```elixir
# Builder accumulates state during pipe chain
defmodule Raggio.BigQuery.Composer.Context do
  defstruct [
    :project_id,
    :current_dataset,
    datasets: %{},
    tables: []
  ]
end

def project(project_id) do
  %Context{project_id: project_id}
end

def dataset(%Context{} = ctx, name) do
  # Flush previous dataset's tables, start new dataset
  ctx
  |> flush_current_dataset()
  |> Map.put(:current_dataset, name)
end

def table(%Context{} = ctx, name, opts) do
  table_def = %TableDef{name: name, schema: opts[:schema], ...}
  update_in(ctx.tables, &[table_def | &1])
end

def build(%Context{} = ctx) do
  ctx
  |> flush_current_dataset()
  |> to_project_struct()
end
```

---

## Decision 6: Backward Compatibility

### Decision: New API coexists with existing `use Raggio.BigQuery.Table`

### Rationale

- Existing code using `use Raggio.BigQuery.Table` behaviour must continue working
- New composable API is additive, not replacing
- Migration path: convert Table modules to inline definitions if desired

### Compatibility Layer

```elixir
# Existing pattern (keep working)
defmodule MyApp.Tables.Events do
  use Raggio.BigQuery.Table
  
  @impl true
  def __dataset__, do: "analytics"
  
  @impl true  
  def __table__, do: "events"
  
  @impl true
  def __schema__ do
    Schema.struct([{:id, Schema.string()}])
  end
end

# New pattern (add this capability)
project = Raggio.BigQuery.Composer.from_modules([
  MyApp.Tables.Events,
  MyApp.Tables.Users
], project_id: "my-project")

# Or define inline
project = 
  project("my-project")
  |> dataset("analytics")
  |> table("events", schema: [...])
  |> build()
```

---

## Decision 7: Canonical Schema Model (Clarification Session)

### Decision: raggio.schema.Type is THE canonical, portable schema format

### Rationale

- Enables "define once, deploy anywhere" workflows
- BigQuery becomes one of many potential adapters (future: API, JSON-Schema)
- Schemas can be derived FROM BigQuery tables for use elsewhere
- Schemas can be converted TO BigQuery tables from any source

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| BigQuery-primary | Simple, BigQuery-specific | Can't reuse schemas for API endpoints | Rejected |
| Canonical raggio.schema | Portable, extensible | Requires adapter layer | **Selected** |
| Dual-source | Flexible | Complex, no single source of truth | Rejected |

### Implication

All adapter-specific schemas (BigQuery.TableDef, future OpenAPI, JSON-Schema) convert to/from `Raggio.Schema.Type`:

```elixir
# BigQuery → Canonical → API (future)
table_def = %BigQuery.TableDef{...}
canonical = Raggio.Schema.Adapters.BigQuery.to_schema(table_def)
# canonical can now be passed to any adapter's from_schema/1
```

---

## Decision 8: Adapter Architecture (Clarification Session)

### Decision: Use Elixir Behaviour for adapter extension point

### Rationale

- Idiomatic Elixir pattern for defining contracts
- Compile-time checking of required callbacks
- Aligns with existing raggio patterns (e.g., `Raggio.BigQuery.HTTPClient` behaviour)
- Clear documentation of what future adapters must implement

### Behaviour Definition

```elixir
defmodule Raggio.Schema.Adapter do
  @moduledoc """
  Behaviour for adapters that convert between raggio.schema.Type
  and adapter-specific formats.
  """
  
  @doc """
  Convert adapter-specific format to canonical raggio.schema.Type.
  Preserves adapter-specific metadata under namespaced keys.
  """
  @callback to_schema(adapter_format :: any()) :: Raggio.Schema.Type.t()
  
  @doc """
  Convert canonical raggio.schema.Type to adapter-specific format.
  Emits warnings for metadata from other adapters that cannot be mapped.
  """
  @callback from_schema(Raggio.Schema.Type.t()) :: {:ok, any()} | {:error, term()}
  
  @doc """
  Returns the namespace key used in Type.metadata for this adapter.
  """
  @callback adapter_namespace() :: atom()
end
```

### BigQuery Implementation

```elixir
defmodule Raggio.Schema.Adapters.BigQuery do
  @behaviour Raggio.Schema.Adapter
  
  @impl true
  def adapter_namespace, do: :bigquery
  
  @impl true
  def to_schema(%BigQuery.TableDef{} = table) do
    # Convert to Schema.Type, storing BigQuery-specific metadata
    %Type{
      kind: :struct,
      fields: convert_columns(table.columns),
      metadata: %{
        bigquery: %{
          partition_by: table.partition_by,
          cluster_by: table.cluster_by,
          table_name: table.name
        }
      }
    }
  end
  
  @impl true
  def from_schema(%Type{} = schema) do
    # Convert from Schema.Type, warn about unmapped foreign metadata
    warn_foreign_metadata(schema.metadata)
    {:ok, convert_to_table_def(schema)}
  end
end
```

---

## Decision 9: Adapter Metadata Handling (Clarification Session)

### Decision: Preserve metadata in Type.metadata under namespaced keys; warn on incompatible export

### Rationale

- Enables lossless round-trips (BigQuery → schema → BigQuery)
- Safe for cross-adapter use (schema → API warns about BigQuery partitioning)
- Namespacing prevents key collisions between adapters

### Metadata Structure

```elixir
%Type{
  kind: :struct,
  fields: [...],
  metadata: %{
    # BigQuery-specific (preserved from to_schema)
    bigquery: %{
      partition_by: {:field, :created_at, :day},
      cluster_by: [:user_id],
      description: "Events table"
    },
    # Future: API adapter metadata
    api: %{
      endpoint: "/events",
      method: :get
    },
    # Portable metadata (used by all adapters)
    description: "User events"
  }
}
```

### Warning Behavior

When `from_schema/1` is called:
1. Check for foreign adapter namespaces in metadata
2. For each foreign namespace with keys that can't be mapped:
   - Emit warning via Logger: "BigQuery adapter ignoring API metadata: [:endpoint, :method]"
3. Proceed with conversion, using only relevant metadata

```elixir
def warn_foreign_metadata(metadata) do
  foreign_adapters = Map.keys(metadata) -- [:bigquery, :description, :name]
  Enum.each(foreign_adapters, fn adapter ->
    keys = Map.keys(metadata[adapter])
    Logger.warning("BigQuery adapter ignoring #{adapter} metadata: #{inspect(keys)}")
  end)
end
```

---

## Implementation Priorities

Based on user stories from spec (updated with clarifications):

| Priority | Component | Dependency |
|----------|-----------|------------|
| P0 | Adapter behaviour definition | None (foundational) |
| P1 | Project/Dataset/TableDef/Column structs | None |
| P1 | Composer builder functions | Structs |
| P1 | BigQuery Adapter (to_schema/from_schema) | Adapter behaviour, Structs |
| P2 | DDL generation from Project | Structs, existing DDL module |
| P2 | Schema composition combinators | raggio.schema |
| P3 | NimbleParsec DDL parser | None (new module) |
| P3 | DDL → Syntax AST conversion | Parser, raggio.syntax |

**Note**: Adapter behaviour (P0) is foundational as it defines the contract for bidirectional schema conversion.

---

## Open Questions (Resolved)

| Question | Resolution |
|----------|------------|
| Should parser be bundled or optional? | Bundled - NimbleParsec is lightweight, DDL parsing is core feature |
| Case sensitivity in parser? | BigQuery keywords case-insensitive, identifiers in backticks preserve case |
| How to handle BigQuery OPTIONS()? | Parse as key-value map, store in metadata |
| Support views in initial release? | No - focus on tables only for MVP, views in future |

---

## Dependencies to Add

```elixir
# mix.exs
defp deps do
  [
    # Existing
    {:decimal, "~> 2.0"},
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.0"},
    
    # New - for DDL parsing
    {:nimble_parsec, "~> 1.4"}
  ]
end
```

---

## References

- [Drizzle ORM Documentation](https://orm.drizzle.team/docs/overview)
- [Effect-TS Schema Documentation](https://effect.website/docs/schema/introduction)
- [NimbleParsec HexDocs](https://hexdocs.pm/nimble_parsec/NimbleParsec.html)
- [BigQuery DDL Reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language)
