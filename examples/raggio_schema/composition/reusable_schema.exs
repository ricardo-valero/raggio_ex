alias Raggio.Schema

defmodule Schemas do
  alias Raggio.Schema

  def address do
    Schema.struct([
      {:street, Schema.string(min: 1)},
      {:city, Schema.string(min: 1)},
      {:state, Schema.string(pattern: ~r/^[A-Z]{2}$/)},
      {:zip, Schema.string(pattern: ~r/^\d{5}$/)}
    ])
  end

  def contact_info do
    Schema.struct([
      {:email, Schema.string(pattern: Schema.email())},
      {:phone, Schema.string(pattern: ~r/^\d{3}-\d{3}-\d{4}$/)}
    ])
  end

  def timestamps do
    Schema.struct([
      {:created_at, Schema.datetime()},
      {:updated_at, Schema.datetime()}
    ])
  end

  def person do
    Schema.struct([
      {:name, Schema.string(min: 2)},
      {:age, Schema.integer(min: 0, max: 150)},
      {:address, address()},
      {:contact, contact_info()}
    ])
  end

  def company do
    Schema.struct([
      {:name, Schema.string(min: 1)},
      {:tax_id, Schema.string(pattern: ~r/^\d{2}-\d{7}$/)},
      {:address, address()},
      {:contact, contact_info()}
    ])
  end

  def employee do
    Schema.struct([
      {:employee_id, Schema.string()},
      {:person, person()},
      {:company, company()},
      {:hire_date, Schema.date()}
    ])
  end
end

IO.puts("Example 1: Person with address and contact")
IO.puts("===========================================")

person_data = %{
  name: "Alice Johnson",
  age: 30,
  address: %{
    street: "123 Main St",
    city: "Portland",
    state: "OR",
    zip: "97201"
  },
  contact: %{
    email: "alice@example.com",
    phone: "503-555-1234"
  }
}

case Schema.validate(Schemas.person(), person_data) do
  {:ok, data} ->
    IO.puts("Person validation passed")
    IO.inspect(data, label: "Valid person", limit: :infinity)

  {:error, errors} ->
    IO.puts("Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample 2: Company with same address/contact schemas")
IO.puts("======================================================")

company_data = %{
  name: "Tech Corp",
  tax_id: "12-3456789",
  address: %{
    street: "456 Business Blvd",
    city: "Seattle",
    state: "WA",
    zip: "98101"
  },
  contact: %{
    email: "info@techcorp.com",
    phone: "206-555-9999"
  }
}

case Schema.validate(Schemas.company(), company_data) do
  {:ok, data} ->
    IO.puts("Company validation passed")
    IO.inspect(data, label: "Valid company", limit: :infinity)

  {:error, errors} ->
    IO.puts("Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample 3: Employee combining person and company")
IO.puts("=================================================")

employee_data = %{
  employee_id: "EMP001",
  person: person_data,
  company: company_data,
  hire_date: ~D[2024-01-15]
}

case Schema.validate(Schemas.employee(), employee_data) do
  {:ok, data} ->
    IO.puts("Employee validation passed")
    IO.puts("  Employee ID: #{data.employee_id}")
    IO.puts("  Name: #{data.person.name}")
    IO.puts("  Company: #{data.company.name}")
    IO.puts("  Hire Date: #{data.hire_date}")

  {:error, errors} ->
    IO.puts("Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample 4: Invalid address caught in both person and company")
IO.puts("=============================================================")

invalid_person = %{
  name: "Bob",
  age: 25,
  address: %{
    street: "789 Elm St",
    city: "Eugene",
    state: "Oregon",
    zip: "ABCDE"
  },
  contact: %{
    email: "bob@example.com",
    phone: "541-555-7777"
  }
}

case Schema.validate(Schemas.person(), invalid_person) do
  {:ok, _} ->
    IO.puts("Validation passed")

  {:error, errors} ->
    IO.puts("Person validation failed (expected):")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\nExample completed successfully")
IO.puts("\nKey takeaway: Reusable schemas ensure consistent validation")
IO.puts("across different entity types!")
