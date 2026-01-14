alias Raggio.Schema

schema =
  Schema.struct([
    {:name, Schema.string(min: 3)},
    {:count, Schema.integer(min: 0, max: 100)},
    {:status, Schema.literal(:active, :inactive, :pending)}
  ])

invalid_data = %{
  name: "AB",
  count: 150,
  status: :unknown
}

IO.puts("=== Validation Error Structure ===\n")

case Schema.validate(schema, invalid_data, mode: :all_errors) do
  {:ok, _} ->
    IO.puts("Unexpectedly valid")

  {:error, errors} ->
    IO.puts("Collected #{length(errors)} error(s):\n")

    Enum.each(errors, fn error ->
      IO.puts("Path:       #{inspect(error.path)}")
      IO.puts("Message:    #{error.message}")
      IO.puts("Value:      #{inspect(error.value)}")
      IO.puts("Constraint: #{inspect(error.constraint)}")
      IO.puts("")
    end)
end
