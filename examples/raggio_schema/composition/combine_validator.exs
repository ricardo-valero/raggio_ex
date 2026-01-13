alias Raggio.Schema

username_schema = Schema.string(min: 3, max: 20, pattern: ~r/^[a-zA-Z0-9_]+$/)

IO.puts("Testing username validation with composed validators:")

case Schema.validate(username_schema, "alice_123") do
  {:ok, _} -> IO.puts("'alice_123' is valid")
  {:error, _} -> IO.puts("'alice_123' is invalid")
end

case Schema.validate(username_schema, "ab") do
  {:ok, _} -> IO.puts("'ab' is valid")
  {:error, errors} -> IO.puts("'ab' is invalid: #{hd(errors).message}")
end

case Schema.validate(username_schema, "alice@test") do
  {:ok, _} -> IO.puts("'alice@test' is valid")
  {:error, errors} -> IO.puts("'alice@test' is invalid: #{hd(errors).message}")
end

email_schema = Schema.string(pattern: Schema.email())

IO.puts("\nTesting email validation:")

case Schema.validate(email_schema, "alice@example.com") do
  {:ok, _} -> IO.puts("'alice@example.com' is valid")
  {:error, _} -> IO.puts("'alice@example.com' is invalid")
end

case Schema.validate(email_schema, "not-an-email") do
  {:ok, _} -> IO.puts("'not-an-email' is valid")
  {:error, errors} -> IO.puts("'not-an-email' is invalid: #{hd(errors).message}")
end
