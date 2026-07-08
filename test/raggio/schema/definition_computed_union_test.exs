defmodule Raggio.Schema.DefinitionComputedUnionTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema.Error

  # --- tagged union over a COMPUTED member list --------------------------------
  #
  # The schema-block DSL routes `union(:disc, expr)` to the runtime
  # `Raggio.Schema.union/2` for ANY member expression — not just a syntactic
  # list literal — matching effect-ts, where `S.Union(...members.map(f))` is
  # idiomatic (schemas are first-class values).

  defmodule MappedCatalog do
    use Raggio.Schema

    @catalog [dog: [:bark, :growl], cat: [:meow]]

    schema do
      union(
        :name,
        Enum.map(@catalog, fn {animal, sounds} ->
          struct(name: literal(animal), sound: literal(sounds))
        end)
      )
    end
  end

  defmodule ComprehendedCatalog do
    use Raggio.Schema

    @catalog [dog: [:bark, :growl], cat: [:meow]]

    schema do
      union(
        :name,
        for {animal, sounds} <- @catalog do
          struct(name: literal(animal), sound: literal(sounds))
        end
      )
    end
  end

  # the existing syntactic-list form must keep working (and keeps its precise type)
  defmodule Alpha do
    use Raggio.Schema

    schema do
      struct(tag: literal(:alpha), size: integer())
    end
  end

  defmodule Beta do
    use Raggio.Schema

    schema do
      struct(tag: literal(:beta), size: integer())
    end
  end

  defmodule Syntactic do
    use Raggio.Schema

    schema do
      union(:tag, [Alpha, Beta])
    end
  end

  describe "union(:disc, Enum.map(...)) — computed members" do
    test "decode dispatches on the discriminator to the matching member" do
      assert {:ok, %{name: :dog, sound: :bark}} =
               MappedCatalog.decode(%{name: :dog, sound: :bark})

      assert {:ok, %{name: :cat, sound: :meow}} =
               MappedCatalog.decode(%{name: :cat, sound: :meow})
    end

    test "a wrong pair fails with the matched member's errors, not 'tried them all'" do
      # :meow is cat-only — the dog member's literal check reports it
      assert {:error, [%Error{path: [:sound], constraint: :literal, value: :meow}]} =
               MappedCatalog.decode(%{name: :dog, sound: :meow})
    end

    test "an unknown discriminator value is a :discriminator error" do
      assert {:error, [%Error{path: [:name], constraint: :discriminator, value: :fox}]} =
               MappedCatalog.decode(%{name: :fox, sound: :bark})
    end

    test "encode round-trips" do
      {:ok, decoded} = MappedCatalog.decode(%{name: :dog, sound: :growl})
      assert {:ok, encoded} = MappedCatalog.encode(decoded)
      assert {:ok, ^decoded} = MappedCatalog.decode(encoded)
    end

    test "combinator calls inside the Enum.map body were rewritten" do
      # struct/literal in the fn body resolved to Raggio.Schema.* — the schema
      # is a tagged union whose members carry the per-member literal sets
      schema = MappedCatalog.__schema__()
      assert schema.discriminator == :name
      assert [dog, cat] = schema.elements

      assert {:sound, %{kind: :literal, values: [:bark, :growl]}} =
               List.keyfind(dog.fields, :sound, 0)

      assert {:sound, %{kind: :literal, values: [:meow]}} =
               List.keyfind(cat.fields, :sound, 0)
    end
  end

  describe "union(:disc, for ... do struct(...) end) — comprehension members" do
    test "decode dispatches on the discriminator" do
      assert {:ok, %{name: :cat, sound: :meow}} =
               ComprehendedCatalog.decode(%{name: :cat, sound: :meow})
    end

    test "a wrong pair fails with the matched member's errors" do
      assert {:error, [%Error{path: [:sound], constraint: :literal}]} =
               ComprehendedCatalog.decode(%{name: :cat, sound: :bark})
    end

    test "encode round-trips" do
      {:ok, decoded} = ComprehendedCatalog.decode(%{name: :dog, sound: :bark})
      assert {:ok, encoded} = ComprehendedCatalog.encode(decoded)
      assert {:ok, ^decoded} = ComprehendedCatalog.decode(encoded)
    end
  end

  describe "syntactic member list stays on the precise path" do
    test "decode still dispatches and builds member structs" do
      assert {:ok, %Alpha{size: 1}} = Syntactic.decode(%{tag: :alpha, size: 1})
      assert {:ok, %Beta{size: 2}} = Syntactic.decode(%{tag: :beta, size: 2})
    end

    test "errors come from the matched member" do
      assert {:error, [%Error{path: [:size], constraint: :type}]} =
               Syntactic.decode(%{tag: :alpha, size: "big"})
    end
  end
end
