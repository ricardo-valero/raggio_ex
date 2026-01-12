# Combining Validators Example
#
# This example demonstrates composing validators using the pipe operator

Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Create a constrained string schema by chaining validators
username_schema =
  Schema.string()
  |> Schema.min_length(3)
  |> Schema.max_length(20)
  |> Schema.pattern(~r/^[a-zA-Z0-9_]+$/)

IO.puts("Testing username validation with composed validators:")

# Valid username
case Schema.validate(username_schema, "alice_123") do
  {:ok, _} -> IO.puts("✓ 'alice_123' is valid")
  {:error, _} -> IO.puts("✗ 'alice_123' is invalid")
end

# Too short
case Schema.validate(username_schema, "ab") do
  {:ok, _} -> IO.puts("✓ 'ab' is valid")
  {:error, errors} -> IO.puts("✗ 'ab' is invalid: #{hd(errors).message}")
end

# Invalid characters
case Schema.validate(username_schema, "alice@test") do
  {:ok, _} -> IO.puts("✓ 'alice@test' is valid")
  {:error, errors} -> IO.puts("✗ 'alice@test' is invalid: #{hd(errors).message}")
end

# Email schema with composition
email_schema = Schema.string() |> Schema.email()

IO.puts("\nTesting email validation:")

case Schema.validate(email_schema, "alice@example.com") do
  {:ok, _} -> IO.puts("✓ 'alice@example.com' is valid")
  {:error, _} -> IO.puts("✗ 'alice@example.com' is invalid")
end

case Schema.validate(email_schema, "not-an-email") do
  {:ok, _} -> IO.puts("✓ 'not-an-email' is valid")
  {:error, errors} -> IO.puts("✗ 'not-an-email' is invalid: #{hd(errors).message}")
end
