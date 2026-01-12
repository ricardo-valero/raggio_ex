defmodule RaggioSyntax.TransformerTest do
  use ExUnit.Case, async: true

  alias RaggioSyntax
  alias RaggioSyntax.Node.{Field, Schema}

  describe "transform/2 (US2 Acceptance 2)" do
    test "transforms AST correctly" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      # Make all fields required
      transformed =
        RaggioSyntax.transform(schema, fn
          %Field{} = field -> %{field | required: true}
          other -> other
        end)

      assert %Schema{} = transformed
      assert Enum.all?(transformed.fields, fn field -> field.required == true end)
    end

    test "maintains structural integrity after transformation" do
      original =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      # Transform by adding metadata
      transformed =
        RaggioSyntax.transform(original, fn
          %Field{} = field ->
            %{field | metadata: Map.put(field.metadata, :transformed, true)}

          other ->
            other
        end)

      # Verify structure is maintained
      assert transformed.name == original.name
      assert length(transformed.fields) == length(original.fields)

      # Verify transformation was applied
      assert Enum.all?(transformed.fields, fn field ->
               field.metadata[:transformed] == true
             end)
    end

    test "transforms nested structures" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(
            :addresses,
            RaggioSyntax.type(:array, [RaggioSyntax.type(:string)])
          )
        ])

      # Add metadata to all type nodes
      transformed =
        RaggioSyntax.transform(schema, fn
          %{type: :type} = type_node ->
            %{type_node | metadata: %{transformed: true}}

          other ->
            other
        end)

      # Find all type nodes and verify they were transformed
      type_nodes =
        RaggioSyntax.find_all(transformed, fn
          %{type: :type} -> true
          _ -> false
        end)

      assert length(type_nodes) > 0
      assert Enum.all?(type_nodes, fn node -> node.metadata[:transformed] == true end)
    end

    test "can change node types during transformation" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string), required: false)
        ])

      transformed =
        RaggioSyntax.transform(schema, fn
          %Field{required: false, default: nil} = field ->
            %{field | required: true}

          other ->
            other
        end)

      [name_field] = transformed.fields
      assert name_field.required == true
    end

    test "preserves nodes that don't match transformation" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      # Only transform fields named :name
      transformed =
        RaggioSyntax.transform(schema, fn
          %Field{name: :name} = field ->
            %{field | required: true}

          other ->
            other
        end)

      name_field = Enum.find(transformed.fields, fn f -> f.name == :name end)
      age_field = Enum.find(transformed.fields, fn f -> f.name == :age end)

      assert name_field.required == true
      assert age_field.required == false
    end
  end

  describe "map/2" do
    test "maps function over all nodes" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      mapped =
        RaggioSyntax.map(schema, fn node ->
          if Map.has_key?(node, :metadata) do
            %{node | metadata: Map.put(node.metadata, :mapped, true)}
          else
            node
          end
        end)

      # Verify all nodes with metadata were mapped
      nodes_with_metadata =
        RaggioSyntax.find_all(mapped, fn node ->
          Map.has_key?(node, :metadata) && node.metadata[:mapped] == true
        end)

      assert length(nodes_with_metadata) > 0
    end
  end

  describe "filter/2" do
    test "filters out nodes not matching predicate" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:id, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:internal_flag, RaggioSyntax.type(:boolean))
        ])

      # Remove fields starting with "internal"
      filtered =
        RaggioSyntax.filter(schema, fn
          %Field{name: name} ->
            not String.starts_with?(Atom.to_string(name), "internal")

          _ ->
            true
        end)

      assert filtered != nil
      field_names = Enum.map(filtered.fields, fn f -> f.name end)
      assert :id in field_names
      assert :name in field_names
      refute :internal_flag in field_names
    end
  end

  describe "replace/3" do
    test "replaces specific node with replacement" do
      old_type = RaggioSyntax.type(:string)
      new_type = RaggioSyntax.type(:text)

      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, old_type)
        ])

      replaced = RaggioSyntax.replace(schema, old_type, new_type)

      # Find the type node in the replaced schema
      found_type =
        RaggioSyntax.find(replaced, fn
          %{type: :type} -> true
          _ -> false
        end)

      assert found_type.name == :text
    end

    test "replaces field node" do
      old_field = RaggioSyntax.field(:old_name, RaggioSyntax.type(:string))
      new_field = RaggioSyntax.field(:new_name, RaggioSyntax.type(:string))

      schema = RaggioSyntax.schema(:user, [old_field])

      replaced = RaggioSyntax.replace(schema, old_field, new_field)

      assert length(replaced.fields) == 1
      assert hd(replaced.fields).name == :new_name
    end

    test "leaves other nodes unchanged" do
      type_to_replace = RaggioSyntax.type(:string)
      new_type = RaggioSyntax.type(:text)

      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, type_to_replace),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      replaced = RaggioSyntax.replace(schema, type_to_replace, new_type)

      # Age field should be unchanged
      age_field = Enum.find(replaced.fields, fn f -> f.name == :age end)
      assert age_field.field_type.name == :integer
    end
  end

  describe "AST transformation" do
    test "transforms AST with metadata preserved" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      metadata = %{version: "1.0"}
      ast = RaggioSyntax.ast(schema, metadata)

      transformed_ast =
        RaggioSyntax.transform(ast, fn
          %Field{} = field -> %{field | required: true}
          other -> other
        end)

      assert transformed_ast.metadata == metadata
      assert hd(transformed_ast.root.fields).required == true
    end
  end
end
