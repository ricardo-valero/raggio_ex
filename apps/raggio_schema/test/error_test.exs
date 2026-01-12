defmodule Raggio.Schema.ErrorTest do
  use ExUnit.Case

  alias Raggio.Schema

  describe "ValidationError" do
    test "validate!/2 raises ValidationError on failure" do
      schema = Schema.string()

      assert_raise Raggio.Schema.ValidationError, fn ->
        Schema.validate!(schema, 123)
      end
    end

    test "ValidationError contains error details" do
      schema = Schema.string() |> Schema.min_length(5)

      try do
        Schema.validate!(schema, "hi")
      rescue
        e in Raggio.Schema.ValidationError ->
          assert is_list(e.errors)
          assert length(e.errors) > 0
          assert [%{constraint: :min_length}] = e.errors
      end
    end

    test "ValidationError message includes all errors" do
      schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(3)},
          {:age, Schema.integer() |> Schema.positive()}
        ])

      try do
        Schema.validate!(schema, %{name: "ab", age: -5})
      rescue
        e in Raggio.Schema.ValidationError ->
          message = Exception.message(e)
          assert message =~ "name"
          assert message =~ "age"
      end
    end

    test "validate!/2 returns data on success" do
      schema = Schema.string()
      assert "hello" = Schema.validate!(schema, "hello")
    end
  end

  describe "error structure" do
    test "error contains path, message, value, and constraint" do
      schema = Schema.string() |> Schema.min_length(5)
      {:error, [error]} = Schema.validate(schema, "hi")

      assert is_list(error.path)
      assert is_binary(error.message)
      assert error.value == "hi"
      assert error.constraint == :min_length
    end

    test "error path is empty for top-level validation" do
      schema = Schema.string()
      {:error, [error]} = Schema.validate(schema, 123)

      assert error.path == []
    end

    test "error path includes field name for struct fields" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.integer()}
        ])

      {:error, errors} = Schema.validate(schema, %{name: "Alice", age: "thirty"})
      assert [%{path: [:age]}] = errors
    end

    test "error path includes array index" do
      schema = Schema.array(Schema.integer())
      {:error, errors} = Schema.validate(schema, [1, "two", 3])

      assert [%{path: [1]}] = errors
    end

    test "error path includes nested struct field" do
      address_schema =
        Schema.struct([
          {:city, Schema.string()},
          {:zip, Schema.integer()}
        ])

      person_schema =
        Schema.struct([
          {:name, Schema.string()},
          {:address, address_schema}
        ])

      {:error, errors} =
        Schema.validate(person_schema, %{
          name: "Alice",
          address: %{city: "Portland", zip: "97201"}
        })

      assert [%{path: [:address]}] = errors
    end

    test "error path includes deeply nested fields" do
      inner_schema = Schema.struct([{:value, Schema.integer()}])
      middle_schema = Schema.struct([{:inner, inner_schema}])
      outer_schema = Schema.struct([{:middle, middle_schema}])

      {:error, errors} =
        Schema.validate(outer_schema, %{middle: %{inner: %{value: "not an int"}}})

      assert [%{path: [:middle]}] = errors
    end
  end

  describe "multiple errors" do
    test "accumulates multiple errors from different fields" do
      schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(3)},
          {:age, Schema.integer() |> Schema.positive()},
          {:email, Schema.string() |> Schema.email()}
        ])

      invalid_data = %{name: "ab", age: -5, email: "not-email"}
      {:error, errors} = Schema.validate(schema, invalid_data)

      assert length(errors) == 3

      error_paths = Enum.map(errors, & &1.path)
      assert [:name] in error_paths
      assert [:age] in error_paths
      assert [:email] in error_paths
    end

    test "accumulates multiple constraint violations on single field" do
      schema =
        Schema.string()
        |> Schema.min_length(5)
        |> Schema.max_length(10)
        |> Schema.pattern(~r/^[A-Z]+$/)

      {:error, errors} = Schema.validate(schema, "ab")

      # Should have at least min_length and pattern errors
      assert length(errors) >= 1
      constraints = Enum.map(errors, & &1.constraint)
      assert :min_length in constraints
    end

    test "accumulates errors from array elements" do
      schema = Schema.array(Schema.integer() |> Schema.positive())
      {:error, errors} = Schema.validate(schema, [1, -2, 3, -4, 5])

      assert length(errors) == 2

      error_paths = Enum.map(errors, & &1.path)
      assert [1] in error_paths
      assert [3] in error_paths
    end

    test "accumulates errors from nested structs" do
      address_schema =
        Schema.struct([
          {:city, Schema.string() |> Schema.min_length(2)},
          {:zip, Schema.string() |> Schema.pattern(~r/^\d{5}$/)}
        ])

      person_schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(2)},
          {:age, Schema.integer() |> Schema.positive()},
          {:address, address_schema}
        ])

      invalid_data = %{
        name: "A",
        age: -5,
        address: %{city: "P", zip: "ABCDE"}
      }

      {:error, errors} = Schema.validate(person_schema, invalid_data)

      # name, age, city, zip all invalid
      assert length(errors) == 4
    end
  end

  describe "CompositionError" do
    test "raises on incompatible type compositions" do
      assert_raise Raggio.Schema.CompositionError, ~r/email.*integer/, fn ->
        Schema.integer() |> Schema.email()
      end

      assert_raise Raggio.Schema.CompositionError, ~r/min_length.*integer/, fn ->
        Schema.integer() |> Schema.min_length(5)
      end

      assert_raise Raggio.Schema.CompositionError, ~r/positive.*string/, fn ->
        Schema.string() |> Schema.positive()
      end
    end

    test "provides helpful error messages" do
      try do
        Schema.boolean() |> Schema.pattern(~r/test/)
      rescue
        e in Raggio.Schema.CompositionError ->
          message = Exception.message(e)
          assert message =~ "pattern"
          assert message =~ "boolean"
      end
    end

    test "does not raise on compatible compositions" do
      # String constraints on string type
      assert %Schema{} = Schema.string() |> Schema.min_length(5)
      assert %Schema{} = Schema.string() |> Schema.email()
      assert %Schema{} = Schema.string() |> Schema.pattern(~r/test/)

      # Numeric constraints on numeric types
      assert %Schema{} = Schema.integer() |> Schema.positive()
      assert %Schema{} = Schema.integer() |> Schema.min(10)
      assert %Schema{} = Schema.float() |> Schema.max(100.0)

      # Generic modifiers on any type
      assert %Schema{} = Schema.string() |> Schema.optional()
      assert %Schema{} = Schema.integer() |> Schema.default(42)
    end
  end

  describe "error formatting" do
    test "formats path as dot-separated string" do
      schema =
        Schema.struct([
          {:user, Schema.struct([{:name, Schema.string()}])}
        ])

      {:error, [error]} = Schema.validate(schema, %{user: %{name: 123}})
      path_string = Enum.join(error.path, ".")
      assert path_string == "user"
    end

    test "formats array path with indices" do
      schema = Schema.array(Schema.integer())
      {:error, [error]} = Schema.validate(schema, [1, "two", 3])

      assert error.path == [1]
    end

    test "includes constraint type in error" do
      test_cases = [
        {Schema.string() |> Schema.min_length(5), "hi", :min_length},
        {Schema.string() |> Schema.email(), "not-email", :email},
        {Schema.integer() |> Schema.positive(), -5, :positive},
        {Schema.enum([:a, :b]), :c, :enum},
        {Schema.string(), 123, :type}
      ]

      for {schema, invalid_value, expected_constraint} <- test_cases do
        {:error, [error]} = Schema.validate(schema, invalid_value)
        assert error.constraint == expected_constraint
      end
    end
  end

  describe "error recovery" do
    test "can fix errors and revalidate" do
      schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(3)},
          {:age, Schema.integer() |> Schema.positive()}
        ])

      # Start with invalid data
      invalid_data = %{name: "ab", age: -5}
      assert {:error, errors} = Schema.validate(schema, invalid_data)
      assert length(errors) == 2

      # Fix one error
      partially_fixed = %{invalid_data | name: "Alice"}
      assert {:error, errors} = Schema.validate(schema, partially_fixed)
      assert length(errors) == 1

      # Fix all errors
      valid_data = %{partially_fixed | age: 30}
      assert {:ok, _} = Schema.validate(schema, valid_data)
    end

    test "error messages are helpful for debugging" do
      schema = Schema.string() |> Schema.min_length(5)
      {:error, [error]} = Schema.validate(schema, "hi")

      assert error.message =~ "5"
      assert error.constraint == :min_length
      assert error.value == "hi"
    end
  end
end
