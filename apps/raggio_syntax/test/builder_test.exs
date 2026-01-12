defmodule RaggioSyntax.BuilderTest do
  use ExUnit.Case, async: true

  alias RaggioSyntax
  alias RaggioSyntax.Node.{Field, Schema, Type}

  describe "node composition (US2 Acceptance 1)" do
    test "nodes can be created with proper structure" do
      # Create type nodes
      string_type = RaggioSyntax.type(:string)
      integer_type = RaggioSyntax.type(:integer)

      assert %Type{name: :string} = string_type
      assert %Type{name: :integer} = integer_type
    end

    test "field nodes can be composed with type nodes" do
      string_type = RaggioSyntax.type(:string)
      name_field = RaggioSyntax.field(:name, string_type)

      assert %Field{name: :name, field_type: ^string_type} = name_field
    end

    test "schema nodes can be composed from field nodes" do
      user_schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer), required: true),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      assert %Schema{name: :user} = user_schema
      assert length(user_schema.fields) == 3

      # Verify each field
      [name_field, age_field, email_field] = user_schema.fields

      assert name_field.name == :name
      assert name_field.required == false

      assert age_field.name == :age
      assert age_field.required == true

      assert email_field.name == :email
    end

    test "nested schemas can be composed" do
      _address_schema =
        RaggioSyntax.schema(:address, [
          RaggioSyntax.field(:street, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:city, RaggioSyntax.type(:string))
        ])

      # Create a user schema with a nested address
      user_schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:address, RaggioSyntax.type(:schema))
        ])

      assert %Schema{} = user_schema
      assert length(user_schema.fields) == 2
    end

    test "generic type nodes can be composed with parameters" do
      # Array of strings
      string_array = RaggioSyntax.type(:array, [RaggioSyntax.type(:string)])

      assert %Type{name: :array} = string_array
      assert length(string_array.parameters) == 1
      assert hd(string_array.parameters).name == :string
    end

    test "complex nested structures can be built" do
      # Build a complex schema: User with array of addresses
      user_schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(
            :addresses,
            RaggioSyntax.type(:array, [
              RaggioSyntax.type(:struct)
            ])
          )
        ])

      assert %Schema{name: :user} = user_schema
      assert length(user_schema.fields) == 2

      addresses_field = Enum.at(user_schema.fields, 1)
      assert addresses_field.name == :addresses
      assert addresses_field.field_type.name == :array
      assert length(addresses_field.field_type.parameters) == 1
    end

    test "AST can be created from composed nodes" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      ast = RaggioSyntax.ast(schema)

      assert %RaggioSyntax.AST{} = ast
      assert ast.root == schema
      assert RaggioSyntax.get_fields(ast.root) == schema.fields
    end

    test "metadata can be attached to AST" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      metadata = %{
        version: "1.0.0",
        author: "Raggio",
        created_at: DateTime.utc_now()
      }

      ast = RaggioSyntax.ast(schema, metadata)

      assert ast.metadata == metadata
    end

    test "multiple schemas can be merged" do
      base_schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:id, RaggioSyntax.type(:integer))
        ])

      user_schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      merged = RaggioSyntax.merge(base_schema, user_schema)

      assert %Schema{} = merged
      assert length(merged.fields) == 3
      assert Enum.any?(merged.fields, fn f -> f.name == :id end)
      assert Enum.any?(merged.fields, fn f -> f.name == :name end)
      assert Enum.any?(merged.fields, fn f -> f.name == :email end)
    end
  end
end
