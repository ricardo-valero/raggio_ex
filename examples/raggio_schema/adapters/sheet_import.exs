# SheetSchema Import Example
# Demonstrates US6 Acceptance Scenario 1: Importing schema from CSV

alias Raggio.Schema.Importer.SheetSchema

IO.puts("=== SheetSchema Import Example ===\n")

# Path to example CSV
csv_path = Path.join([__DIR__, "fixtures", "user_schema.csv"])

IO.puts("Importing schema from: #{csv_path}\n")

# Import the schema
case SheetSchema.from_csv(csv_path) do
  {:ok, code} ->
    IO.puts("✓ Successfully imported schema!")
    IO.puts("\nGenerated Code:")
    IO.puts("─────────────────────────────────────")
    IO.puts(code)
    IO.puts("─────────────────────────────────────")

    IO.puts("\n✓ SheetSchema import complete!")

  {:error, reason} ->
    IO.puts("✗ Import failed: #{inspect(reason)}")
end
