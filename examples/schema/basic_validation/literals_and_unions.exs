alias Raggio.Schema

status_schema = Schema.literal(:pending, :approved, :rejected)

response_schema =
  Schema.union([
    Schema.struct([
      {:type, Schema.literal(:success)},
      {:data, Schema.string()}
    ]),
    Schema.struct([
      {:type, Schema.literal(:error)},
      {:message, Schema.string()}
    ])
  ])

IO.puts("=== Literals and Unions ===\n")

IO.puts("Literal type validation:")

Enum.each([:pending, :approved, :invalid], fn status ->
  case Schema.validate(status_schema, status) do
    {:ok, _} -> IO.puts("  #{inspect(status)} - valid")
    {:error, _} -> IO.puts("  #{inspect(status)} - invalid")
  end
end)

IO.puts("\nUnion type validation:")

success_response = %{type: :success, data: "User created"}
error_response = %{type: :error, message: "Not found"}
invalid_response = %{type: :unknown, foo: "bar"}

Enum.each([success_response, error_response, invalid_response], fn response ->
  case Schema.validate(response_schema, response) do
    {:ok, _} -> IO.puts("  #{inspect(response)} - matches union")
    {:error, _} -> IO.puts("  #{inspect(response)} - no match")
  end
end)
