alias Raggio.Schema

user_schema =
  Schema.struct([
    {:username, Schema.string(min: 3, max: 20)},
    {:email, Schema.string(pattern: Schema.email())},
    {:age, Schema.integer(min: 18, max: 120)},
    {:password, Schema.string(min: 8)}
  ])

invalid_user = %{
  username: "ab",
  email: "not-an-email",
  age: 15,
  password: "short"
}

IO.puts("Collecting multiple validation errors:")

case Schema.validate(user_schema, invalid_user) do
  {:ok, data} ->
    IO.puts("Passed")
    IO.inspect(data)

  {:error, errors} ->
    IO.puts("Failed with #{length(errors)} error(s):")

    Enum.each(errors, fn err ->
      path = if err.path == [], do: "root", else: Enum.join(err.path, ".")
      IO.puts("  #{path}: #{err.message} (#{err.constraint})")
    end)
end

IO.puts("\nUsing validate!/2:")

try do
  Schema.validate!(user_schema, invalid_user)
rescue
  e in Raggio.Schema.ValidationError ->
    IO.puts("Caught ValidationError: #{length(e.errors)} errors")
end

fixed_user = %{
  username: "alice_wonder",
  email: "alice@example.com",
  age: 25,
  password: "secure_password_123"
}

IO.puts("\nAfter fixing:")
IO.inspect(Schema.validate(user_schema, fixed_user))
