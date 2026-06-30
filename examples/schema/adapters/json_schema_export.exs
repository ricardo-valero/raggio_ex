# Export a Raggio.Schema definition to JSON Schema (draft 2020-12).
#
#   mix run examples/schema/adapters/json_schema_export.exs

alias Raggio.Schema
alias Raggio.Schema.Adapters.JsonSchema

user_schema =
  Schema.struct([
    {:name, Schema.string(min: 1, max: 100)},
    {:age, Schema.integer(min: 0)},
    {:email, Schema.string(pattern: Schema.email())},
    {:status, Schema.literal(:active, :inactive, :pending)},
    {:tags, Schema.list(Schema.string(), unique: true)},
    {:bio, Schema.string() |> Schema.optional()}
  ])

IO.puts("# JSON Schema for the user schema\n")
IO.puts(JsonSchema.to_json_string(user_schema))

doc = JsonSchema.to_json_schema(user_schema)

# Sanity checks so the example doubles as a smoke test under examples_test.
"object" = doc["type"]
["name", "age", "email", "status", "tags"] = doc["required"]
"https://json-schema.org/draft/2020-12/schema" = doc["$schema"]

IO.puts("\nOK: generated a valid JSON Schema document.")
