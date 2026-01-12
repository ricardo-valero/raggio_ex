# Example: Error handling patterns
# Demonstrates different ways to handle validation errors

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Define a complex user schema with multiple constraints
user_schema =
  Schema.struct([
    {:username, Schema.string() |> Schema.min_length(3) |> Schema.max_length(20)},
    {:email, Schema.string() |> Schema.email()},
    {:age, Schema.integer() |> Schema.range(18, 120)},
    {:password, Schema.string() |> Schema.min_length(8)}
  ])

# Invalid data with multiple errors
invalid_user = %{
  username: "ab",
  # too short
  email: "not-an-email",
  # invalid format
  age: 15,
  # too young
  password: "short"
  # too short
}

IO.puts("Example 1: Collecting multiple validation errors")
IO.puts("================================================")

case Schema.validate(user_schema, invalid_user) do
  {:ok, data} ->
    IO.puts("✓ Validation passed")
    IO.inspect(data)

  {:error, errors} ->
    IO.puts("✗ Validation failed with #{length(errors)} error(s):\n")

    Enum.each(errors, fn err ->
      path = if err.path == [], do: "root", else: Enum.join(err.path, ".")
      IO.puts("  • #{path}: #{err.message}")
      IO.puts("    Value: #{inspect(err.value)}")
      IO.puts("    Constraint: #{err.constraint}\n")
    end)
end

# Using validate!/2 for exceptions
IO.puts("\nExample 2: Using validate!/2 (raises exception)")
IO.puts("================================================")

try do
  Schema.validate!(user_schema, invalid_user)
  IO.puts("✓ Validation passed")
rescue
  e in Raggio.Schema.ValidationError ->
    IO.puts("✗ Caught ValidationError exception:")
    IO.puts("   Message: #{Exception.message(e)}")
    IO.puts("   Error count: #{length(e.errors)}")
end

# Programmatically handling specific errors
IO.puts("\nExample 3: Pattern matching on specific error paths")
IO.puts("====================================================")

case Schema.validate(user_schema, invalid_user) do
  {:ok, _} ->
    IO.puts("✓ Valid")

  {:error, errors} ->
    # Group errors by field
    errors_by_field = Enum.group_by(errors, fn err -> List.first(err.path) end)

    IO.puts("Errors grouped by field:")

    Enum.each(errors_by_field, fn {field, field_errors} ->
      messages = Enum.map(field_errors, & &1.message)
      IO.puts("  #{field}: #{Enum.join(messages, ", ")}")
    end)
end

# Valid user after fixing errors
IO.puts("\nExample 4: Fixing errors and revalidating")
IO.puts("==========================================")

fixed_user = %{
  username: "alice_wonder",
  email: "alice@example.com",
  age: 25,
  password: "secure_password_123"
}

case Schema.validate(user_schema, fixed_user) do
  {:ok, data} ->
    IO.puts("✓ All errors fixed! Validation passed")
    IO.inspect(data, label: "Valid user")

  {:error, errors} ->
    IO.puts("✗ Still have errors:")
    IO.inspect(errors)
end

IO.puts("\n✓ Example completed successfully")
