# Example: Nested struct validation
# Demonstrates validating complex nested data structures

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Define nested schemas - address is embedded in user
address_schema =
  Schema.struct([
    {:street, Schema.string() |> Schema.min_length(3)},
    {:city, Schema.string() |> Schema.min_length(2)},
    {:zip, Schema.string() |> Schema.pattern(~r/^\d{5}$/)}
  ])

user_schema =
  Schema.struct([
    {:name, Schema.string() |> Schema.min_length(3)},
    {:age, Schema.integer() |> Schema.positive()},
    {:address, address_schema}
  ])

# Valid nested data
valid_user = %{
  name: "Alice Johnson",
  age: 30,
  address: %{
    street: "123 Main St",
    city: "Portland",
    zip: "97201"
  }
}

IO.puts("Validating valid nested user:")

case Schema.validate(user_schema, valid_user) do
  {:ok, data} ->
    IO.puts("✓ Validation passed")
    IO.inspect(data, label: "Valid data")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    IO.inspect(errors, label: "Errors")
end

# Invalid nested data - bad zip code
invalid_user = %{
  name: "Bob",
  age: 25,
  address: %{
    street: "456 Oak Ave",
    city: "Seattle",
    zip: "ABCDE"
  }
}

IO.puts("\nValidating invalid nested user (bad zip):")

case Schema.validate(user_schema, invalid_user) do
  {:ok, data} ->
    IO.puts("✓ Validation passed")
    IO.inspect(data, label: "Valid data")

  {:error, errors} ->
    IO.puts("✗ Validation failed (expected)")
    IO.inspect(errors, label: "Errors")
end

# Deeply nested structure
contact_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:address, address_schema},
    {:emergency_contact,
     Schema.struct([
       {:name, Schema.string()},
       {:phone, Schema.string()},
       {:address, address_schema}
     ])}
  ])

deeply_nested = %{
  name: "Charlie Brown",
  address: %{
    street: "789 Pine Rd",
    city: "Eugene",
    zip: "97401"
  },
  emergency_contact: %{
    name: "Diana Prince",
    phone: "555-0123",
    address: %{
      street: "321 Elm St",
      city: "Salem",
      zip: "97301"
    }
  }
}

IO.puts("\nValidating deeply nested structure:")

case Schema.validate(contact_schema, deeply_nested) do
  {:ok, data} ->
    IO.puts("✓ Validation passed")
    IO.inspect(data, label: "Valid data")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    IO.inspect(errors, label: "Errors")
end

IO.puts("\n✓ Example completed successfully")
