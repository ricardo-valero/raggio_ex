# BigQuery DDL Export Example
#
# This example demonstrates how to export Raggio.Schema definitions to BigQuery DDL

# Setup paths for umbrella project
Mix.install([], consolidate_protocols: false)
Code.prepend_path("_build/dev/lib/raggio_schema/ebin")

alias Raggio.Schema
alias Raggio.Schema.Adapters.BigQuery

IO.puts("\n=== BigQuery DDL Export Examples ===\n")

# Example 1: Simple table with primitive types
IO.puts("1. Simple user table:")

user_schema =
  Schema.struct([
    {:id, Schema.integer()},
    {:email, Schema.string()},
    {:created_at, Schema.datetime()}
  ])

ddl = BigQuery.to_ddl(user_schema, "users")
IO.puts(ddl)

# Example 2: Table with optional fields and defaults
IO.puts("\n2. Table with optional fields and defaults:")

product_schema =
  Schema.struct([
    {:id, Schema.integer()},
    {:name, Schema.string()},
    {:description, Schema.string() |> Schema.optional()},
    {:status, Schema.string() |> Schema.default("active")},
    {:price, Schema.decimal()},
    {:quantity, Schema.integer() |> Schema.default(0)}
  ])

ddl = BigQuery.to_ddl(product_schema, "products")
IO.puts(ddl)

# Example 3: Table with array fields
IO.puts("\n3. Table with array fields:")

article_schema =
  Schema.struct([
    {:id, Schema.integer()},
    {:title, Schema.string()},
    {:tags, Schema.array(Schema.string())},
    {:ratings, Schema.array(Schema.integer()) |> Schema.optional()}
  ])

ddl = BigQuery.to_ddl(article_schema, "articles")
IO.puts(ddl)

# Example 4: Table with nested struct
IO.puts("\n4. Table with nested struct:")

address_schema =
  Schema.struct([
    {:street, Schema.string()},
    {:city, Schema.string()},
    {:zip_code, Schema.string() |> Schema.optional()},
    {:country, Schema.string()}
  ])

customer_schema =
  Schema.struct([
    {:id, Schema.integer()},
    {:name, Schema.string()},
    {:email, Schema.string()},
    {:address, address_schema}
  ])

ddl = BigQuery.to_ddl(customer_schema, "customers")
IO.puts(ddl)

# Example 5: Partitioned table
IO.puts("\n5. Partitioned table:")

event_schema =
  Schema.struct([
    {:event_id, Schema.integer()},
    {:user_id, Schema.integer()},
    {:event_type, Schema.string()},
    {:event_timestamp, Schema.datetime()},
    {:properties, Schema.string() |> Schema.optional()}
  ])

ddl = BigQuery.to_ddl(event_schema, "events", partition_by: "DATE(event_timestamp)")
IO.puts(ddl)

# Example 6: Clustered table
IO.puts("\n6. Clustered table:")

order_schema =
  Schema.struct([
    {:order_id, Schema.integer()},
    {:customer_id, Schema.integer()},
    {:status, Schema.string()},
    {:total_amount, Schema.decimal()},
    {:created_at, Schema.datetime()}
  ])

ddl = BigQuery.to_ddl(order_schema, "orders", cluster_by: ["customer_id", "status"])
IO.puts(ddl)

# Example 7: Partitioned and clustered table
IO.puts("\n7. Partitioned and clustered table:")

transaction_schema =
  Schema.struct([
    {:transaction_id, Schema.integer()},
    {:user_id, Schema.integer()},
    {:merchant_id, Schema.integer()},
    {:amount, Schema.decimal()},
    {:currency, Schema.string()},
    {:status, Schema.string()},
    {:transaction_date, Schema.date()}
  ])

ddl =
  BigQuery.to_ddl(transaction_schema, "transactions",
    partition_by: "transaction_date",
    cluster_by: ["user_id", "merchant_id"]
  )

IO.puts(ddl)

IO.puts("\n=== All examples completed successfully! ===\n")
