defmodule RaggioSyntaxTest do
  use ExUnit.Case, async: true
  doctest RaggioSyntax

  alias RaggioSyntax
  alias RaggioSyntax.Node.{Field, Schema, Type}

  describe "type/1" do
    test "creates a simple type node" do
      type = RaggioSyntax.type(:string)

      assert %Type{} = type
      assert type.name == :string
      assert type.type == :type
      assert type.parameters == []
    end
  end

  describe "type/2" do
    test "creates a generic type node with parameters" do
      string_type = RaggioSyntax.type(:string)
      array_type = RaggioSyntax.type(:array, [string_type])

      assert %Type{} = array_type
      assert array_type.name == :array
      assert length(array_type.parameters) == 1
      assert hd(array_type.parameters) == string_type
    end
  end

  describe "field/2" do
    test "creates a field node" do
      string_type = RaggioSyntax.type(:string)
      field = RaggioSyntax.field(:name, string_type)

      assert %Field{} = field
      assert field.name == :name
      assert field.field_type == string_type
      assert field.required == false
      assert field.default == nil
    end
  end

  describe "field/3" do
    test "creates a field node with options" do
      integer_type = RaggioSyntax.type(:integer)
      field = RaggioSyntax.field(:age, integer_type, required: true, default: 0)

      assert %Field{} = field
      assert field.name == :age
      assert field.required == true
      assert field.default == 0
    end
  end

  describe "schema/1" do
    test "creates a schema node from fields" do
      fields = [
        RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
        RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
      ]

      schema = RaggioSyntax.schema(fields)

      assert %Schema{} = schema
      assert schema.name == nil
      assert length(schema.fields) == 2
      assert schema.schema_type == :struct
    end
  end

  describe "schema/2" do
    test "creates a named schema node" do
      fields = [
        RaggioSyntax.field(:name, RaggioSyntax.type(:string))
      ]

      schema = RaggioSyntax.schema(:user, fields)

      assert %Schema{} = schema
      assert schema.name == :user
      assert length(schema.fields) == 1
    end
  end

  describe "ast/1" do
    test "creates an AST from a root node" do
      schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      ast = RaggioSyntax.ast(schema)

      assert %RaggioSyntax.AST{} = ast
      assert ast.root == schema
      assert ast.metadata == %{}
    end
  end

  describe "ast/2" do
    test "creates an AST with metadata" do
      schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      metadata = %{version: "1.0", author: "test"}
      ast = RaggioSyntax.ast(schema, metadata)

      assert %RaggioSyntax.AST{} = ast
      assert ast.root == schema
      assert ast.metadata == metadata
    end
  end

  describe "get_fields/1" do
    test "extracts field nodes from schema" do
      fields = [
        RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
        RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
      ]

      schema = RaggioSyntax.schema(fields)
      result = RaggioSyntax.get_fields(schema)

      assert result == fields
    end

    test "returns empty list for non-schema nodes" do
      type = RaggioSyntax.type(:string)
      result = RaggioSyntax.get_fields(type)

      assert result == []
    end
  end

  describe "get_field/2" do
    test "gets a specific field by name" do
      fields = [
        RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
        RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
      ]

      schema = RaggioSyntax.schema(fields)
      field = RaggioSyntax.get_field(schema, :name)

      assert %Field{} = field
      assert field.name == :name
    end

    test "returns nil if field not found" do
      schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      result = RaggioSyntax.get_field(schema, :missing)

      assert result == nil
    end
  end

  describe "get_type/1" do
    test "returns the type of a node" do
      field = RaggioSyntax.field(:name, RaggioSyntax.type(:string))

      assert RaggioSyntax.get_type(field) == :field
    end
  end

  describe "get_children/1" do
    test "returns children of schema node" do
      fields = [
        RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
        RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
      ]

      schema = RaggioSyntax.schema(fields)
      children = RaggioSyntax.get_children(schema)

      assert children == fields
    end

    test "returns field type for field node" do
      string_type = RaggioSyntax.type(:string)
      field = RaggioSyntax.field(:name, string_type)
      children = RaggioSyntax.get_children(field)

      assert children == [string_type]
    end
  end

  describe "valid?/1" do
    test "returns true for valid schema" do
      schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      assert RaggioSyntax.valid?(schema) == true
    end
  end

  describe "validate/1" do
    test "validates correct schema structure" do
      schema =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      assert RaggioSyntax.validate(schema) == :ok
    end

    test "validates field with atom name" do
      field = RaggioSyntax.field(:name, RaggioSyntax.type(:string))

      assert RaggioSyntax.validate(field) == :ok
    end

    test "validates type with atom name" do
      type = RaggioSyntax.type(:string)

      assert RaggioSyntax.validate(type) == :ok
    end
  end

  describe "merge/2" do
    test "merges two schema nodes" do
      schema1 =
        RaggioSyntax.schema([
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      schema2 =
        RaggioSyntax.schema([
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      merged = RaggioSyntax.merge(schema1, schema2)

      assert %Schema{} = merged
      assert length(merged.fields) == 2
    end
  end

  describe "compose/1" do
    test "composes multiple schemas into one" do
      schemas = [
        RaggioSyntax.schema([RaggioSyntax.field(:name, RaggioSyntax.type(:string))]),
        RaggioSyntax.schema([RaggioSyntax.field(:age, RaggioSyntax.type(:integer))]),
        RaggioSyntax.schema([RaggioSyntax.field(:email, RaggioSyntax.type(:string))])
      ]

      composed = RaggioSyntax.compose(schemas)

      assert %Schema{} = composed
      assert length(composed.fields) == 3
    end
  end
end
