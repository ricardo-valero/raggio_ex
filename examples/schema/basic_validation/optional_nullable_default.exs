alias Raggio.Schema

config_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:description, Schema.string() |> Schema.optional()},
    {:count, Schema.integer() |> Schema.nullable()},
    {:enabled, Schema.boolean(true)}
  ])

IO.puts("=== Optional, Nullable, and Default Values ===\n")

minimal_data = %{name: "Test"}
IO.puts("Minimal data (only required field):")

case Schema.validate(config_schema, minimal_data) do
  {:ok, data} -> IO.puts("  Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("  Errors: #{inspect(errors)}")
end

with_nil = %{name: "Test", count: nil}
IO.puts("\nWith explicit nil on nullable field:")

case Schema.validate(config_schema, with_nil) do
  {:ok, data} -> IO.puts("  Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("  Errors: #{inspect(errors)}")
end

full_data = %{name: "Test", description: "A test config", count: 42, enabled: false}
IO.puts("\nFull data (overriding default):")

case Schema.validate(config_schema, full_data) do
  {:ok, data} -> IO.puts("  Valid: #{inspect(data)}")
  {:error, errors} -> IO.puts("  Errors: #{inspect(errors)}")
end
