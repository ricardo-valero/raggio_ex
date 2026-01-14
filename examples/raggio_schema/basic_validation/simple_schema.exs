alias Raggio.Schema

user_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:age, Schema.integer()}
  ])

valid_user = %{name: "Alice", age: 30}

case Schema.validate(user_schema, valid_user) do
  {:ok, data} ->
    IO.puts("Valid: #{inspect(data)}")

  {:error, errors} ->
    IO.puts("Invalid: #{inspect(errors)}")
end

invalid_user = %{name: "Bob", age: "not a number"}

case Schema.validate(user_schema, invalid_user) do
  {:ok, data} ->
    IO.puts("Valid: #{inspect(data)}")

  {:error, errors} ->
    IO.puts("Invalid:")

    Enum.each(errors, fn err ->
      path = Enum.join(err.path, ".")
      IO.puts("  #{path}: #{err.message}")
    end)
end
