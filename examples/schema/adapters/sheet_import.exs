alias Raggio.Schema.Adapters.SheetSchema

IO.puts("=== SheetSchema CSV Import ===\n")

csv_content = """
field_name,type,required,constraints,description
email,string,true,pattern(^.+@.+$)|max(255),User email address
age,integer,false,min(0)|max(150),User age in years
name,string,true,min(1)|max(100),Full name
is_verified,boolean,false,,Email verification status
"""

csv_path = "/tmp/test_schema.csv"
File.write!(csv_path, csv_content)

IO.puts("Input CSV:")
IO.puts(csv_content)

case SheetSchema.from_csv(csv_path) do
  {:ok, code} ->
    IO.puts("\n--- Generated Schema Code ---")
    IO.puts(code)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

IO.puts("\n--- With Module Wrapper ---")

case SheetSchema.from_csv(csv_path, module_name: "MyApp.UserSchema") do
  {:ok, code} ->
    IO.puts(code)

  {:error, err} ->
    IO.puts("Error: #{inspect(err)}")
end

IO.puts("\n--- Format Validation ---")

case SheetSchema.validate_format(csv_path) do
  :ok ->
    IO.puts("CSV format is valid!")

  {:error, errors} ->
    IO.puts("Validation errors:")
    Enum.each(errors, fn {row, msg} -> IO.puts("  Row #{row}: #{msg}") end)
end

File.rm(csv_path)
