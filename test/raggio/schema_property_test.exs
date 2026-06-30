defmodule Raggio.SchemaPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Raggio.Schema
  alias Raggio.Schema.Error

  # The analog of Effect's ToArbitrary: generate values from a schema's intent and
  # assert `validate` agrees with the declared constraints.

  describe "string length bounds" do
    property "strings within [min, max] validate" do
      check all(
              min <- integer(1..5),
              extra <- integer(0..5),
              str <- string(:alphanumeric, length: min + extra)
            ) do
        schema = Schema.string(min: min, max: min + 5)
        assert {:ok, ^str} = Schema.validate(schema, str)
      end
    end

    property "strings shorter than min fail with a :min error" do
      check all(
              min <- integer(2..6),
              len <- integer(0..(min - 1)),
              str <- string(:alphanumeric, length: len)
            ) do
        assert {:error, [%Error{constraint: :min}]} =
                 Schema.validate(Schema.string(min: min), str)
      end
    end
  end

  describe "integer value bounds" do
    property "integers within [min, max] validate" do
      check all(
              min <- integer(-50..50),
              span <- integer(0..100),
              value <- integer(min..(min + span))
            ) do
        schema = Schema.integer(min: min, max: min + span)
        assert {:ok, ^value} = Schema.validate(schema, value)
      end
    end

    property "integers below min fail with a :min error" do
      check all(
              min <- integer(0..50),
              value <- integer((min - 50)..(min - 1))
            ) do
        assert {:error, [%Error{constraint: :min}]} =
                 Schema.validate(Schema.integer(min: min), value)
      end
    end
  end

  describe "list unique" do
    property "distinct lists pass; injecting a duplicate fails" do
      check all(list <- uniq_list_of(integer(), min_length: 1, max_length: 6)) do
        schema = Schema.list(Schema.integer(), unique: true)
        assert {:ok, _} = Schema.validate(schema, list)

        assert {:error, [%Error{constraint: :unique}]} =
                 Schema.validate(schema, [hd(list) | list])
      end
    end
  end

  describe "struct with all required fields" do
    property "a complete map validates" do
      check all(
              name <- string(:alphanumeric, min_length: 1, max_length: 20),
              age <- integer(0..120)
            ) do
        schema = Schema.struct([{:name, Schema.string(min: 1)}, {:age, Schema.integer(min: 0)}])
        assert {:ok, _} = Schema.validate(schema, %{name: name, age: age})
      end
    end
  end
end
