defmodule RaggioSyntax.TraversalTest do
  use ExUnit.Case, async: true

  alias RaggioSyntax

  describe "traverse/2 (US2 Acceptance 3)" do
    test "visits all nodes in depth-first order" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      RaggioSyntax.traverse(schema, fn node ->
        send(self(), {:visited, node.type})
      end)

      # Verify nodes were visited
      assert_received {:visited, :schema}
      assert_received {:visited, :field}
      assert_received {:visited, :type}
    end

    test "can access all nodes in predictable order" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      RaggioSyntax.traverse(schema, fn node ->
        send(self(), {:type, node.type})
      end)

      # Should visit in depth-first order: schema -> field -> type -> field -> type
      assert_received {:type, :schema}
      assert_received {:type, :field}
      assert_received {:type, :type}
      assert_received {:type, :field}
      assert_received {:type, :type}
    end

    test "processes all nodes with visitor function" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      field_count =
        RaggioSyntax.traverse(schema, 0, fn
          %{type: :field}, acc -> {:continue, acc + 1}
          _node, acc -> {:continue, acc}
        end)

      assert field_count == 3
    end
  end

  describe "traverse/3 with accumulator" do
    test "accumulates values while traversing" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      field_names =
        RaggioSyntax.traverse(schema, [], fn
          %{type: :field, name: name}, acc -> {:continue, [name | acc]}
          _node, acc -> {:continue, acc}
        end)

      assert :name in field_names
      assert :age in field_names
      assert length(field_names) == 2
    end

    test "can halt traversal early" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      result =
        RaggioSyntax.traverse(schema, nil, fn
          %{type: :field, name: :age} = field, _acc -> {:halt, field}
          _node, acc -> {:continue, acc}
        end)

      assert result.name == :age
    end

    test "collects all field names" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:id, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      field_names =
        RaggioSyntax.traverse(schema, [], fn
          %{type: :field, name: name}, acc -> {:continue, [name | acc]}
          _, acc -> {:continue, acc}
        end)
        |> Enum.reverse()

      assert field_names == [:id, :name, :email]
    end
  end

  describe "traverse_breadth_first/2" do
    test "visits nodes level by level" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      RaggioSyntax.traverse_breadth_first(schema, fn node ->
        send(self(), {:visited_bfs, node.type})
      end)

      # In breadth-first: schema first, then all fields, then all types
      assert_received {:visited_bfs, :schema}
      assert_received {:visited_bfs, :field}
      assert_received {:visited_bfs, :type}
    end
  end

  describe "find/2" do
    test "finds first node matching predicate" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      result =
        RaggioSyntax.find(schema, fn
          %{type: :field, name: :age} -> true
          _ -> false
        end)

      assert result != nil
      assert result.name == :age
    end

    test "returns nil when no match found" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      result =
        RaggioSyntax.find(schema, fn
          %{type: :field, name: :missing} -> true
          _ -> false
        end)

      assert result == nil
    end

    test "finds type nodes" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer))
        ])

      result =
        RaggioSyntax.find(schema, fn
          %{type: :type, name: :integer} -> true
          _ -> false
        end)

      assert result != nil
      assert result.name == :integer
    end
  end

  describe "find_all/2" do
    test "finds all nodes matching predicate" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      results =
        RaggioSyntax.find_all(schema, fn
          %{type: :field} -> true
          _ -> false
        end)

      assert length(results) == 3
      assert Enum.all?(results, fn node -> node.type == :field end)
    end

    test "finds all string types" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string)),
          RaggioSyntax.field(:age, RaggioSyntax.type(:integer)),
          RaggioSyntax.field(:email, RaggioSyntax.type(:string))
        ])

      results =
        RaggioSyntax.find_all(schema, fn
          %{type: :type, name: :string} -> true
          _ -> false
        end)

      assert length(results) == 2
    end

    test "returns empty list when no matches" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      results =
        RaggioSyntax.find_all(schema, fn
          %{type: :transform} -> true
          _ -> false
        end)

      assert results == []
    end
  end

  describe "AST traversal" do
    test "can traverse AST structure" do
      schema =
        RaggioSyntax.schema(:user, [
          RaggioSyntax.field(:name, RaggioSyntax.type(:string))
        ])

      ast = RaggioSyntax.ast(schema)

      count =
        RaggioSyntax.traverse(ast, 0, fn
          _node, acc -> {:continue, acc + 1}
        end)

      # Should count: AST wrapper -> schema -> field -> type = 4 nodes
      # But traverse strips AST wrapper, so: schema -> field -> type = 3
      assert count == 3
    end
  end
end
