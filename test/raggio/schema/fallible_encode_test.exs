defmodule Raggio.Schema.FallibleEncodeTest do
  @moduledoc "Task 5.7 / D14: encode is defensive — errors as values, mirroring decode."
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error
  alias Raggio.Schema.Issue.{AnyOf, Encoding, InvalidType, Pointer}

  defmodule Code do
    use Raggio.Schema.Declaration

    @impl true
    def decode(v) when is_binary(v), do: {:ok, String.upcase(v)}
    def decode(_), do: {:error, "must be a string"}

    @impl true
    def encode(v) when is_binary(v), do: {:ok, v}
    def encode(_), do: {:error, "cannot encode as code"}
  end

  test "a fallible encode getter returns an Encoding issue, not a raise" do
    schema =
      Schema.transform(Schema.string(), &{:ok, &1}, fn
        v when is_binary(v) -> v
        _ -> {:error, "cannot encode as text"}
      end)

    assert {:ok, "x"} = Schema.encode(schema, "x")

    assert {:error, [%Error{constraint: :transform, message: "cannot encode as text"}]} =
             Schema.encode(schema, 42)
  end

  test "declarations may return {:ok, v} / {:error, msg} from encode" do
    schema = Schema.declare(Code)
    assert {:ok, "AB"} = Schema.encode(schema, "AB")
    assert {:error, [%Error{message: "cannot encode as code"}]} = Schema.encode(schema, 42)
  end

  test "wrong-shaped input yields InvalidType instead of pass-through" do
    assert {:error, [%Error{constraint: :type, message: "expected string"}]} =
             Schema.encode(Schema.string(), 42)

    schema = Schema.struct([{:name, Schema.string()}])

    assert {:error, [%Error{constraint: :type, message: "expected map"}]} =
             Schema.encode(schema, "no")

    assert {:error, [%Error{path: [:name], constraint: :type}]} =
             Schema.encode(schema, %{name: 1})
  end

  test "decode_to target validates before the getter runs (no FunctionClauseError)" do
    schema =
      Schema.string()
      |> Schema.decode_to(Schema.literal(["on", "off"]), &{:ok, String.downcase(&1)})

    assert {:ok, "on"} = Schema.encode(schema, "on")
    assert {:error, [%Error{constraint: :literal}]} = Schema.encode(schema, "maybe")
  end

  test "a union value matching no member errors instead of passing through" do
    schema = Schema.union([Schema.string(), Schema.integer()])
    assert {:ok, "a"} = Schema.encode(schema, "a")
    assert {:error, [%Error{constraint: :union}]} = Schema.encode(schema, true)
  end

  test "checks re-validate the encoded output (getter → checks symmetry)" do
    assert {:error, [%Error{constraint: :min}]} = Schema.encode(Schema.string(min: 3), "ab")
    assert {:ok, "abc"} = Schema.encode(Schema.string(min: 3), "abc")
  end

  test "mode: :all_errors collects sibling field failures" do
    schema = Schema.struct([{:a, Schema.string()}, {:b, Schema.integer()}])
    assert {:error, errors} = Schema.encode(schema, %{a: 1, b: "x"}, mode: :all_errors)
    assert Enum.map(errors, & &1.path) |> Enum.sort() == [[:a], [:b]]
  end

  test "errors: :tree returns the Issue tree with Encoding/Pointer/AnyOf nodes" do
    schema = Schema.struct([{:id, Schema.union([Schema.string(), Schema.integer()])}])

    assert {:error, %Pointer{key: :id, issue: %AnyOf{issues: [%InvalidType{}, %InvalidType{}]}}} =
             Schema.encode(schema, %{id: true}, errors: :tree)

    t = Schema.transform(Schema.string(), &{:ok, &1}, fn _ -> {:error, "nope"} end)
    assert {:error, %Encoding{message: "nope"}} = Schema.encode(t, 1, errors: :tree)
  end

  test "encode!/2 raises ValidationError (encodeSync analog)" do
    assert "ok" = Schema.encode!(Schema.string(), "ok")

    assert_raise Raggio.Schema.ValidationError, fn ->
      Schema.encode!(Schema.string(), 42)
    end
  end

  test "list element failures are located by index" do
    schema = Schema.list(Schema.integer())
    assert {:error, [%Error{path: [1], constraint: :type}]} = Schema.encode(schema, [1, "x", 3])
  end
end
