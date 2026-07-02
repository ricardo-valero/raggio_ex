defmodule Raggio.Schema.CodecTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Raggio.Schema
  alias Raggio.Schema.Error
  alias Raggio.Schema.Adapters.JsonSchema

  describe "number_from_string" do
    test "decodes a numeric string to an integer" do
      assert {:ok, 42} = Schema.validate(Schema.number_from_string(), "42")
    end

    test "decodes a decimal string to a float" do
      assert {:ok, 3.14} = Schema.validate(Schema.number_from_string(), "3.14")
    end

    test "decode failure is a structured :transform error" do
      assert {:error, [%Error{constraint: :transform, value: "abc"}]} =
               Schema.validate(Schema.number_from_string(), "abc")
    end

    test "rejects a non-string (encoded-side type error)" do
      assert {:error, [%Error{constraint: :type}]} =
               Schema.validate(Schema.number_from_string(), 42)
    end

    test "encode reverses decode" do
      assert {:ok, "42"} = Schema.encode(Schema.number_from_string(), 42)
    end
  end

  describe "string transforms" do
    test "trim" do
      assert {:ok, "x"} = Schema.validate(Schema.trim(), "  x  ")
      assert {:ok, "x"} = Schema.encode(Schema.trim(), "x")
    end

    test "downcase / upcase" do
      assert {:ok, "abc"} = Schema.validate(Schema.downcase(), "ABC")
      assert {:ok, "ABC"} = Schema.validate(Schema.upcase(), "abc")
    end
  end

  describe "datetime_from_iso8601" do
    test "decodes / encodes / round-trips" do
      iso = "2026-07-02T12:00:00Z"
      assert {:ok, %DateTime{} = dt} = Schema.validate(Schema.datetime_from_iso8601(), iso)
      assert {:ok, ^iso} = Schema.encode(Schema.datetime_from_iso8601(), dt)
    end

    test "rejects an invalid datetime string" do
      assert {:error, [%Error{constraint: :transform}]} =
               Schema.validate(Schema.datetime_from_iso8601(), "nope")
    end
  end

  describe "propagation through lists" do
    test "decode maps each element" do
      schema = Schema.list(Schema.number_from_string())
      assert {:ok, [1, 2, 3]} = Schema.validate(schema, ["1", "2", "3"])
    end

    test "encode maps each element" do
      schema = Schema.list(Schema.number_from_string())
      assert {:ok, ["1", "2"]} = Schema.encode(schema, [1, 2])
    end
  end

  describe "composition (nesting)" do
    test "decode threads through both transforms" do
      # "21" --number_from_string--> 21 --double--> 42
      doubled =
        Schema.transform(Schema.number_from_string(), &{:ok, &1 * 2}, &div(&1, 2))

      assert {:ok, 42} = Schema.validate(doubled, "21")
      assert {:ok, "21"} = Schema.encode(doubled, 42)
    end
  end

  describe "JSON Schema (encoded/wire side)" do
    test "a transform reports its encoded side" do
      assert JsonSchema.to_json_schema(Schema.number_from_string(), root: false) == %{
               "type" => "string"
             }
    end
  end

  describe "decode/2 alias" do
    test "decode is validate" do
      assert {:ok, 5} = Schema.decode(Schema.number_from_string(), "5")
    end
  end

  describe "properties" do
    property "encode |> decode is identity for number_from_string" do
      schema = Schema.number_from_string()

      check all(n <- integer()) do
        assert {:ok, encoded} = Schema.encode(schema, n)
        assert {:ok, ^n} = Schema.validate(schema, encoded)
      end
    end
  end
end
