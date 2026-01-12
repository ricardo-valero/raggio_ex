# Research: Multi-Package Monorepo Restructure

**Date**: 2026-01-12  
**Status**: Complete  
**Purpose**: Resolve technical unknowns and establish API design pattern for Raggio.Schema and Raggio.Syntax

---

## 1. Effect-TS/Schema API Pattern Analysis

### Decision
Adopt **pipe-first composition** with **combinator function** and **structured error accumulation** pattern inspired by Effect-TS/Schema.

### Rationale
Effect-TS/Schema demonstrates a proven approach for building composable, type-safe API that prioritize developer experience:

1. **Pipe-first composition**: Natural left-to-right reading flow matches Elixir's `|>` operator perfectly
2. **Combinator function**: Higher-order function that compose schema (e.g., `compose`, `array`, `struct`) provide clean composition without macro
3. **Structured error**: Tree-structured error with path information make debugging easier
4. **Data-last function signature**: All function accept data as last argument, enabling pipeline composition

### Key Pattern Transferable to Elixir

**Composition through pipe operator**:
```elixir
# Effect-TS pattern
pipe(input, Schema.string(), Schema.minLength(5), Schema.maxLength(50))

# Elixir equivalent
"input"
|> Raggio.Schema.string()
|> Raggio.Schema.min_length(5)
|> Raggio.Schema.max_length(50)
```

**Structural composition with combinator**:
```elixir
# Combine schema using combinator function
Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer() |> Raggio.Schema.positive()},
  {:email, Raggio.Schema.string() |> Raggio.Schema.email()}
])
```

**Error accumulation**:
```elixir
# Validation return structured error with path
{:error, [
  %{path: [:user, :email], message: "invalid email format"},
  %{path: [:user, :age], message: "must be positive integer"}
]}
```

**Separation of schema definition from execution**:
```elixir
# Schema are data structure describing validation
user_schema = Raggio.Schema.struct([...])

# Execution happen separately
Raggio.Schema.validate(user_schema, data)
```

### Alternative Considered
- **Macro-based DSL** (like Ecto.Schema): Rejected because spec requires minimal macro (FR-007)
- **Protocol-based composition**: Rejected because function composition is more explicit and easier to debug
- **Behaviour-based**: Rejected because it adds unnecessary complexity for this use case

---

## 2. Elixir Umbrella Structure

### Decision
Use **Elixir umbrella project** structure for monorepo, but keep package **independently publishable** similar to Ecto/Phoenix approach.

### Rationale
Research shows that Ecto and Phoenix actually prefer **multi-repo over umbrella** for publishable package. However, for this project, umbrella structure provide benefit:

1. **Unified development experience**: All package in one repository simplify development workflow
2. **Shared tooling**: Mix task, formatter, and CI configuration can be shared
3. **Independent publishing**: Each app in umbrella can still be published to Hex independently
4. **Clear dependency management**: Path dependency during development, proper version in production

The key insight: Umbrella project work well when package are tightly related but independently useful (Raggio.Schema and Raggio.Syntax fit this pattern).

### Concrete Structure

```elixir
# Root mix.exs (umbrella)
defmodule Raggio.MixProject do
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
    []  # Umbrella level dependency (if any)
  end

  defp aliases do
    [
      "test.all": ["test", "cmd --app raggio_schema mix test", "cmd --app raggio_syntax mix test"],
      "format.all": ["format", "cmd --app raggio_schema mix format", "cmd --app raggio_syntax mix format"]
    ]
  end
end

# Package mix.exs (apps/raggio_schema/mix.exs)
defmodule RaggioSchema.MixProject do
  use Mix.Project

  def project do
    [
      app: :raggio_schema,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      
      # Publishing configuration
      description: "Composable schema definition and validation library",
      package: package(),
      name: "Raggio.Schema",
      source_url: "https://github.com/your_org/raggio"
    ]
  end

  defp deps do
    []  # No external dependency initially
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/your_org/raggio"},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end
end
```

