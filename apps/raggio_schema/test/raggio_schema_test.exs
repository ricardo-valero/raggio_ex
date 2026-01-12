defmodule RaggioSchemaTest do
  use ExUnit.Case
  doctest Raggio.Schema

  alias Raggio.Schema

  describe "primitive types" do
    test "string/0 creates string schema" do
      schema = Schema.string()
      assert schema.type == :string
    end

    test "integer/0 creates integer schema" do
      schema = Schema.integer()
      assert schema.type == :integer
    end

    test "float/0 creates float schema" do
      schema = Schema.float()
      assert schema.type == :float
    end

    test "boolean/0 creates boolean schema" do
      schema = Schema.boolean()
      assert schema.type == :boolean
    end
  end

  describe "composite types" do
    test "struct/1 creates struct schema" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.integer()}
        ])

      assert schema.type == :struct
      assert length(schema.fields) == 2
    end

    test "array/1 creates array schema" do
      schema = Schema.array(Schema.string())
      assert schema.type == :array
    end
  end

  describe "validation" do
    test "validates valid string data" do
      schema = Schema.string()
      assert {:ok, "hello"} = Schema.validate(schema, "hello")
    end

    test "validates invalid string data" do
      schema = Schema.string()
      assert {:error, errors} = Schema.validate(schema, 123)
      assert length(errors) > 0
    end

    test "validates struct with valid data" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.integer()}
        ])

      assert {:ok, _} = Schema.validate(schema, %{name: "Alice", age: 30})
    end

    test "validates struct with invalid data" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.integer()}
        ])

      assert {:error, errors} = Schema.validate(schema, %{name: "Alice", age: "not a number"})
      assert length(errors) > 0
    end
  end

  describe "constraints" do
    test "min_length constraint" do
      schema = Schema.string() |> Schema.min_length(5)
      assert {:ok, _} = Schema.validate(schema, "hello")
      assert {:error, _} = Schema.validate(schema, "hi")
    end

    test "positive constraint" do
      schema = Schema.integer() |> Schema.positive()
      assert {:ok, _} = Schema.validate(schema, 10)
      assert {:error, _} = Schema.validate(schema, -5)
    end

    test "email constraint" do
      schema = Schema.string() |> Schema.email()
      assert {:ok, _} = Schema.validate(schema, "test@example.com")
      assert {:error, _} = Schema.validate(schema, "not-an-email")
    end
  end

  describe "composition" do
    test "chains constraints with pipe operator" do
      schema =
        Schema.string()
        |> Schema.min_length(5)
        |> Schema.max_length(50)

      assert {:ok, _} = Schema.validate(schema, "hello world")
      assert {:error, _} = Schema.validate(schema, "hi")
    end

    test "composition error on incompatible types" do
      assert_raise Raggio.Schema.CompositionError, fn ->
        Schema.integer() |> Schema.email()
      end
    end
  end
end
