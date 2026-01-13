alias Raggio.Syntax

IO.puts("=== Basic Node Building ===\n")

user_schema =
  Syntax.schema(:user, [
    Syntax.field(:name, Syntax.type(:string)),
    Syntax.field(:age, Syntax.type(:integer)),
    Syntax.field(:email, Syntax.type(:string), required: true),
    Syntax.field(:nickname, Syntax.type(:string), required: false, default: "Anonymous")
  ])

IO.puts("Created schema node:")
IO.inspect(user_schema, pretty: true)

IO.puts("\nSchema name: #{inspect(user_schema.name)}")
IO.puts("Field count: #{length(user_schema.fields)}")

IO.puts("\n--- Field Details ---")

Enum.each(user_schema.fields, fn field ->
  IO.puts("  #{field.name}: #{field.field_type.name} (required: #{field.required})")
end)

IO.puts("\n--- Generic Type (list of strings) ---")
tags_type = Syntax.type(:list, [Syntax.type(:string)])
IO.inspect(tags_type, pretty: true)
