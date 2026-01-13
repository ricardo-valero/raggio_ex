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
      schema = Schema.string(min: 5)

      try do
        Schema.validate!(schema, "hi")
      rescue
        e in Raggio.Schema.ValidationError ->
          assert is_list(e.errors)
          assert length(e.errors) > 0
          assert [%{constraint: :min}] = e.errors
      end
    end

    test "ValidationError message includes all errors" do
      schema =
        Schema.struct([
          {:name, Schema.string(min: 3)},
          {:age, Schema.integer(min: 1)}
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
      schema = Schema.string(min: 5)
      {:error, [error]} = Schema.validate(schema, "hi")

      assert is_list(error.path)
      assert is_binary(error.message)
      assert error.value == "hi"
      assert error.constraint == :min
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
      schema = Schema.list(Schema.integer())
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

      assert [%{path: [:address, :zip]}] = errors
    end

    test "error path includes deeply nested fields" do
      inner_schema = Schema.struct([{:value, Schema.integer()}])
      middle_schema = Schema.struct([{:inner, inner_schema}])
      outer_schema = Schema.struct([{:middle, middle_schema}])

      {:error, errors} =
        Schema.validate(outer_schema, %{middle: %{inner: %{value: "not an int"}}})

      assert [%{path: [:middle, :inner, :value]}] = errors
    end
  end

  describe "multiple errors" do
    test "accumulates multiple errors from different fields" do
      schema =
        Schema.struct([
          {:name, Schema.string(min: 3)},
          {:age, Schema.integer(min: 1)},
          {:email, Schema.string(pattern: Schema.email())}
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
      schema = Schema.string(min: 5, max: 10, pattern: ~r/^[A-Z]+$/)

      {:error, errors} = Schema.validate(schema, "ab")

      assert length(errors) >= 1
      constraints = Enum.map(errors, & &1.constraint)
      assert :min in constraints
    end

    test "accumulates errors from array elements" do
      schema = Schema.list(Schema.integer(min: 1))
      {:error, errors} = Schema.validate(schema, [1, -2, 3, -4, 5])

      assert length(errors) == 2

      error_paths = Enum.map(errors, & &1.path)
      assert [1] in error_paths
      assert [3] in error_paths
    end

    test "accumulates errors from nested structs" do
      address_schema =
        Schema.struct([
          {:city, Schema.string(min: 2)},
          {:zip, Schema.string(pattern: ~r/^\d{5}$/)}
        ])

      person_schema =
        Schema.struct([
          {:name, Schema.string(min: 2)},
          {:age, Schema.integer(min: 1)},
          {:address, address_schema}
        ])

      invalid_data = %{
        name: "A",
        age: -5,
        address: %{city: "P", zip: "ABCDE"}
      }

      {:error, errors} = Schema.validate(person_schema, invalid_data)

      assert length(errors) == 4
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
      assert path_string == "user.name"
    end

    test "formats array path with indices" do
      schema = Schema.list(Schema.integer())
      {:error, [error]} = Schema.validate(schema, [1, "two", 3])

      assert error.path == [1]
    end

    test "includes constraint type in error" do
      test_cases = [
        {Schema.string(min: 5), "hi", :min},
        {Schema.string(pattern: Schema.email()), "not-email", :pattern},
        {Schema.integer(min: 1), -5, :min},
        {Schema.literal(:a, :b), :c, :literal},
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
          {:name, Schema.string(min: 3)},
          {:age, Schema.integer(min: 1)}
        ])

      invalid_data = %{name: "ab", age: -5}
      assert {:error, errors} = Schema.validate(schema, invalid_data)
      assert length(errors) == 2

      partially_fixed = %{invalid_data | name: "Alice"}
      assert {:error, errors} = Schema.validate(schema, partially_fixed)
      assert length(errors) == 1

      valid_data = %{partially_fixed | age: 30}
      assert {:ok, _} = Schema.validate(schema, valid_data)
    end

    test "error messages are helpful for debugging" do
      schema = Schema.string(min: 5)
      {:error, [error]} = Schema.validate(schema, "hi")

      assert error.message =~ "5"
      assert error.constraint == :min
      assert error.value == "hi"
    end
  end
end
