alias Raggio.Schema

user_schema =
  Schema.struct([
    {:name, Schema.string(min: 1, max: 100)},
    {:age, Schema.integer(min: 0, max: 150)},
    {:email, Schema.string(pattern: Schema.email())}
  ])

valid_user = %{
  name: "Alice",
  age: 30,
  email: "alice@example.com"
}

invalid_user = %{
  name: "",
  age: -5,
  email: "not-an-email"
}

IO.puts("=== Simple Schema Validation ===\n")

case Schema.validate(user_schema, valid_user) do
  {:ok, data} -> IO.puts("Valid user: #{inspect(data)}")
  {:error, errors} -> IO.puts("Errors: #{inspect(errors)}")
end

IO.puts("")

case Schema.validate(user_schema, invalid_user) do
  {:ok, data} ->
    IO.puts("Valid user: #{inspect(data)}")

  {:error, errors} ->
    IO.puts("Validation failed with #{length(errors)} error(s):")

    Enum.each(errors, fn err ->
      IO.puts("  - #{inspect(err.path)}: #{err.message}")
    end)
end
