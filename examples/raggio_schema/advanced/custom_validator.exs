# Custom Validator Composition Example
# Demonstrates US4: Extending functionality through composition

# This example shows how to create custom validators using
# Raggio.Schema's composable API without modifying the library.

alias Raggio.Schema

# =============================================================================
# Example 1: Custom Validators as Functions
# =============================================================================

IO.puts("Example 1: Custom Validator Functions")
IO.puts("======================================\n")

# Define a custom validator that checks business rules
defmodule CustomValidators do
  alias Raggio.Schema

  @doc """
  Validates that a string contains at least one uppercase letter.
  Uses pattern constraint with composition.
  """
  def has_uppercase do
    Schema.string(pattern: ~r/[A-Z]/)
  end

  @doc """
  Validates that a string contains at least one digit.
  """
  def has_digit do
    Schema.string(pattern: ~r/[0-9]/)
  end

  @doc """
  Validates that a string contains at least one special character.
  """
  def has_special do
    Schema.string(pattern: ~r/[!@#$%^&*(),.?":{}|<>]/)
  end

  @doc """
  Strong password: min 8 chars, has uppercase, digit, and special char.
  Compose by using union to validate all rules.
  Note: This is a simplified approach - all checks must pass.
  """
  def strong_password do
    # For strong password, we need ALL constraints to pass.
    # We use a pattern that requires all components.
    Schema.string(
      min: 8,
      pattern: ~r/^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*(),.?":{}|<>]).+$/
    )
  end

  @doc """
  Email with specific domain restriction.
  """
  def corporate_email(domain) do
    Schema.string(pattern: ~r/^[a-zA-Z0-9._%+-]+@#{domain}$/)
  end

  @doc """
  US phone number with area code.
  """
  def us_phone do
    Schema.string(pattern: ~r/^\(\d{3}\) \d{3}-\d{4}$/)
  end

  @doc """
  Credit card number (simple pattern - 16 digits with optional dashes).
  """
  def credit_card do
    Schema.string(pattern: ~r/^\d{4}(-?\d{4}){3}$/)
  end
end

# Test strong password validator
password_schema = CustomValidators.strong_password()

test_passwords = [
  {"Pass123!", true},
  {"password", false},
  {"PASSWORD123", false},
  {"Pass!", false}
]

Enum.each(test_passwords, fn {password, expected_valid} ->
  result = Schema.validate(password_schema, password)

  case {result, expected_valid} do
    {{:ok, _}, true} ->
      IO.puts("  '#{password}' - Valid (expected)")

    {{:error, _}, false} ->
      IO.puts("  '#{password}' - Invalid (expected)")

    {{:ok, _}, false} ->
      IO.puts("  '#{password}' - Valid (UNEXPECTED!)")

    {{:error, errors}, true} ->
      IO.puts("  '#{password}' - Invalid (UNEXPECTED!): #{hd(errors).message}")
  end
end)

# =============================================================================
# Example 2: Schema Composition with Custom Types
# =============================================================================

IO.puts("\n\nExample 2: Schema Composition with Custom Types")
IO.puts("================================================\n")

# Create a user registration schema with custom validators
user_registration_schema =
  Schema.struct([
    {:username, Schema.string(min: 3, max: 20, pattern: ~r/^[a-zA-Z0-9_]+$/)},
    {:email, CustomValidators.corporate_email("example.com")},
    {:password, CustomValidators.strong_password()},
    {:phone, Schema.optional(CustomValidators.us_phone())}
  ])

# Valid registration
valid_user = %{
  username: "alice_smith",
  email: "alice@example.com",
  password: "Secure123!",
  phone: "(503) 555-1234"
}

case Schema.validate(user_registration_schema, valid_user) do
  {:ok, data} ->
    IO.puts("Valid user registration:")
    IO.inspect(data, pretty: true)

  {:error, errors} ->
    IO.puts("Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Invalid registration
IO.puts("\nTesting invalid registration:")

invalid_user = %{
  username: "ab",
  email: "alice@gmail.com",
  password: "weak"
}

case Schema.validate(user_registration_schema, invalid_user) do
  {:ok, _} ->
    IO.puts("Validation passed (unexpected)")

  {:error, errors} ->
    IO.puts("Validation failed (expected):")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# =============================================================================
# Example 3: Reusable Nested Validators
# =============================================================================

IO.puts("\n\nExample 3: Reusable Nested Validators")
IO.puts("======================================\n")

# Address validator that can be reused
defmodule AddressValidators do
  alias Raggio.Schema

  def us_address do
    Schema.struct([
      {:street, Schema.string(min: 5)},
      {:city, Schema.string(min: 2)},
      {:state, Schema.string(pattern: ~r/^[A-Z]{2}$/)},
      {:zip, Schema.string(pattern: ~r/^\d{5}(-\d{4})?$/)}
    ])
  end

  def international_address do
    Schema.struct([
      {:street, Schema.string(min: 5)},
      {:city, Schema.string(min: 2)},
      {:country_code, Schema.string(pattern: ~r/^[A-Z]{2}$/)},
      {:postal_code, Schema.string(min: 3, max: 10)}
    ])
  end
end

# Customer schema using reusable address validator
customer_schema =
  Schema.struct([
    {:name, Schema.string(min: 2)},
    {:billing_address, AddressValidators.us_address()},
    {:shipping_address, Schema.optional(AddressValidators.us_address())}
  ])

valid_customer = %{
  name: "Bob Jones",
  billing_address: %{
    street: "123 Main St",
    city: "Portland",
    state: "OR",
    zip: "97201"
  }
}

case Schema.validate(customer_schema, valid_customer) do
  {:ok, data} ->
    IO.puts("Valid customer:")
    IO.inspect(data, pretty: true)

  {:error, errors} ->
    IO.puts("Validation failed:")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\n\nCustom validator composition complete!")
