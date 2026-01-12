# Simple Schema Example
#
# This example demonstrates basic schema definition and validation

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Define a simple user schema
user_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:age, Schema.integer()}
  ])

# Validate valid data
valid_user = %{name: "Alice", age: 30}

case Schema.validate(user_schema, valid_user) do
  {:ok, data} ->
    IO.puts("✓ Validation succeeded: #{inspect(data)}")

  {:error, errors} ->
    IO.puts("✗ Validation failed: #{inspect(errors)}")
end

# Validate invalid data
invalid_user = %{name: "Bob", age: "not a number"}

case Schema.validate(user_schema, invalid_user) do
  {:ok, data} ->
    IO.puts("✓ Validation succeeded: #{inspect(data)}")

  {:error, errors} ->
    IO.puts("✗ Validation failed:")

    Enum.each(errors, fn err ->
      path = Enum.join(err.path, ".")
      IO.puts("  - #{path}: #{err.message}")
    end)
end
