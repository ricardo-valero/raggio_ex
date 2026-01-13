alias Raggio.Schema
alias RaggioTabular.SheetSchema

IO.puts("=== Header Variants Example ===\n")

schema =
  SheetSchema.define([
    {:user_id, Schema.integer()},
    {:full_name, Schema.string(min: 1)},
    {:email_address, Schema.string()}
  ])
  |> SheetSchema.with_header_variants([
    %{"id" => :user_id, "uid" => :user_id, "user id" => :user_id},
    %{"name" => :full_name, "full name" => :full_name, "fullname" => :full_name},
    %{"email" => :email_address, "e-mail" => :email_address, "mail" => :email_address}
  ])

csv_variant1 = """
ID,Name,Email
1,Alice,alice@example.com
2,Bob,bob@example.com
"""

csv_variant2 = """
User ID,Full Name,E-Mail
3,Charlie,charlie@example.com
4,Diana,diana@example.com
"""

IO.puts("Variant 1 (ID, Name, Email):")
{:ok, result1} = RaggioTabular.parse_string(csv_variant1, schema)

Enum.each(result1.valid_rows, fn row ->
  IO.puts("  #{row.user_id}: #{row.full_name} <#{row.email_address}>")
end)

IO.puts("\nVariant 2 (User ID, Full Name, E-Mail):")
{:ok, result2} = RaggioTabular.parse_string(csv_variant2, schema)

Enum.each(result2.valid_rows, fn row ->
  IO.puts("  #{row.user_id}: #{row.full_name} <#{row.email_address}>")
end)

IO.puts("\nHeader variants example complete!")
