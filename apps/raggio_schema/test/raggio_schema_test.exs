defmodule RaggioSchemaTest do
  use ExUnit.Case
  doctest Raggio.Schema

  alias Raggio.Schema

  describe "primitive types" do
    test "string/0 creates string schema" do
      schema = Schema.string()
      assert schema.type == :string
    end

    test "string/1 with constraints" do
      schema = Schema.string(min: 3, max: 10)
      assert schema.type == :string
      assert schema.constraints == [min: 3, max: 10]
    end

    test "integer/0 creates integer schema" do
      schema = Schema.integer()
      assert schema.type == :integer
    end

    test "integer/1 with constraints" do
      schema = Schema.integer(min: 0, max: 100)
      assert schema.type == :integer
      assert schema.constraints == [min: 0, max: 100]
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

    test "list/1 creates list schema" do
      schema = Schema.list(Schema.string())
      assert schema.type == :list
    end

    test "list/2 with constraints" do
      schema = Schema.list(Schema.string(), min: 1, max: 5, unique: true)
      assert schema.type == :list
      assert schema.constraints == [min: 1, max: 5, unique: true]
    end

    test "literal/1 creates literal schema" do
      schema = Schema.literal(:pending, :approved, :rejected)
      assert schema.type == :literal
      assert schema.values == [:pending, :approved, :rejected]
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
    test "min constraint on string" do
      schema = Schema.string(min: 5)
      assert {:ok, _} = Schema.validate(schema, "hello")
      assert {:error, _} = Schema.validate(schema, "hi")
    end

    test "min constraint on integer" do
      schema = Schema.integer(min: 1)
      assert {:ok, _} = Schema.validate(schema, 10)
      assert {:error, _} = Schema.validate(schema, -5)
    end

    test "pattern constraint on string" do
      schema = Schema.string(pattern: Schema.email())
      assert {:ok, _} = Schema.validate(schema, "test@example.com")
      assert {:error, _} = Schema.validate(schema, "not-an-email")
    end
  end

  describe "field descriptors" do
    test "optional/1 marks field as optional" do
      schema = Schema.optional(Schema.string())
      assert schema.optional == true
      assert {:ok, nil} = Schema.validate(schema, nil)
    end

    test "nullable/1 allows nil value" do
      schema = Schema.nullable(Schema.string())
      assert schema.nullable == true
      assert {:ok, nil} = Schema.validate(schema, nil)
    end
  end

  describe "convenience helpers" do
    test "email/0 returns email regex" do
      regex = Schema.email()
      assert Regex.match?(regex, "test@example.com")
      refute Regex.match?(regex, "not-an-email")
    end

    test "url/0 returns URL regex" do
      regex = Schema.url()
      assert Regex.match?(regex, "https://example.com")
      refute Regex.match?(regex, "not-a-url")
    end

    test "uuid/0 returns UUID regex" do
      regex = Schema.uuid()
      assert Regex.match?(regex, "550e8400-e29b-41d4-a716-446655440000")
      refute Regex.match?(regex, "not-a-uuid")
    end
  end

  describe "composition" do
    test "combines constraints via keyword args" do
      schema = Schema.string(min: 5, max: 50)
      assert {:ok, _} = Schema.validate(schema, "hello world")
      assert {:error, _} = Schema.validate(schema, "hi")
    end

    test "literal type validates allowed values" do
      schema = Schema.literal(:a, :b, :c)
      assert {:ok, :a} = Schema.validate(schema, :a)
      assert {:error, _} = Schema.validate(schema, :d)
    end
  end
end
