# Example: Enum and Union types
# Demonstrates using enum for fixed values and union for multiple types

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema

# Example 1: Simple enum validation
IO.puts("Example 1: Status enum")
IO.puts("=======================")

status_schema = Schema.enum([:pending, :approved, :rejected])

case Schema.validate(status_schema, :pending) do
  {:ok, data} ->
    IO.puts("✓ Status :pending is valid")
    IO.inspect(data, label: "Valid status")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{&1.message}"))
end

case Schema.validate(status_schema, :invalid) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Invalid status rejected (expected):")
    Enum.each(errors, &IO.puts("  - #{&1.message}"))
end

# Example 2: Enum in struct
IO.puts("\nExample 2: Order with status enum")
IO.puts("===================================")

order_schema =
  Schema.struct([
    {:id, Schema.string()},
    {:status, Schema.enum([:pending, :processing, :shipped, :delivered])},
    {:total, Schema.float() |> Schema.positive()}
  ])

valid_order = %{
  id: "ORD-001",
  status: :shipped,
  total: 99.99
}

case Schema.validate(order_schema, valid_order) do
  {:ok, data} ->
    IO.puts("✓ Order validation passed")
    IO.inspect(data, label: "Valid order")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 3: Union types for flexible validation
IO.puts("\nExample 3: Union type (string or integer ID)")
IO.puts("=============================================")

id_schema = Schema.union([Schema.string(), Schema.integer()])

case Schema.validate(id_schema, "ABC123") do
  {:ok, data} ->
    IO.puts("✓ String ID validated")
    IO.inspect(data, label: "Valid ID")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{&1.message}"))
end

case Schema.validate(id_schema, 12345) do
  {:ok, data} ->
    IO.puts("✓ Integer ID validated")
    IO.inspect(data, label: "Valid ID")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{&1.message}"))
end

case Schema.validate(id_schema, 3.14) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Float rejected by union (expected):")
    Enum.each(errors, &IO.puts("  - #{&1.message}"))
end

# Example 4: Union with complex types
IO.puts("\nExample 4: Payment method union")
IO.puts("================================")

credit_card_schema =
  Schema.struct([
    {:type, Schema.enum([:credit_card])},
    {:card_number, Schema.string() |> Schema.pattern(~r/^\d{16}$/)},
    {:cvv, Schema.string() |> Schema.pattern(~r/^\d{3}$/)}
  ])

paypal_schema =
  Schema.struct([
    {:type, Schema.enum([:paypal])},
    {:email, Schema.string() |> Schema.email()}
  ])

cash_schema =
  Schema.struct([
    {:type, Schema.enum([:cash])},
    {:amount, Schema.float() |> Schema.positive()}
  ])

payment_method_schema = Schema.union([credit_card_schema, paypal_schema, cash_schema])

credit_card_payment = %{
  type: :credit_card,
  card_number: "1234567890123456",
  cvv: "123"
}

case Schema.validate(payment_method_schema, credit_card_payment) do
  {:ok, data} ->
    IO.puts("✓ Credit card payment validated")
    IO.inspect(data, label: "Valid payment")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

paypal_payment = %{
  type: :paypal,
  email: "user@example.com"
}

case Schema.validate(payment_method_schema, paypal_payment) do
  {:ok, data} ->
    IO.puts("✓ PayPal payment validated")
    IO.inspect(data, label: "Valid payment")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

# Example 5: Enum with string values
IO.puts("\nExample 5: Priority enum with atoms")
IO.puts("=====================================")

task_schema =
  Schema.struct([
    {:title, Schema.string() |> Schema.min_length(1)},
    {:priority, Schema.enum([:low, :medium, :high, :urgent])}
  ])

valid_task = %{
  title: "Fix bug in validator",
  priority: :high
}

case Schema.validate(task_schema, valid_task) do
  {:ok, data} ->
    IO.puts("✓ Task validation passed")
    IO.inspect(data, label: "Valid task")

  {:error, errors} ->
    IO.puts("✗ Validation failed")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

invalid_task = %{
  title: "Another task",
  priority: :critical
  # not in enum
}

case Schema.validate(task_schema, invalid_task) do
  {:ok, _} ->
    IO.puts("✓ Validation passed")

  {:error, errors} ->
    IO.puts("✗ Invalid priority rejected (expected):")
    Enum.each(errors, &IO.puts("  - #{Enum.join(&1.path, ".")}: #{&1.message}"))
end

IO.puts("\n✓ Example completed successfully")
