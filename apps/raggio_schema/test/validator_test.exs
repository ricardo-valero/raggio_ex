defmodule Raggio.Schema.ValidatorTest do
  use ExUnit.Case
  doctest Raggio.Schema.Validator

  alias Raggio.Schema
  alias Raggio.Schema.Validator

  describe "primitive type validation" do
    test "validates string type" do
      schema = Schema.string()
      assert {:ok, "hello"} = Validator.validate(schema, "hello")
      assert {:error, errors} = Validator.validate(schema, 123)
      assert [%{constraint: :type, message: "must be string type"}] = errors
    end

    test "validates integer type" do
      schema = Schema.integer()
      assert {:ok, 42} = Validator.validate(schema, 42)
      assert {:error, errors} = Validator.validate(schema, "not an int")
      assert [%{constraint: :type}] = errors
    end

    test "validates float type" do
      schema = Schema.float()
      assert {:ok, 3.14} = Validator.validate(schema, 3.14)
      assert {:error, _} = Validator.validate(schema, 42)
    end

    test "validates boolean type" do
      schema = Schema.boolean()
      assert {:ok, true} = Validator.validate(schema, true)
      assert {:ok, false} = Validator.validate(schema, false)
      assert {:error, _} = Validator.validate(schema, "true")
    end

    test "validates atom type" do
      schema = Schema.atom()
      assert {:ok, :foo} = Validator.validate(schema, :foo)
      assert {:error, _} = Validator.validate(schema, "foo")
    end

    test "validates date type" do
      schema = Schema.date()
      date = ~D[2024-01-15]
      assert {:ok, ^date} = Validator.validate(schema, date)
      assert {:error, _} = Validator.validate(schema, "2024-01-15")
    end

    test "validates datetime type" do
      schema = Schema.datetime()
      dt = ~U[2024-01-15 10:30:00Z]
      assert {:ok, ^dt} = Validator.validate(schema, dt)

      ndt = ~N[2024-01-15 10:30:00]
      assert {:ok, ^ndt} = Validator.validate(schema, ndt)

      assert {:error, _} = Validator.validate(schema, "2024-01-15")
    end

    test "validates decimal type" do
      schema = Schema.decimal()
      assert {:ok, 42} = Validator.validate(schema, 42)
      assert {:ok, 3.14} = Validator.validate(schema, 3.14)
      assert {:error, _} = Validator.validate(schema, "3.14")
    end
  end

  describe "string constraints" do
    test "validates min_length constraint" do
      schema = Schema.string() |> Schema.min_length(5)
      assert {:ok, "hello"} = Validator.validate(schema, "hello")
      assert {:ok, "hello world"} = Validator.validate(schema, "hello world")
      assert {:error, errors} = Validator.validate(schema, "hi")
      assert [%{constraint: :min_length, message: "minimum length is 5"}] = errors
    end

    test "validates max_length constraint" do
      schema = Schema.string() |> Schema.max_length(10)
      assert {:ok, "hello"} = Validator.validate(schema, "hello")
      assert {:error, errors} = Validator.validate(schema, "hello world!")
      assert [%{constraint: :max_length}] = errors
    end

    test "validates pattern constraint" do
      schema = Schema.string() |> Schema.pattern(~r/^[A-Z]+$/)
      assert {:ok, "ABC"} = Validator.validate(schema, "ABC")
      assert {:error, errors} = Validator.validate(schema, "abc")
      assert [%{constraint: :pattern}] = errors
    end

    test "validates email constraint" do
      schema = Schema.string() |> Schema.email()
      assert {:ok, "test@example.com"} = Validator.validate(schema, "test@example.com")
      assert {:error, errors} = Validator.validate(schema, "not-an-email")
      assert [%{constraint: :email}] = errors
    end
  end

  describe "numeric constraints" do
    test "validates min constraint" do
      schema = Schema.integer() |> Schema.min(10)
      assert {:ok, 10} = Validator.validate(schema, 10)
      assert {:ok, 20} = Validator.validate(schema, 20)
      assert {:error, errors} = Validator.validate(schema, 5)
      assert [%{constraint: :min}] = errors
    end

    test "validates max constraint" do
      schema = Schema.integer() |> Schema.max(100)
      assert {:ok, 100} = Validator.validate(schema, 100)
      assert {:ok, 50} = Validator.validate(schema, 50)
      assert {:error, errors} = Validator.validate(schema, 101)
      assert [%{constraint: :max}] = errors
    end

    test "validates positive constraint" do
      schema = Schema.integer() |> Schema.positive()
      assert {:ok, 1} = Validator.validate(schema, 1)
      assert {:error, errors} = Validator.validate(schema, 0)
      assert [%{constraint: :positive}] = errors
      assert {:error, _} = Validator.validate(schema, -5)
    end

    test "validates range constraint" do
      schema = Schema.integer() |> Schema.range(10, 20)
      assert {:ok, 10} = Validator.validate(schema, 10)
      assert {:ok, 15} = Validator.validate(schema, 15)
      assert {:ok, 20} = Validator.validate(schema, 20)
      assert {:error, errors} = Validator.validate(schema, 5)
      assert [%{constraint: :range}] = errors
      assert {:error, _} = Validator.validate(schema, 25)
    end
  end

  describe "array validation" do
    test "validates array of primitives" do
      schema = Schema.array(Schema.string())
      assert {:ok, ["a", "b", "c"]} = Validator.validate(schema, ["a", "b", "c"])
      assert {:error, errors} = Validator.validate(schema, ["a", 123, "c"])
      assert length(errors) == 1
      assert [%{path: [1], constraint: :type}] = errors
    end

    test "validates array with element constraints" do
      schema = Schema.array(Schema.integer() |> Schema.positive())
      assert {:ok, [1, 2, 3]} = Validator.validate(schema, [1, 2, 3])
      assert {:error, errors} = Validator.validate(schema, [1, -2, 3])
      assert [%{path: [1], constraint: :positive}] = errors
    end

    test "validates array with length constraints" do
      schema = Schema.array(Schema.string()) |> Schema.min_length(2) |> Schema.max_length(5)
      assert {:ok, ["a", "b"]} = Validator.validate(schema, ["a", "b"])
      assert {:error, errors} = Validator.validate(schema, ["a"])
      assert [%{constraint: :min_length}] = errors
    end

    test "validates nested arrays" do
      schema = Schema.array(Schema.array(Schema.integer()))
      assert {:ok, [[1, 2], [3, 4]]} = Validator.validate(schema, [[1, 2], [3, 4]])
      assert {:error, _} = Validator.validate(schema, [[1, 2], [3, "four"]])
    end
  end

  describe "struct validation" do
    test "validates struct with valid data" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.integer()}
        ])

      assert {:ok, data} = Validator.validate(schema, %{name: "Alice", age: 30})
      assert data.name == "Alice"
      assert data.age == 30
    end

    test "validates struct with invalid field" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.integer()}
        ])

      assert {:error, errors} = Validator.validate(schema, %{name: "Alice", age: "thirty"})
      assert [%{path: [:age], constraint: :type}] = errors
    end

    test "validates nested structs" do
      address_schema =
        Schema.struct([
          {:city, Schema.string()},
          {:zip, Schema.string()}
        ])

      person_schema =
        Schema.struct([
          {:name, Schema.string()},
          {:address, address_schema}
        ])

      valid_data = %{name: "Alice", address: %{city: "Portland", zip: "97201"}}
      assert {:ok, _} = Validator.validate(person_schema, valid_data)

      invalid_data = %{name: "Alice", address: %{city: "Portland", zip: 97201}}
      assert {:error, errors} = Validator.validate(person_schema, invalid_data)
      assert [%{path: [:address], constraint: :type}] = errors
    end
  end

  describe "enum validation" do
    test "validates enum values" do
      schema = Schema.enum([:red, :green, :blue])
      assert {:ok, :red} = Validator.validate(schema, :red)
      assert {:error, errors} = Validator.validate(schema, :yellow)
      assert [%{constraint: :enum}] = errors
    end
  end

  describe "union validation" do
    test "validates union types" do
      schema = Schema.union([Schema.string(), Schema.integer()])
      assert {:ok, "hello"} = Validator.validate(schema, "hello")
      assert {:ok, 42} = Validator.validate(schema, 42)
      assert {:error, errors} = Validator.validate(schema, 3.14)
      assert [%{constraint: :union}] = errors
    end

    test "validates union with complex types" do
      schema1 = Schema.struct([{:type, Schema.enum([:a])}, {:value, Schema.string()}])
      schema2 = Schema.struct([{:type, Schema.enum([:b])}, {:value, Schema.integer()}])
      union_schema = Schema.union([schema1, schema2])

      assert {:ok, _} = Validator.validate(union_schema, %{type: :a, value: "test"})
      assert {:ok, _} = Validator.validate(union_schema, %{type: :b, value: 42})
      assert {:error, _} = Validator.validate(union_schema, %{type: :c, value: "test"})
    end
  end

  describe "optional and default" do
    test "validates optional fields" do
      schema = Schema.string() |> Schema.optional()
      assert {:ok, "hello"} = Validator.validate(schema, "hello")
      assert {:ok, nil} = Validator.validate(schema, nil)
    end

    test "applies default values" do
      schema = Schema.integer() |> Schema.default(42)
      assert {:ok, 10} = Validator.validate(schema, 10)
      assert {:ok, 42} = Validator.validate(schema, nil)
    end

    test "optional with default" do
      schema = Schema.string() |> Schema.optional() |> Schema.default("default")
      assert {:ok, "hello"} = Validator.validate(schema, "hello")
      assert {:ok, "default"} = Validator.validate(schema, nil)
    end
  end

  describe "multiple errors" do
    test "accumulates multiple constraint errors" do
      schema =
        Schema.string()
        |> Schema.min_length(5)
        |> Schema.max_length(10)
        |> Schema.pattern(~r/^[A-Z]+$/)

      assert {:error, errors} = Validator.validate(schema, "ab")
      # Should have min_length and pattern errors
      assert length(errors) == 2
    end

    test "accumulates errors across struct fields" do
      schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(3)},
          {:age, Schema.integer() |> Schema.positive()},
          {:email, Schema.string() |> Schema.email()}
        ])

      invalid_data = %{name: "ab", age: -5, email: "not-email"}
      assert {:error, errors} = Validator.validate(schema, invalid_data)
      assert length(errors) == 3
    end
  end
end
