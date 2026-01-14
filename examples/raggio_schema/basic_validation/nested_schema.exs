alias Raggio.Schema

address_schema =
  Schema.struct([
    {:street, Schema.string(min: 3)},
    {:city, Schema.string(min: 2)},
    {:zip, Schema.string(pattern: ~r/^\d{5}$/)}
  ])

user_schema =
  Schema.struct([
    {:name, Schema.string(min: 3)},
    {:age, Schema.integer(min: 1)},
    {:address, address_schema}
  ])

valid_user = %{
  name: "Alice Johnson",
  age: 30,
  address: %{
    street: "123 Main St",
    city: "Portland",
    zip: "97201"
  }
}

IO.puts("Valid nested user:")
IO.inspect(Schema.validate(user_schema, valid_user))

invalid_user = %{
  name: "Bob",
  age: 25,
  address: %{
    street: "456 Oak Ave",
    city: "Seattle",
    zip: "ABCDE"
  }
}

IO.puts("\nInvalid nested user (bad zip):")

case Schema.validate(user_schema, invalid_user) do
  {:ok, _} ->
    IO.puts("Passed")

  {:error, errors} ->
    Enum.each(errors, fn err ->
      IO.puts("  #{Enum.join(err.path, ".")}: #{err.message}")
    end)
end

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

IO.puts("\nDeeply nested structure:")
IO.inspect(Schema.validate(contact_schema, deeply_nested))
