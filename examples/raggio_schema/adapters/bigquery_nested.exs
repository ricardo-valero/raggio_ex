alias Raggio.Schema
alias Raggio.Schema.Adapters.BigQuery

IO.puts("\n=== BigQuery Nested Struct Export Examples ===\n")

IO.puts("1. Simple nested struct:")

address =
  Schema.struct([
    {:street, Schema.string()},
    {:city, Schema.string()},
    {:state, Schema.string()},
    {:zip, Schema.string()}
  ])

customer =
  Schema.struct([
    {:id, Schema.integer()},
    {:name, Schema.string()},
    {:address, address}
  ])

IO.puts(BigQuery.to_ddl(customer, "customers"))

IO.puts("\n2. Deeply nested structs:")

geo =
  Schema.struct([
    {:lat, Schema.float()},
    {:lng, Schema.float()}
  ])

location =
  Schema.struct([
    {:address, Schema.string()},
    {:city, Schema.string()},
    {:geo, geo}
  ])

store =
  Schema.struct([
    {:id, Schema.integer()},
    {:name, Schema.string()},
    {:location, location}
  ])

IO.puts(BigQuery.to_ddl(store, "stores"))

IO.puts("\n3. Nested struct with arrays:")

order_item =
  Schema.struct([
    {:product_id, Schema.integer()},
    {:quantity, Schema.integer()},
    {:unit_price, Schema.decimal()}
  ])

order =
  Schema.struct([
    {:order_id, Schema.integer()},
    {:customer_id, Schema.integer()},
    {:items, Schema.list(order_item)},
    {:total, Schema.decimal()}
  ])

IO.puts(BigQuery.to_ddl(order, "orders"))

IO.puts("\n4. Multiple nested structs at same level:")

billing_address =
  Schema.struct([
    {:name, Schema.string()},
    {:street, Schema.string()},
    {:city, Schema.string()}
  ])

shipping_address =
  Schema.struct([
    {:recipient, Schema.string()},
    {:street, Schema.string()},
    {:city, Schema.string()},
    {:instructions, Schema.optional(Schema.string())}
  ])

invoice =
  Schema.struct([
    {:invoice_id, Schema.integer()},
    {:billing, billing_address},
    {:shipping, shipping_address},
    {:amount, Schema.decimal()}
  ])

IO.puts(BigQuery.to_ddl(invoice, "invoices"))

IO.puts("\n5. Optional nested struct:")

profile =
  Schema.struct([
    {:bio, Schema.optional(Schema.string())},
    {:website, Schema.optional(Schema.string())}
  ])

user =
  Schema.struct([
    {:id, Schema.integer()},
    {:username, Schema.string()},
    {:profile, Schema.optional(profile)}
  ])

IO.puts(BigQuery.to_ddl(user, "users"))

IO.puts("\n=== Nested struct export completed! ===\n")
