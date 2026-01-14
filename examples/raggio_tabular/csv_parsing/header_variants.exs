alias Raggio.Schema
alias Raggio.Tabular.SheetSchema

IO.puts("=== Header Variants Example ===\n")

schema =
  SheetSchema.define([
    {:user_id, Schema.integer()},
    {:full_name, Schema.string(min: 1)},
    {:email_address, Schema.string()}
  ])
  |> SheetSchema.with_header_variants(%{
    "id" => :user_id,
    "uid" => :user_id,
    "user id" => :user_id,
    "name" => :full_name,
    "full name" => :full_name,
    "fullname" => :full_name,
    "email" => :email_address,
    "e-mail" => :email_address,
    "mail" => :email_address
  })

IO.puts("Schema with header variants configured.")
IO.puts("\nThis schema will match files with any of these header combinations:")
IO.puts("  - id, name, email")
IO.puts("  - uid, fullname, mail")
IO.puts("  - user id, full name, e-mail")
IO.puts("\nAll variants map to the same canonical fields: user_id, full_name, email_address")

IO.puts("\nHeader variants example complete!")
