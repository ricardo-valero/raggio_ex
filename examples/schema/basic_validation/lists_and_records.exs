alias Raggio.Schema

tags_schema = Schema.list(Schema.string(min: 1), min: 1, max: 5, unique: true)

metadata_schema = Schema.record(Schema.string(), Schema.integer())

item_schema =
  Schema.struct([
    {:name, Schema.string()},
    {:tags, tags_schema},
    {:metadata, metadata_schema}
  ])

valid_item = %{
  name: "Widget",
  tags: ["featured", "sale", "new"],
  metadata: %{"views" => 100, "likes" => 42}
}

invalid_item = %{
  name: "Gadget",
  tags: ["a", "a", "b"],
  metadata: %{"count" => "not a number"}
}

IO.puts("=== Lists and Records Validation ===\n")

IO.puts("Valid item with list and record:")

case Schema.validate(item_schema, valid_item) do
  {:ok, _} -> IO.puts("  Success!")
  {:error, errors} -> IO.puts("  Errors: #{inspect(errors)}")
end

IO.puts("\nInvalid item (duplicate tags, wrong metadata type):")

case Schema.validate(item_schema, invalid_item, mode: :all_errors) do
  {:ok, _} ->
    IO.puts("  Unexpectedly valid")

  {:error, errors} ->
    Enum.each(errors, fn err ->
      path_str = err.path |> Enum.map(&to_string/1) |> Enum.join(".")
      IO.puts("  - #{path_str}: #{err.message}")
    end)
end
