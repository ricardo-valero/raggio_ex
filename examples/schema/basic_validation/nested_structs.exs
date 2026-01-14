alias Raggio.Schema

address_schema =
  Schema.struct([
    {:street, Schema.string(min: 1)},
    {:city, Schema.string(min: 1)},
    {:zip, Schema.string(pattern: ~r/^\d{5}$/)}
  ])

person_schema =
  Schema.struct([
    {:name, Schema.string(min: 1)},
    {:address, address_schema}
  ])

valid_person = %{
  name: "Bob",
  address: %{
    street: "123 Main St",
    city: "Springfield",
    zip: "12345"
  }
}

invalid_person = %{
  name: "Bob",
  address: %{
    street: "",
    city: "Springfield",
    zip: "invalid"
  }
}

IO.puts("=== Nested Struct Validation ===\n")

IO.puts("Valid nested data:")

case Schema.validate(person_schema, valid_person) do
  {:ok, data} -> IO.puts("  Success: #{inspect(data)}")
  {:error, errors} -> IO.puts("  Errors: #{inspect(errors)}")
end

IO.puts("\nInvalid nested data:")

case Schema.validate(person_schema, invalid_person, mode: :all_errors) do
  {:ok, _} ->
    IO.puts("  Unexpectedly valid")

  {:error, errors} ->
    Enum.each(errors, fn err ->
      path_str = err.path |> Enum.map(&to_string/1) |> Enum.join(".")
      IO.puts("  - #{path_str}: #{err.message}")
    end)
end
