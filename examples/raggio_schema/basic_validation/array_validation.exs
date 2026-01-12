# Example: Array validation
# Demonstrates validating arrays and their elements

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Example 1: Simple array of strings
IO.puts("Example 1: Array of strings")
IO.puts("============================")

tags_schema = Schema.array(Schema.string())

valid_tags = ["elixir", "functional", "programming"]

case Schema.validate(tags_schema, valid_tags) do
  {:ok, data} ->
    IO.puts("✓ Tags validation passed")
    IO.inspect(data, label: "Valid tags")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 2: Array with element constraints
IO.puts("\nExample 2: Array of emails")
IO.puts("===========================")

emails_schema = Schema.array(Schema.string() |> Schema.email())

valid_emails = ["alice@example.com", "bob@test.org"]

case Schema.validate(emails_schema, valid_emails) do
  {:ok, data} ->
    IO.puts("✓ Emails validation passed")
    IO.inspect(data, label: "Valid emails")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

invalid_emails = ["alice@example.com", "not-an-email", "bob@test.org"]

case Schema.validate(emails_schema, invalid_emails) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Invalid emails rejected (expected):")
    Enum.each(errors, &IO.puts("  - Index #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 3: Array of numbers with constraints
IO.puts("\nExample 3: Array of positive integers")
IO.puts("======================================")

scores_schema = Schema.array(Schema.integer() |> Schema.positive())

valid_scores = [95, 87, 92, 78, 100]

case Schema.validate(scores_schema, valid_scores) do
  {:ok, data} ->
    IO.puts("✓ Scores validation passed")
    IO.inspect(data, label: "Valid scores")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

invalid_scores = [95, -10, 87, 0, 92]

case Schema.validate(scores_schema, invalid_scores) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Invalid scores rejected (expected):")
    Enum.each(errors, &IO.puts("  - Index #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 4: Array of structs
IO.puts("\nExample 4: Array of user structs")
IO.puts("==================================")

user_schema =
  Schema.struct([
    {:name, Schema.string() |> Schema.min_length(2)},
    {:age, Schema.integer() |> Schema.positive()}
  ])

users_schema = Schema.array(user_schema)

valid_users = [
  %{name: "Alice", age: 30},
  %{name: "Bob", age: 25},
  %{name: "Charlie", age: 35}
]

case Schema.validate(users_schema, valid_users) do
  {:ok, data} ->
    IO.puts("✓ Users array validation passed")
    IO.puts("  Validated #{length(data)} users")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

invalid_users = [
  %{name: "Alice", age: 30},
  %{name: "X", age: 25},
  # name too short
  %{name: "Charlie", age: -5}
  # negative age
]

case Schema.validate(users_schema, invalid_users) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Invalid users rejected (expected):")
    Enum.each(errors, &IO.puts("  - Index #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 5: Nested arrays
IO.puts("\nExample 5: Nested arrays (matrix)")
IO.puts("===================================")

matrix_schema = Schema.array(Schema.array(Schema.integer()))

valid_matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]

case Schema.validate(matrix_schema, valid_matrix) do
  {:ok, data} ->
    IO.puts("✓ Matrix validation passed")
    IO.puts("  Size: #{length(data)}x#{length(List.first(data))}")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 6: Array with min/max length constraints
IO.puts("\nExample 6: Array with length constraints")
IO.puts("==========================================")

limited_array_schema =
  Schema.array(Schema.string())
  |> Schema.min_length(2)
  |> Schema.max_length(5)

valid_limited = ["one", "two", "three"]

case Schema.validate(limited_array_schema, valid_limited) do
  {:ok, data} ->
    IO.puts("✓ Limited array validation passed")
    IO.inspect(data, label: "Valid array")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

too_short = ["one"]

case Schema.validate(limited_array_schema, too_short) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Array too short (expected):")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\n✓ Example completed successfully")