### Best Practice Applied
1. **Separate `.formatter.exs`** per package with consistent rule
2. **Independent versioning**: Each package has own version and changelog
3. **Mix aliases** for coordinated testing and formatting
4. **Shared build artifact** (`_build`, `deps`, `mix.lock`) at umbrella root
5. **Package-specific README** with clear usage example

### Alternative Considered
- **Multi-repo** (separate repository for each package): Rejected because package are tightly related and developed together initially
- **Single package with namespace**: Rejected because spec explicitly require independent package (FR-004)

---

## 3. Composability without Macro

### Decision
Use **pure function with pipe operator**, **combinator pattern**, and **explicit data structure** to achieve composability without macro.

### Rationale
Elixir provide native support for function composition through pipe operator. By designing function with data-last signature and using struct to carry state, we can build fluent API without `use` macro:

1. **Pipe operator** (`|>`) enable natural left-to-right composition
2. **Combinator function** (higher-order function) compose behavior
3. **Explicit data passing** make function pure and testable
4. **Struct as state container** maintain state through pipeline

### Pattern to Apply

**Pattern 1: Data-last function for pipe composition**
```elixir
defmodule Raggio.Schema do
  # BAD: Data-first (doesn't pipe well)
  def validate(data, schema), do: ...
  
  # GOOD: Data-last (pipes naturally)
  def validate(schema, data), do: ...
  
  # Usage
  data |> Raggio.Schema.validate(user_schema)
end
```

**Pattern 2: Combinator for composition**
```elixir
defmodule Raggio.Schema do
  def compose(validators) when is_list(validators) do
    fn schema ->
      Enum.reduce(validators, {:ok, schema}, fn
        validator, {:ok, schema} -> validator.(schema)
        _validator, error -> error
      end)
    end
  end
  
  # Usage
  combined = Raggio.Schema.compose([
    &Raggio.Schema.min_length(&1, 5),
    &Raggio.Schema.max_length(&1, 50),
    &Raggio.Schema.pattern(&1, ~r/@/)
  ])
end
```

**Pattern 3: ValidationSet for error accumulation**
```elixir
defmodule Raggio.Schema.ValidationSet do
  defstruct data: %{}, error: [], valid?: true
  
  def new(data), do: %__MODULE__{data: data}
  
  def validate(vset, field, validator) do
    case validator.(vset.data[field]) do
      :ok -> vset
      {:error, msg} -> 
        %{vset | 
          error: [{field, msg} | vset.error],
          valid?: false
        }
    end
  end
  
  def apply(vset) do
    if vset.valid?, do: {:ok, vset.data}, else: {:error, Enum.reverse(vset.error)}
  end
end

# Usage accumulates all error
%{email: "bad", age: -5}
|> ValidationSet.new()
|> ValidationSet.validate(:email, &validate_email/1)
|> ValidationSet.validate(:age, &validate_age/1)
|> ValidationSet.apply()
```

**Pattern 4: Struct-based fluent API**
```elixir
defmodule Raggio.Schema do
  defstruct [:type, :constraint, :validator]
  
  def string(), do: %__MODULE__{type: :string, constraint: [], validator: []}
  
  def min_length(schema, n) do
    %{schema | constraint: [{:min_length, n} | schema.constraint]}
  end
  
  def max_length(schema, n) do
    %{schema | constraint: [{:max_length, n} | schema.constraint]}
  end
  
  # Usage
  Raggio.Schema.string()
  |> Raggio.Schema.min_length(5)
  |> Raggio.Schema.max_length(50)
end
```

### Error Handling Pattern

**Composition-time error** (per clarification):
```elixir
defmodule Raggio.Schema do
  def compose(schema1, schema2) do
    case compatible?(schema1.type, schema2.type) do
      true -> 
        {:ok, merge_schema(schema1, schema2)}
      false -> 
        {:error, %Raggio.Schema.CompositionError{
          message: "Cannot compose incompatible type",
          left_type: schema1.type,
          right_type: schema2.type
        }}
    end
  end
end
```

