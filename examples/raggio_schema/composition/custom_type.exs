# Example: Custom type patterns using composition
# Demonstrates creating reusable domain-specific types

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Custom type builders as functions
defmodule CustomTypes do
  alias Raggio.Schema

  @doc "A username is a string with specific constraints"
  def username do
    Schema.string()
    |> Schema.min_length(3)
    |> Schema.max_length(20)
    |> Schema.pattern(~r/^[a-zA-Z0-9_]+$/)
  end

  @doc "A phone number in US format"
  def us_phone do
    Schema.string()
    |> Schema.pattern(~r/^\d{3}-\d{3}-\d{4}$/)
  end

  @doc "A positive price with up to 2 decimal places"
  def price do
    Schema.float()
    |> Schema.positive()
  end

  @doc "An age for adults only"
  def adult_age do
    Schema.integer()
    |> Schema.range(18, 120)
  end

  @doc "A strong password"
  def strong_password do
    Schema.string()
    |> Schema.min_length(8)
  end

  @doc "A US zip code"
  def us_zipcode do
    Schema.string()
    |> Schema.pattern(~r/^\d{5}(-\d{4})?$/)
  end
end

# Use custom types in schemas
IO.puts("Example 1: User registration with custom types")
IO.puts("===============================================")

user_schema =
  Schema.struct([
    {:username, CustomTypes.username()},
    {:email, Schema.string() |> Schema.email()},
    {:age, CustomTypes.adult_age()},
    {:password, CustomTypes.strong_password()}
  ])

valid_user = %{
  username: "alice_2024",
  email: "alice@example.com",
  age: 25,
  password: "SecurePass123"
}

case Schema.validate(user_schema, valid_user) do
  {:ok, data} ->
    IO.puts("✓ User validation passed")
    IO.inspect(data, label: "Valid user")

  {:error, errors} ->
    IO.puts("✗ Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Product schema with custom types
IO.puts("\nExample 2: Product schema with custom types")
IO.puts("=============================================")

product_schema =
  Schema.struct([
    {:name, Schema.string() |> Schema.min_length(3)},
    {:price, CustomTypes.price()},
    {:quantity, Schema.integer() |> Schema.positive()}
  ])

valid_product = %{
  name: "Laptop",
  price: 999.99,
  quantity: 10
}

case Schema.validate(product_schema, valid_product) do
  {:ok, data} ->
    IO.puts("✓ Product validation passed")
    IO.inspect(data, label: "Valid product")

  {:error, errors} ->
    IO.puts("✗ Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Contact info with custom types
IO.puts("\nExample 3: Contact info with custom phone and zip")
IO.puts("===================================================")

contact_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:phone, CustomTypes.us_phone()},
    {:zipcode, CustomTypes.us_zipcode()}
  ])

valid_contact = %{
  name: "Bob Smith",
  phone: "503-555-1234",
  zipcode: "97201"
}

case Schema.validate(contact_schema, valid_contact) do
  {:ok, data} ->
    IO.puts("✓ Contact validation passed")
    IO.inspect(data, label: "Valid contact")

  {:error, errors} ->
    IO.puts("✗ Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Invalid examples
IO.puts("\nExample 4: Invalid data with custom types")
IO.puts("==========================================")

invalid_contact = %{
  name: "Charlie",
  phone: "1234567890",
  # wrong format
  zipcode: "ABCDE"
  # not a valid zip
}

case Schema.validate(contact_schema, invalid_contact) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Validation failed (expected):")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\n✓ Example completed successfully")
