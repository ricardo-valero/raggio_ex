defmodule Raggio.Schema.IssueTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Issue

  alias Raggio.Schema.Issue.{
    AnyOf,
    Composite,
    Encoding,
    InvalidType,
    InvalidValue,
    MissingKey,
    Pointer
  }

  defp tree(schema, data, opts \\ []) do
    assert {:error, issue} = Schema.validate(schema, data, Keyword.put(opts, :errors, :tree))
    issue
  end

  describe "errors: :tree returns the issue tree" do
    test "a scalar type failure is a bare leaf" do
      assert %InvalidType{expected: "string", value: 1} = tree(Schema.string(), 1)
    end

    test "a struct field failure is a Pointer wrapping the leaf" do
      schema = Schema.struct([{:name, Schema.string()}])

      assert %Pointer{key: :name, issue: %InvalidType{expected: "string"}} =
               tree(schema, %{name: 1})
    end

    test "a missing required field is Pointer(MissingKey)" do
      schema = Schema.struct([{:name, Schema.string()}])
      assert %Pointer{key: :name, issue: %MissingKey{}} = tree(schema, %{})
    end

    test "nested pointers record the full location" do
      schema = Schema.struct([{:items, Schema.list(Schema.struct([{:n, Schema.integer()}]))}])

      assert %Pointer{
               key: :items,
               issue: %Pointer{key: 1, issue: %Pointer{key: :n, issue: %MissingKey{}}}
             } = tree(schema, %{items: [%{n: 1}, %{}]})
    end

    test "all_errors groups siblings in a Composite" do
      schema = Schema.struct([{:a, Schema.string()}, {:b, Schema.string()}])

      assert %Composite{issues: [%Pointer{key: :a}, %Pointer{key: :b}]} =
               tree(schema, %{}, mode: :all_errors)
    end

    test "a transform decode failure is an Encoding leaf" do
      assert %Encoding{message: "is not a number", value: "abc"} =
               tree(Schema.number_from_string(), "abc")
    end

    test "a failed check is an InvalidValue with its constraint" do
      assert %InvalidValue{constraint: :min} = tree(Schema.string(min: 3), "ab")
    end
  end

  describe "AnyOf keeps union branch detail (what flat errors cannot express)" do
    test "each branch's own issue is preserved" do
      schema = Schema.union([Schema.string(min: 5), Schema.integer(min: 10)])

      assert %AnyOf{value: 3, issues: [string_branch, integer_branch]} = tree(schema, 3)
      assert %InvalidType{expected: "string"} = string_branch
      assert %InvalidValue{constraint: :min} = integer_branch
    end

    test "the flat fold collapses AnyOf to the single legacy union error" do
      schema = Schema.struct([{:id, Schema.union([Schema.string(), Schema.integer()])}])

      assert {:error,
              [
                %Schema.Error{
                  path: [:id],
                  constraint: :union,
                  message: "does not match any union variant"
                }
              ]} =
               Schema.validate(schema, %{id: true})
    end
  end

  describe "to_errors/1 is the flat projection" do
    test "tree and flat agree on paths and constraints" do
      schema = Schema.struct([{:items, Schema.list(Schema.struct([{:n, Schema.integer()}]))}])
      input = %{items: [%{n: 1}, %{}, %{n: "x"}]}

      issue = tree(schema, input, mode: :all_errors)
      {:error, flat} = Schema.validate(schema, input, mode: :all_errors)

      assert Issue.to_errors(issue) == flat
      assert Enum.map(flat, & &1.path) |> Enum.sort() == [[:items, 1, :n], [:items, 2, :n]]
    end
  end

  describe "format/1 (Formatter analog)" do
    test "renders an indented human-readable tree" do
      schema = Schema.struct([{:items, Schema.list(Schema.struct([{:n, Schema.integer()}]))}])
      out = schema |> tree(%{items: [%{}]}) |> Issue.format()

      assert out =~ "items:"
      assert out =~ "[0]"
      assert out =~ "is required"
    end

    test "renders union branches" do
      out = Schema.union([Schema.string(), Schema.integer()]) |> tree(true) |> Issue.format()
      assert out =~ "does not match any union variant"
      assert out =~ "variant 0:"
      assert out =~ "expected string, got true"
    end
  end
end