### Alternative Considered
- **Macro-based DSL**: Rejected per spec requirement (FR-007)
- **Protocol-based**: Considered but pure function are simpler and more explicit
- **GenServer for state**: Rejected because schema are immutable data structure

---

## 4. Example Testing Strategy

### Decision
Implement **automated test suite** using ExUnit that executes all example file and verifies output using **doctest-style assertion**.

### Rationale
Example must remain accurate as API evolve (FR-009). Automated testing ensure:

1. **Example always compile**: Catch syntax error and API change
2. **Output is verified**: Ensure example produce expected result
3. **CI integration**: Run automatically on every commit
4. **Fast feedback**: Developer know immediately when example break

### Implementation Approach

**Structure**:
```
test/
└── example_test.exs     # Single test file that discover and run all example
```

**Test implementation**:
```elixir
defmodule ExampleTest do
  use ExUnit.Case, async: true
  
  @examples_dir Path.expand("../examples", __DIR__)
  
  # Discover all .exs file in example directory
  @example_files @examples_dir
                 |> Path.join("**/*.exs")
                 |> Path.wildcard()
                 |> Enum.sort()
  
  for example_file <- @example_files do
    relative_path = Path.relative_to(example_file, @examples_dir)
    
    test "example: #{relative_path}" do
      # Execute example file
      {output, exit_code} = System.cmd("elixir", [unquote(example_file)], 
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )
      
      # Verify execution succeeded
      assert exit_code == 0, """
      Example failed: #{unquote(relative_path)}
      Output:
      #{output}
      """
      
      # Verify output contains expected marker (optional)
      # Example file can include "# Expected: <pattern>" comment
      # Test parse and verify output match pattern
    end
  end
end
```

**Example file pattern**:
```elixir
# examples/raggio_schema/basic_validation/simple_schema.exs

# Expected output: Validation succeeded: %{name: "Alice", age: 30}

user_schema = Raggio.Schema.struct([
  {:name, Raggio.Schema.string()},
  {:age, Raggio.Schema.integer()}
])

case Raggio.Schema.validate(user_schema, %{name: "Alice", age: 30}) do
  {:ok, data} -> 
    IO.puts("Validation succeeded: #{inspect(data)}")
  {:error, error} -> 
    IO.puts("Validation failed: #{inspect(error)}")
end
```

**CI integration**:
```yaml
# .github/workflows/ci.yml
- name: Run example test
  run: mix test test/example_test.exs
```

### Verification Strategy
1. **Compilation check**: Example must compile without error
2. **Execution check**: Example must run to completion (exit code 0)
3. **Output verification** (optional): Parse expected output from comment and verify

### Alternative Considered
- **Manual verification**: Rejected because not scalable and error-prone
- **Doctest in module doc**: Rejected because spec requires minimal inline documentation
- **Separate test per example**: Rejected because single test file is simpler to maintain

---

## Summary of Decision

| Area | Decision | Key Rationale |
|------|----------|---------------|
| API Pattern | Pipe-first composition with combinator | Match Elixir idiom; proven by Effect-TS |
| Project Structure | Umbrella project with independent package | Balance unified development with independent publishing |
| Composition | Pure function + pipe operator + struct | No macro required; explicit and testable |
| Error Handling | Composition-time error + accumulated validation error | Fail fast on type mismatch; accumulate validation error |
| Example Testing | Automated ExUnit test discovering all example | Ensure example accuracy with CI integration |

## Implementation Readiness

All NEEDS CLARIFICATION item from Technical Context are now resolved:
- ✅ Language/Version: Elixir 1.14+
- ✅ Testing: ExUnit with automated example verification
- ✅ Project Type: Umbrella monorepo
- ✅ API Design: Pipe-first composition without macro
- ✅ Error Strategy: Composition-time + validation-time

**Next Phase**: Phase 1 - Design & Contract (data model, API contract, quickstart guide)
