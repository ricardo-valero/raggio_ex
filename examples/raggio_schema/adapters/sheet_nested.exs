alias Raggio.Schema.Importer.SheetSchema

IO.puts("=== SheetSchema Nested Import Example ===\n")

csv_path = Path.join([__DIR__, "fixtures", "nested_schema.csv"])

IO.puts("Importing nested schema from: #{csv_path}\n")

case SheetSchema.from_csv(csv_path) do
  {:ok, code} ->
    IO.puts("Generated Code:")
    IO.puts("---")
    IO.puts(code)
    IO.puts("---")

    IO.puts("\nImport successful!")

  {:error, reason} ->
    IO.puts("Import failed: #{inspect(reason)}")
end
