alias Raggio.Schema

defmodule CustomTypes do
  alias Raggio.Schema

  def username do
    Schema.string(min: 3, max: 20, pattern: ~r/^[a-zA-Z0-9_]+$/)
  end

  def us_phone do
    Schema.string(pattern: ~r/^\d{3}-\d{3}-\d{4}$/)
  end

  def price do
    Schema.float(min: 0.01)
  end

  def adult_age do
    Schema.integer(min: 18, max: 120)
  end

  def strong_password do
    Schema.string(min: 8)
  end

  def us_zipcode do
    Schema.string(pattern: ~r/^\d{5}(-\d{4})?$/)
  end
end

IO.puts("Example 1: User registration with custom types")
IO.puts("===============================================")

user_schema =
  Schema.struct([
    {:username, CustomTypes.username()},
    {:email, Schema.string(pattern: Schema.email())},
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
    IO.puts("User validation passed")
    IO.inspect(data, label: "Valid user")

  {:error, errors} ->
    IO.puts("Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample 2: Product schema with custom types")
IO.puts("=============================================")

product_schema =
  Schema.struct([
    {:name, Schema.string(min: 3)},
    {:price, CustomTypes.price()},
    {:quantity, Schema.integer(min: 1)}
  ])

valid_product = %{
  name: "Laptop",
  price: 999.99,
  quantity: 10
}

case Schema.validate(product_schema, valid_product) do
  {:ok, data} ->
    IO.puts("Product validation passed")
    IO.inspect(data, label: "Valid product")

  {:error, errors} ->
    IO.puts("Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

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
    IO.puts("Contact validation passed")
    IO.inspect(data, label: "Valid contact")

  {:error, errors} ->
    IO.puts("Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample 4: Invalid data with custom types")
IO.puts("==========================================")

invalid_contact = %{
  name: "Charlie",
  phone: "1234567890",
  zipcode: "ABCDE"
}

case Schema.validate(contact_schema, invalid_contact) do
  {:ok, _} ->
    IO.puts("Validation passed")

  {:error, errors} ->
    IO.puts("Validation failed (expected):")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample completed successfully")
