defmodule Raggio.Schema.StructMacroTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema.AST

  defmodule Status do
    use Raggio.Schema.Literal, values: ["on", "off"]
  end

  defmodule Level do
    use Raggio.Schema.Literal, values: ["low", "high"], decode: :downcase
  end

  defmodule Mode do
    use Raggio.Schema.Literal, values: [:read, :write]
  end

  defmodule User do
    use Raggio.Schema.Struct

    defschema(
      name: Schema.string(min: 1),
      age: Schema.integer(min: 0),
      status: Schema.literal(:active, :inactive),
      bio: Schema.string() |> Schema.optional()
    )
  end

  # Exercises every branch of the @type t derivation — compiling this module IS the
  # assertion that the generated typespec is well-formed.
  defmodule Kitchen do
    use Raggio.Schema.Struct

    defschema(
      count: Schema.number_from_string(),
      tags: Schema.list(Schema.string()),
      kind: Schema.union([Schema.string(), Schema.integer()]),
      when: Schema.datetime_from_iso8601(),
      price: Schema.decimal() |> Schema.nullable(),
      even: Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even"),
      meta: Schema.record(Schema.string(), Schema.integer())
    )
  end

  # Module composition: literal-set field + embedded defschema module.
  defmodule Device do
    use Raggio.Schema.Struct

    defschema(
      name: Schema.string(min: 1),
      status: Status,
      owner: User
    )
  end

  describe "defschema" do
    test "defines the struct with the declared fields" do
      assert %User{} |> Map.keys() |> Enum.sort() == [:__struct__, :age, :bio, :name, :status]
    end

    test "__schema__/0 returns the runtime schema bound to the module" do
      assert %AST{kind: :struct, module: User, fields: fields} = User.__schema__()
      assert Keyword.keys(fields) == [:name, :age, :status, :bio]
    end

    test "decode builds the struct with validated values" do
      assert {:ok, %User{name: "A", age: 30, status: :active}} =
               User.decode(%{name: "A", age: 30, status: :active})
    end

    test "absent optional fields fall back to the struct default (nil)" do
      assert {:ok, %User{bio: nil}} = User.decode(%{name: "A", age: 1, status: :active})
    end

    test "field transforms decode into the struct" do
      assert {:ok, %Kitchen{count: 42}} =
               Kitchen.decode(%{
                 count: "42",
                 tags: ["a"],
                 kind: 1,
                 when: "2026-07-02T12:00:00Z",
                 price: nil,
                 even: 2,
                 meta: %{"a" => 1}
               })
    end

    test "returns structured errors" do
      assert {:error, [%Raggio.Schema.Error{path: [:age], constraint: :min}]} =
               User.decode(%{name: "A", age: -1, status: :active})
    end

    test "decode!/1 raises on invalid data" do
      assert_raise Raggio.Schema.ValidationError, fn ->
        User.decode!(%{name: "A", age: -1, status: :active})
      end
    end

    test "encode round-trips through the wire shape" do
      wire = %{
        count: "42",
        tags: ["a"],
        kind: 1,
        when: "2026-07-02T12:00:00Z",
        price: nil,
        even: 2,
        meta: %{"a" => 1}
      }

      assert {:ok, %Kitchen{} = decoded} = Kitchen.decode(wire)
      assert {:ok, encoded} = Kitchen.encode(decoded)
      assert encoded[:count] == "42"
      assert encoded[:when] == "2026-07-02T12:00:00Z"
      refute Map.has_key?(encoded, :__struct__)
    end

    test "empty defschema raises at compile time" do
      assert_raise ArgumentError, ~r/at least one field/, fn ->
        defmodule Empty do
          use Raggio.Schema.Struct
          defschema([])
        end
      end
    end
  end

  describe "Raggio.Schema.Literal" do
    test "decodes a member and rejects a non-member" do
      assert {:ok, "on"} = Status.decode("on")
      assert {:error, [%Raggio.Schema.Error{constraint: :literal}]} = Status.decode("blue")
    end

    test "values/0 exposes the set" do
      assert Status.values() == ["on", "off"]
    end

    test "atom value sets work" do
      assert {:ok, :read} = Mode.decode(:read)
      assert {:error, _} = Mode.decode(:delete)
    end

    test "decode: :downcase folds the wire value before matching" do
      assert {:ok, "high"} = Level.decode("HIGH")
      assert {:ok, "low"} = Level.decode("Low")
      assert {:error, [%Raggio.Schema.Error{constraint: :transform}]} = Level.decode("MEDIUM")
    end

    test "encode is the canonical value" do
      assert {:ok, "high"} = Level.encode("high")
    end
  end

  describe "module composition" do
    test "a literal-set module is usable as a field schema" do
      assert {:ok, %Device{status: "on"}} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: 1, status: :active}
               })
    end

    test "an embedded defschema module decodes to its own struct" do
      assert {:ok, %Device{owner: %User{name: "A"}}} =
               Device.decode(%{
                 name: "lamp",
                 status: "off",
                 owner: %{name: "A", age: 1, status: :active}
               })
    end

    test "nested errors carry the full path" do
      assert {:error, [%Raggio.Schema.Error{path: [:owner, :age]}]} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: -1, status: :active}
               })
    end

    test "runtime combinators also accept modules" do
      schema = Raggio.Schema.list(Status)
      assert {:ok, ["on", "off"]} = Raggio.Schema.validate(schema, ["on", "off"])
    end
  end
end
