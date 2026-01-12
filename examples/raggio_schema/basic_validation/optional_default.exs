# Example: Optional fields and default values
# Demonstrates using optional/1 and default/2 for flexible schemas

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Example 1: Optional field without default
IO.puts("Example 1: Optional field (can be nil)")
IO.puts("=======================================")

user_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:bio, Schema.string() |> Schema.optional()}
  ])

# User with bio
user_with_bio = %{name: "Alice", bio: "Software developer"}

case Schema.validate(user_schema, user_with_bio) do
  {:ok, data} ->
    IO.puts("✓ User with bio validated")
    IO.inspect(data, label: "Valid user")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# User without bio (nil is allowed)
user_without_bio = %{name: "Bob", bio: nil}

case Schema.validate(user_schema, user_without_bio) do
  {:ok, data} ->
    IO.puts("✓ User without bio validated (bio is nil)")
    IO.inspect(data, label: "Valid user")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 2: Field with default value
IO.puts("\nExample 2: Field with default value")
IO.puts("====================================")

config_schema =
  Schema.struct([
    {:host, Schema.string()},
    {:port, Schema.integer() |> Schema.default(8080)},
    {:timeout, Schema.integer() |> Schema.default(5000)}
  ])

# Config with custom values
custom_config = %{host: "localhost", port: 3000, timeout: 10_000}

case Schema.validate(config_schema, custom_config) do
  {:ok, data} ->
    IO.puts("✓ Custom config validated")
    IO.inspect(data, label: "Config with custom values")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Config using defaults (nil values get replaced with defaults)
default_config = %{host: "api.example.com", port: nil, timeout: nil}

case Schema.validate(config_schema, default_config) do
  {:ok, data} ->
    IO.puts("✓ Config with defaults validated")
    IO.puts("  Host: #{data.host}")
    IO.puts("  Port: #{data.port} (default)")
    IO.puts("  Timeout: #{data.timeout} (default)")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 3: Optional with default
IO.puts("\nExample 3: Optional field with default value")
IO.puts("=============================================")

settings_schema =
  Schema.struct([
    {:theme, Schema.string() |> Schema.optional() |> Schema.default("light")},
    {:language, Schema.string() |> Schema.optional() |> Schema.default("en")}
  ])

# Settings with custom values
custom_settings = %{theme: "dark", language: "es"}

case Schema.validate(settings_schema, custom_settings) do
  {:ok, data} ->
    IO.puts("✓ Custom settings validated")
    IO.inspect(data, label: "Custom settings")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Settings using defaults
default_settings = %{theme: nil, language: nil}

case Schema.validate(settings_schema, default_settings) do
  {:ok, data} ->
    IO.puts("✓ Default settings applied")
    IO.inspect(data, label: "Settings with defaults")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 4: Complex struct with optional nested fields
IO.puts("\nExample 4: Nested struct with optional fields")
IO.puts("==============================================")

address_schema =
  Schema.struct([
    {:street, Schema.string()},
    {:city, Schema.string()},
    {:apartment, Schema.string() |> Schema.optional()}
  ])

person_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:email, Schema.string() |> Schema.email()},
    {:phone, Schema.string() |> Schema.optional()},
    {:address, address_schema}
  ])

person = %{
  name: "Charlie",
  email: "charlie@example.com",
  phone: nil,
  address: %{
    street: "123 Main St",
    city: "Portland",
    apartment: nil
  }
}

case Schema.validate(person_schema, person) do
  {:ok, data} ->
    IO.puts("✓ Person with optional fields validated")
    IO.puts("  Name: #{data.name}")
    IO.puts("  Phone: #{inspect(data.phone)} (optional)")
    IO.puts("  Apartment: #{inspect(data.address.apartment)} (optional)")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 5: Array with default empty list
IO.puts("\nExample 5: Array field with default empty list")
IO.puts("===============================================")

post_schema =
  Schema.struct([
    {:title, Schema.string()},
    {:tags, Schema.array(Schema.string()) |> Schema.default([])}
  ])

post_with_tags = %{title: "My Post", tags: ["elixir", "functional"]}

case Schema.validate(post_schema, post_with_tags) do
  {:ok, data} ->
    IO.puts("✓ Post with tags validated")
    IO.inspect(data, label: "Post with tags")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

post_without_tags = %{title: "Another Post", tags: nil}

case Schema.validate(post_schema, post_without_tags) do
  {:ok, data} ->
    IO.puts("✓ Post without tags validated")
    IO.inspect(data, label: "Post with default empty tags")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\n✓ Example completed successfully")
