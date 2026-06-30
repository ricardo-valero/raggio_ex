defmodule Raggio.Schema.Adapters.JsonSchemaTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Adapters.JsonSchema

  # Nested view (no `$schema` wrapper) for focused assertions.
  defp gen(schema), do: JsonSchema.to_json_schema(schema, root: false)

  describe "primitives" do
    test "string" do
      assert gen(Schema.string()) == %{"type" => "string"}
    end

    test "string with min/max/pattern" do
      schema = Schema.string(min: 3, max: 20, pattern: ~r/^[a-z]+$/)

      assert gen(schema) == %{
               "type" => "string",
               "minLength" => 3,
               "maxLength" => 20,
               "pattern" => "^[a-z]+$"
             }
    end

    test "integer with bounds maps to minimum/maximum" do
      assert gen(Schema.integer(min: 0, max: 150)) == %{
               "type" => "integer",
               "minimum" => 0,
               "maximum" => 150
             }
    end

    test "float maps to number" do
      assert gen(Schema.float()) == %{"type" => "number"}
    end

    test "boolean" do
      assert gen(Schema.boolean()) == %{"type" => "boolean"}
    end

    test "atom serializes as string" do
      assert gen(Schema.atom()) == %{"type" => "string"}
    end

    test "date / datetime / decimal carry a format" do
      assert gen(Schema.date()) == %{"type" => "string", "format" => "date"}
      assert gen(Schema.datetime()) == %{"type" => "string", "format" => "date-time"}
      assert gen(Schema.decimal()) == %{"type" => "string", "format" => "decimal"}
    end
  end

  describe "composites" do
    test "struct maps to object with properties and required (optional excluded)" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:age, Schema.optional(Schema.integer())}
        ])

      doc = gen(schema)

      assert doc["type"] == "object"
      assert doc["properties"]["name"] == %{"type" => "string"}
      assert doc["properties"]["age"] == %{"type" => "integer"}
      assert doc["required"] == ["name"]
    end

    test "defaulted fields are excluded from required" do
      schema =
        Schema.struct([
          {:name, Schema.string()},
          {:status, Schema.string("active")}
        ])

      assert gen(schema)["required"] == ["name"]
    end

    test "struct with no required fields omits the required key" do
      schema = Schema.struct([{:bio, Schema.optional(Schema.string())}])
      refute Map.has_key?(gen(schema), "required")
    end

    test "list maps to array with items and constraints" do
      schema = Schema.list(Schema.integer(min: 0), min: 1, max: 10, unique: true)

      assert gen(schema) == %{
               "type" => "array",
               "items" => %{"type" => "integer", "minimum" => 0},
               "minItems" => 1,
               "maxItems" => 10,
               "uniqueItems" => true
             }
    end

    test "tuple maps to prefixItems with fixed length" do
      schema = Schema.tuple([Schema.string(), Schema.integer()])

      assert gen(schema) == %{
               "type" => "array",
               "prefixItems" => [%{"type" => "string"}, %{"type" => "integer"}],
               "items" => false,
               "minItems" => 2,
               "maxItems" => 2
             }
    end

    test "union maps to anyOf" do
      schema = Schema.union([Schema.string(), Schema.integer()])

      assert gen(schema) == %{
               "anyOf" => [%{"type" => "string"}, %{"type" => "integer"}]
             }
    end

    test "record maps to additionalProperties" do
      schema = Schema.record(Schema.string(), Schema.integer(min: 0))

      assert gen(schema) == %{
               "type" => "object",
               "additionalProperties" => %{"type" => "integer", "minimum" => 0}
             }
    end
  end

  describe "literals" do
    test "single literal maps to const" do
      assert gen(Schema.literal(:active)) == %{"const" => "active"}
    end

    test "multiple literals map to enum (atoms as strings)" do
      assert gen(Schema.literal(:pending, :approved, :rejected)) == %{
               "enum" => ["pending", "approved", "rejected"]
             }
    end

    test "scalar literals keep their JSON type" do
      assert gen(Schema.literal(1, 2)) == %{"enum" => [1, 2]}
    end
  end

  describe "modifiers" do
    test "nullable widens type to include null" do
      assert gen(Schema.nullable(Schema.string())) == %{"type" => ["string", "null"]}
    end

    test "nullable on a union falls back to anyOf with null" do
      schema = Schema.nullable(Schema.union([Schema.string(), Schema.integer()]))

      assert gen(schema) == %{
               "anyOf" => [
                 %{"anyOf" => [%{"type" => "string"}, %{"type" => "integer"}]},
                 %{"type" => "null"}
               ]
             }
    end

    test "default is emitted (atoms serialized)" do
      assert gen(Schema.integer(0))["default"] == 0
      assert gen(Schema.string("active"))["default"] == "active"
    end
  end

  describe "annotations" do
    test "metadata title/description/examples flow into the document" do
      schema = %{
        Schema.string()
        | metadata: %{title: "Email", description: "User email", examples: ["a@b.co"]}
      }

      doc = gen(schema)
      assert doc["title"] == "Email"
      assert doc["description"] == "User email"
      assert doc["examples"] == ["a@b.co"]
    end
  end

  describe "document root" do
    test "top-level emits the draft 2020-12 $schema" do
      doc = JsonSchema.to_json_schema(Schema.string())
      assert doc["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    end

    test "nested schemas do not repeat $schema" do
      doc = JsonSchema.to_json_schema(Schema.struct([{:name, Schema.string()}]))
      refute Map.has_key?(doc["properties"]["name"], "$schema")
    end

    test "to_json_string produces valid JSON" do
      json = JsonSchema.to_json_string(Schema.struct([{:name, Schema.string()}]), pretty: false)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["type"] == "object"
    end
  end
end
