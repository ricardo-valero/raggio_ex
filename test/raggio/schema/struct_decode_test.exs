defmodule Raggio.Schema.StructDecodeTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error

  defmodule User do
    defstruct [:name, :age, :status, :bio]
  end

  defmodule Counter do
    defstruct [:count, :name]
  end

  describe "struct decode rebuilds the value (Type projection)" do
    test "output contains the decoded field values" do
      schema = Schema.struct([{:name, Schema.string()}, {:age, Schema.integer()}])
      assert {:ok, %{name: "A", age: 1}} = Schema.validate(schema, %{name: "A", age: 1})
    end

    test "defaults are merged into the output (fixes the P0-era wart)" do
      schema = Schema.struct([{:name, Schema.string()}, {:status, Schema.string("active")}])
      assert {:ok, %{name: "A", status: "active"}} = Schema.validate(schema, %{name: "A"})
    end

    test "undeclared keys are dropped" do
      schema = Schema.struct([{:name, Schema.string()}])
      assert {:ok, decoded} = Schema.validate(schema, %{name: "A", extra: 1})
      refute Map.has_key?(decoded, :extra)
    end

    test "absent optional fields stay absent" do
      schema = Schema.struct([{:name, Schema.string()}, {:bio, Schema.optional(Schema.string())}])
      assert {:ok, decoded} = Schema.validate(schema, %{name: "A"})
      refute Map.has_key?(decoded, :bio)
    end

    test "nullable fields materialize as nil" do
      schema = Schema.struct([{:bio, Schema.nullable(Schema.string())}])
      assert {:ok, %{bio: nil}} = Schema.validate(schema, %{bio: nil})
    end

    test "nested structs are rebuilt recursively" do
      schema =
        Schema.struct([
          {:user, Schema.struct([{:name, Schema.string()}, {:role, Schema.string("member")}])}
        ])

      assert {:ok, %{user: %{name: "A", role: "member"}}} =
               Schema.validate(schema, %{user: %{name: "A", junk: true}})
    end

    test "partial mode rebuilds from the fields that are present" do
      schema = Schema.struct([{:a, Schema.string()}, {:b, Schema.string()}])
      assert {:ok, decoded} = Schema.validate(schema, %{a: "x"}, partial: true)
      assert decoded == %{a: "x"}
    end
  end

  describe "transforms through struct fields (closes the P2 gap)" do
    test "a field's transform output lands in the decoded map" do
      schema =
        Schema.struct([
          {:count, Schema.number_from_string()},
          {:name, Schema.trim()}
        ])

      assert {:ok, %{count: 42, name: "x"}} =
               Schema.validate(schema, %{count: "42", name: "  x "})
    end

    test "a failing field transform reports the field path" do
      schema = Schema.struct([{:count, Schema.number_from_string()}])

      assert {:error, [%Error{constraint: :transform, path: [:count]}]} =
               Schema.validate(schema, %{count: "abc"})
    end
  end

  describe "bound module (module: opt)" do
    test "decode returns the target struct" do
      schema =
        Schema.struct(
          [
            {:name, Schema.string()},
            {:age, Schema.integer(min: 0)},
            {:status, Schema.string("active")}
          ],
          module: User
        )

      assert {:ok, %User{name: "A", age: 1, status: "active"}} =
               Schema.validate(schema, %{name: "A", age: 1})
    end

    test "field errors still carry paths (no struct built on failure)" do
      schema = Schema.struct([{:age, Schema.integer(min: 0)}], module: User)

      assert {:error, [%Error{path: [:age], constraint: :min}]} =
               Schema.validate(schema, %{age: -1})
    end

    test "encode turns the struct back into a wire map" do
      schema =
        Schema.struct(
          [{:count, Schema.number_from_string()}, {:name, Schema.string()}],
          module: Counter
        )

      # round-trip: decode builds the struct, encode flattens it back to the wire shape
      assert {:ok, encoded} = Schema.encode(schema, %Counter{count: 42, name: "A"})
      refute Map.has_key?(encoded, :__struct__)
    end

    test "decode |> encode round-trips the declared fields" do
      schema =
        Schema.struct(
          [{:count, Schema.number_from_string()}, {:name, Schema.string()}],
          module: Counter
        )

      wire = %{count: "42", name: "A"}
      assert {:ok, %Counter{count: 42, name: "A"} = decoded} = Schema.validate(schema, wire)
      assert {:ok, %{count: "42", name: "A"}} = Schema.encode(schema, decoded)
    end

    test "a schema field the bound struct lacks raises (no silent data loss)" do
      schema = Schema.struct([{:nope, Schema.string()}], module: Counter)

      assert_raise KeyError, fn ->
        Schema.validate(schema, %{nope: "x"})
      end
    end
  end
end
