defmodule Raggio.Schema.CompositionTest do
  use ExUnit.Case

  alias Raggio.Schema

  describe "pipe operator composition" do
    test "chains string constraints with pipe" do
      schema =
        Schema.string()
        |> Schema.min_length(3)
        |> Schema.max_length(10)

      assert {:ok, "hello"} = Schema.validate(schema, "hello")
      assert {:error, _} = Schema.validate(schema, "hi")
      assert {:error, _} = Schema.validate(schema, "hello world!")
    end

    test "chains numeric constraints with pipe" do
      schema =
        Schema.integer()
        |> Schema.positive()
        |> Schema.max(100)

      assert {:ok, 50} = Schema.validate(schema, 50)
      assert {:error, _} = Schema.validate(schema, -5)
      assert {:error, _} = Schema.validate(schema, 150)
    end

    test "chains optional and default" do
      schema =
        Schema.string()
        |> Schema.optional()
        |> Schema.default("N/A")

      assert {:ok, "hello"} = Schema.validate(schema, "hello")
      assert {:ok, "N/A"} = Schema.validate(schema, nil)
    end

    test "chains multiple string constraints" do
      schema =
        Schema.string()
        |> Schema.min_length(5)
        |> Schema.max_length(20)
        |> Schema.pattern(~r/^[a-zA-Z0-9_]+$/)

      assert {:ok, "valid_user123"} = Schema.validate(schema, "valid_user123")
      assert {:error, _} = Schema.validate(schema, "ab")
      # too short
      assert {:error, _} = Schema.validate(schema, "invalid-user!")
      # bad pattern
    end
  end

  describe "composition with structs" do
    test "composes schemas in struct fields" do
      username_schema =
        Schema.string()
        |> Schema.min_length(3)
        |> Schema.max_length(20)

      email_schema =
        Schema.string()
        |> Schema.email()

      user_schema =
        Schema.struct([
          {:username, username_schema},
          {:email, email_schema},
          {:age, Schema.integer() |> Schema.range(18, 120)}
        ])

      valid_user = %{username: "alice", email: "alice@example.com", age: 25}
      assert {:ok, _} = Schema.validate(user_schema, valid_user)

      invalid_user = %{username: "ab", email: "not-email", age: 15}
      assert {:error, errors} = Schema.validate(user_schema, invalid_user)
      assert length(errors) == 3
    end

    test "composes nested struct schemas" do
      address_schema =
        Schema.struct([
          {:city, Schema.string() |> Schema.min_length(2)},
          {:zip, Schema.string() |> Schema.pattern(~r/^\d{5}$/)}
        ])

      person_schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(2)},
          {:address, address_schema}
        ])

      valid_person = %{
        name: "Alice",
        address: %{city: "Portland", zip: "97201"}
      }

      assert {:ok, _} = Schema.validate(person_schema, valid_person)

      invalid_person = %{
        name: "A",
        address: %{city: "P", zip: "ABCDE"}
      }

      assert {:error, errors} = Schema.validate(person_schema, invalid_person)
      # name too short, city too short, zip invalid pattern
      assert length(errors) == 3
    end
  end

  describe "composition with arrays" do
    test "composes array element schemas" do
      email_schema = Schema.string() |> Schema.email()
      emails_schema = Schema.array(email_schema)

      valid_emails = ["alice@test.com", "bob@test.com"]
      assert {:ok, _} = Schema.validate(emails_schema, valid_emails)

      invalid_emails = ["alice@test.com", "invalid", "bob@test.com"]
      assert {:error, errors} = Schema.validate(emails_schema, invalid_emails)
      assert [%{path: [1]}] = errors
    end

    test "composes array with length constraints" do
      schema =
        Schema.array(Schema.integer() |> Schema.positive())
        |> Schema.min_length(2)
        |> Schema.max_length(5)

      assert {:ok, [1, 2, 3]} = Schema.validate(schema, [1, 2, 3])
      assert {:error, _} = Schema.validate(schema, [1])
      # too short
      assert {:error, _} = Schema.validate(schema, [1, 2, 3, 4, 5, 6])
      # too long
    end

    test "composes array of complex structs" do
      item_schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(1)},
          {:price, Schema.float() |> Schema.positive()}
        ])

      cart_schema = Schema.array(item_schema)

      valid_cart = [
        %{name: "Item 1", price: 9.99},
        %{name: "Item 2", price: 19.99}
      ]

      assert {:ok, _} = Schema.validate(cart_schema, valid_cart)

      invalid_cart = [
        %{name: "Item 1", price: 9.99},
        %{name: "", price: -5.0}
      ]

      assert {:error, errors} = Schema.validate(cart_schema, invalid_cart)
      assert length(errors) == 2
    end
  end

  describe "composition with union and enum" do
    test "composes enum in struct" do
      order_schema =
        Schema.struct([
          {:id, Schema.string()},
          {:status, Schema.enum([:pending, :shipped, :delivered])}
        ])

      assert {:ok, _} = Schema.validate(order_schema, %{id: "ORD-1", status: :pending})
      assert {:error, _} = Schema.validate(order_schema, %{id: "ORD-1", status: :cancelled})
    end

    test "composes union with constrained types" do
      string_id = Schema.string() |> Schema.pattern(~r/^[A-Z]{3}-\d{3}$/)
      integer_id = Schema.integer() |> Schema.positive()
      id_schema = Schema.union([string_id, integer_id])

      assert {:ok, "ABC-123"} = Schema.validate(id_schema, "ABC-123")
      assert {:ok, 42} = Schema.validate(id_schema, 42)
      assert {:error, _} = Schema.validate(id_schema, "invalid")
      assert {:error, _} = Schema.validate(id_schema, -5)
    end
  end

  describe "reusable schema composition" do
    setup do
      # Define reusable schemas
      username = Schema.string() |> Schema.min_length(3) |> Schema.max_length(20)
      email = Schema.string() |> Schema.email()
      password = Schema.string() |> Schema.min_length(8)

      {:ok, username: username, email: email, password: password}
    end

    test "reuses schemas across multiple structs", %{
      username: username,
      email: email,
      password: password
    } do
      registration_schema =
        Schema.struct([
          {:username, username},
          {:email, email},
          {:password, password}
        ])

      login_schema =
        Schema.struct([
          {:username, username},
          {:password, password}
        ])

      profile_schema =
        Schema.struct([
          {:username, username},
          {:email, email}
        ])

      # All should validate consistently
      valid_data = %{
        username: "alice",
        email: "alice@example.com",
        password: "securepass123"
      }

      assert {:ok, _} = Schema.validate(registration_schema, valid_data)
      assert {:ok, _} = Schema.validate(login_schema, Map.drop(valid_data, [:email]))
      assert {:ok, _} = Schema.validate(profile_schema, Map.drop(valid_data, [:password]))

      # All should reject bad username consistently
      invalid_username = %{valid_data | username: "ab"}
      assert {:error, _} = Schema.validate(registration_schema, invalid_username)
      assert {:error, _} = Schema.validate(login_schema, Map.drop(invalid_username, [:email]))

      assert {:error, _} =
               Schema.validate(profile_schema, Map.drop(invalid_username, [:password]))
    end
  end

  describe "complex composition patterns" do
    test "deeply nested composition" do
      coordinates_schema =
        Schema.struct([
          {:lat, Schema.float() |> Schema.range(-90.0, 90.0)},
          {:lng, Schema.float() |> Schema.range(-180.0, 180.0)}
        ])

      address_schema =
        Schema.struct([
          {:street, Schema.string() |> Schema.min_length(1)},
          {:city, Schema.string() |> Schema.min_length(1)},
          {:coordinates, coordinates_schema |> Schema.optional()}
        ])

      venue_schema =
        Schema.struct([
          {:name, Schema.string() |> Schema.min_length(1)},
          {:address, address_schema}
        ])

      valid_venue = %{
        name: "Conference Center",
        address: %{
          street: "123 Main St",
          city: "Portland",
          coordinates: %{lat: 45.5152, lng: -122.6784}
        }
      }

      assert {:ok, _} = Schema.validate(venue_schema, valid_venue)

      # Invalid coordinates should be caught
      invalid_venue = %{
        name: "Conference Center",
        address: %{
          street: "123 Main St",
          city: "Portland",
          coordinates: %{lat: 100.0, lng: -200.0}
        }
      }

      assert {:error, errors} = Schema.validate(venue_schema, invalid_venue)
      assert length(errors) == 2
    end

    test "composition with multiple constraint violations" do
      schema =
        Schema.string()
        |> Schema.min_length(5)
        |> Schema.max_length(10)
        |> Schema.pattern(~r/^[A-Z]+$/)

      # Should fail multiple constraints
      assert {:error, errors} = Schema.validate(schema, "ab")
      # Too short + wrong pattern
      assert length(errors) >= 1
    end
  end

  describe "composition error prevention" do
    test "raises error when composing incompatible types" do
      assert_raise Raggio.Schema.CompositionError, fn ->
        Schema.integer() |> Schema.email()
      end

      assert_raise Raggio.Schema.CompositionError, fn ->
        Schema.string() |> Schema.positive()
      end

      assert_raise Raggio.Schema.CompositionError, fn ->
        Schema.boolean() |> Schema.min_length(5)
      end
    end

    test "allows composition of compatible constraints" do
      # These should not raise
      assert %Schema{} = Schema.string() |> Schema.min_length(5) |> Schema.max_length(10)
      assert %Schema{} = Schema.integer() |> Schema.min(10) |> Schema.max(100)
      assert %Schema{} = Schema.float() |> Schema.positive() |> Schema.max(100.0)
    end
  end
end
