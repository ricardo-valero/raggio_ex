defmodule Raggio.SchemaTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error

  # Inspired by effect-smol's Schema.test.ts: one describe per constructor, each
  # asserting representative success and failure cases, and checking the error
  # constraint tag + path on failure.

  defp errors(schema, data, opts \\ []) do
    assert {:error, errs} = Schema.validate(schema, data, opts)
    errs
  end

  describe "string/0,1" do
    test "accepts a binary" do
      assert {:ok, "hi"} = Schema.validate(Schema.string(), "hi")
    end

    test "rejects a non-binary with a :type error" do
      assert [%Error{constraint: :type, path: []}] = errors(Schema.string(), 1)
    end

    test "min/max are length bounds" do
      assert {:ok, "abc"} = Schema.validate(Schema.string(min: 3, max: 5), "abc")
      assert [%Error{constraint: :min}] = errors(Schema.string(min: 3), "ab")
      assert [%Error{constraint: :max}] = errors(Schema.string(max: 2), "abc")
    end

    test "pattern must match" do
      schema = Schema.string(pattern: ~r/^[a-z]+$/)
      assert {:ok, "abc"} = Schema.validate(schema, "abc")
      assert [%Error{constraint: :pattern}] = errors(schema, "ABC")
    end
  end

  describe "integer/0,1" do
    test "accepts an integer, rejects a float" do
      assert {:ok, 5} = Schema.validate(Schema.integer(), 5)
      assert [%Error{constraint: :type}] = errors(Schema.integer(), 5.0)
    end

    test "min/max bound the value" do
      assert {:ok, 5} = Schema.validate(Schema.integer(min: 0, max: 10), 5)
      assert [%Error{constraint: :min}] = errors(Schema.integer(min: 0), -1)
      assert [%Error{constraint: :max}] = errors(Schema.integer(max: 10), 11)
    end
  end

  describe "float/0,1" do
    test "accepts a float and widens an integer to float" do
      assert {:ok, 1.5} = Schema.validate(Schema.float(), 1.5)
      assert {:ok, 5.0} = Schema.validate(Schema.float(), 5)
    end

    test "rejects a non-number" do
      assert [%Error{constraint: :type}] = errors(Schema.float(), "x")
    end
  end

  describe "boolean / atom / date / datetime / decimal" do
    test "boolean" do
      assert {:ok, true} = Schema.validate(Schema.boolean(), true)
      assert [%Error{constraint: :type}] = errors(Schema.boolean(), "true")
    end

    test "atom" do
      assert {:ok, :ok} = Schema.validate(Schema.atom(), :ok)
      assert [%Error{constraint: :type}] = errors(Schema.atom(), "ok")
    end

    test "date / datetime" do
      assert {:ok, _} = Schema.validate(Schema.date(), ~D[2026-06-30])
      assert {:ok, _} = Schema.validate(Schema.datetime(), ~U[2026-06-30 12:00:00Z])
      assert {:ok, _} = Schema.validate(Schema.datetime(), ~N[2026-06-30 12:00:00])
      assert [%Error{constraint: :type}] = errors(Schema.date(), "2026-06-30")
    end

    test "decimal" do
      assert {:ok, _} = Schema.validate(Schema.decimal(), Decimal.new("1.5"))
      assert [%Error{constraint: :type}] = errors(Schema.decimal(), 1.5)
    end
  end

  describe "struct/1" do
    test "validates declared fields" do
      schema = Schema.struct([{:name, Schema.string()}, {:age, Schema.integer(min: 0)}])
      assert {:ok, _} = Schema.validate(schema, %{name: "A", age: 1})
    end

    test "missing required field yields a :required error at the field path" do
      schema = Schema.struct([{:name, Schema.string()}])
      assert [%Error{constraint: :required, path: [:name]}] = errors(schema, %{})
    end

    test "optional field may be absent" do
      schema = Schema.struct([{:name, Schema.string()}, {:bio, Schema.optional(Schema.string())}])
      assert {:ok, _} = Schema.validate(schema, %{name: "A"})
    end

    test "missing defaulted field does not error" do
      schema = Schema.struct([{:status, Schema.string("active")}])
      assert {:ok, _} = Schema.validate(schema, %{})
    end

    test "nested field error carries the full path" do
      schema =
        Schema.struct([
          {:user, Schema.struct([{:age, Schema.integer(min: 0)}])}
        ])

      assert [%Error{constraint: :min, path: [:user, :age]}] =
               errors(schema, %{user: %{age: -1}})
    end
  end

  describe "list/2" do
    test "validates each element and constraints" do
      schema = Schema.list(Schema.integer(min: 0), min: 1, max: 3)
      assert {:ok, [1, 2]} = Schema.validate(schema, [1, 2])
      assert [%Error{constraint: :min}] = errors(schema, [])
      assert [%Error{constraint: :max}] = errors(schema, [1, 2, 3, 4])
    end

    test "unique constraint rejects duplicates" do
      schema = Schema.list(Schema.string(), unique: true)
      assert [%Error{constraint: :unique}] = errors(schema, ["a", "a"])
    end

    test "element error carries the index in its path" do
      schema = Schema.list(Schema.integer())
      assert [%Error{constraint: :type, path: [1]}] = errors(schema, [1, "x"])
    end
  end

  describe "tuple/1" do
    test "validates positionally and returns a tuple" do
      schema = Schema.tuple([Schema.string(), Schema.integer()])
      assert {:ok, {"a", 1}} = Schema.validate(schema, {"a", 1})
    end

    test "size mismatch is a :type error" do
      schema = Schema.tuple([Schema.string(), Schema.integer()])
      assert [%Error{constraint: :type}] = errors(schema, {"a"})
    end
  end

  describe "union/1" do
    test "accepts a value matching any variant" do
      schema = Schema.union([Schema.string(), Schema.integer()])
      assert {:ok, "a"} = Schema.validate(schema, "a")
      assert {:ok, 1} = Schema.validate(schema, 1)
    end

    test "rejects a value matching no variant" do
      schema = Schema.union([Schema.string(), Schema.integer()])
      assert [%Error{constraint: :union}] = errors(schema, true)
    end
  end

  describe "literal/1..3" do
    test "accepts an allowed value" do
      assert {:ok, :active} = Schema.validate(Schema.literal(:active, :inactive), :active)
    end

    test "rejects a disallowed value" do
      assert [%Error{constraint: :literal}] = errors(Schema.literal(:active), :nope)
    end
  end

  describe "record/2" do
    test "validates keys and values" do
      schema = Schema.record(Schema.string(), Schema.integer(min: 0))
      assert {:ok, %{"a" => 1}} = Schema.validate(schema, %{"a" => 1})
    end

    test "rejects an invalid value" do
      schema = Schema.record(Schema.string(), Schema.integer(min: 0))
      assert {:error, _} = Schema.validate(schema, %{"a" => -1})
    end
  end

  describe "optional / nullable / default" do
    test "nullable accepts nil" do
      assert {:ok, nil} = Schema.validate(Schema.nullable(Schema.string()), nil)
    end

    test "default is returned when value is nil (top-level)" do
      assert {:ok, 0} = Schema.validate(Schema.integer(0), nil)
      assert {:ok, "active"} = Schema.validate(Schema.string("active"), nil)
    end
  end

  describe "validation modes" do
    test ":fail_fast (default) returns a single error" do
      schema = Schema.struct([{:a, Schema.string()}, {:b, Schema.string()}])
      assert length(errors(schema, %{})) == 1
    end

    test ":all_errors collects one error per failing field" do
      schema = Schema.struct([{:a, Schema.string()}, {:b, Schema.string()}])
      errs = errors(schema, %{}, mode: :all_errors)
      assert length(errs) == 2
      assert Enum.map(errs, & &1.path) |> Enum.sort() == [[:a], [:b]]
    end

    test "partial: true skips missing fields" do
      schema = Schema.struct([{:a, Schema.string()}, {:b, Schema.string()}])
      assert {:ok, _} = Schema.validate(schema, %{a: "x"}, partial: true)
    end
  end

  describe "validate!/2" do
    test "returns the value on success" do
      assert "hi" == Schema.validate!(Schema.string(), "hi")
    end

    test "raises ValidationError on failure" do
      assert_raise Raggio.Schema.ValidationError, fn ->
        Schema.validate!(Schema.string(), 1)
      end
    end
  end
end
