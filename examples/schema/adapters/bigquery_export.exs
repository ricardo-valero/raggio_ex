alias Raggio.Schema
alias Raggio.Schema.Adapters.BigQuery

IO.puts("=== BigQuery DDL Export ===\n")

user_schema =
  Schema.struct([
    {:id, Schema.integer()},
    {:email, Schema.string()},
    {:name, Schema.string()},
    {:created_at, Schema.datetime()},
    {:is_active, Schema.boolean(default: true)},
    {:score, Schema.optional(Schema.decimal())}
  ])

IO.puts("--- Basic Table ---")
ddl = BigQuery.to_ddl(user_schema, "users")
IO.puts(ddl)

IO.puts("\n--- With Partitioning and Clustering ---")

ddl_advanced =
  BigQuery.to_ddl(user_schema, "myproject.mydataset.users",
    partition_by: "DATE(created_at)",
    cluster_by: ["is_active", "id"],
    description: "User accounts table"
  )

IO.puts(ddl_advanced)

IO.puts("\n--- Nested Schema ---")

address_schema =
  Schema.struct([
    {:street, Schema.string()},
    {:city, Schema.string()},
    {:zip, Schema.string()}
  ])

order_schema =
  Schema.struct([
    {:order_id, Schema.string()},
    {:items, Schema.list(Schema.string())},
    {:shipping_address, address_schema},
    {:total, Schema.decimal()}
  ])

nested_ddl = BigQuery.to_ddl(order_schema, "orders")
IO.puts(nested_ddl)
