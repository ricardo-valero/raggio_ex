defmodule Raggio.Schema.ChecksTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Raggio.Schema
  alias Raggio.Schema.{Check, Error}
  alias Raggio.Schema.Adapters.JsonSchema

  defp error(schema, data) do
    assert {:error, [err]} = Schema.validate(schema, data)
    err
  end

  defp js(schema), do: JsonSchema.to_json_schema(schema, root: false)

  describe "refine/3" do
    test "passes when the predicate holds" do
      schema = Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even")
      assert {:ok, 4} = Schema.validate(schema, 4)
    end

    test "fails with the message and a :refine constraint" do
      schema = Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even")
      assert %Error{constraint: :refine, message: "must be even"} = error(schema, 3)
    end

    test "runs after the type check (type error wins)" do
      schema = Schema.integer() |> Schema.refine(&(&1 > 0), "must be positive")
      assert %Error{constraint: :type} = error(schema, "x")
    end

    test "emits no JSON Schema keywords" do
      schema = Schema.integer() |> Schema.refine(&(&1 > 0), "must be positive")
      assert js(schema) == %{"type" => "integer"}
    end
  end

  describe "check/2" do
    test "attaches a prebuilt Check" do
      schema = Schema.integer() |> Schema.check(Check.greater_than(0))
      assert {:ok, 1} = Schema.validate(schema, 1)
      assert %Error{constraint: :greater_than} = error(schema, 0)
    end
  end

  describe "exclusive bounds" do
    test "greater_than rejects the boundary" do
      schema = Schema.integer(greater_than: 0)
      assert {:ok, 1} = Schema.validate(schema, 1)
      assert %Error{constraint: :greater_than} = error(schema, 0)
    end

    test "less_than rejects the boundary" do
      schema = Schema.integer(less_than: 10)
      assert {:ok, 9} = Schema.validate(schema, 9)
      assert %Error{constraint: :less_than} = error(schema, 10)
    end

    test "gt / lt aliases" do
      assert %Error{constraint: :greater_than} = error(Schema.integer(gt: 0), 0)
      assert %Error{constraint: :less_than} = error(Schema.integer(lt: 0), 0)
    end
  end

  describe "multiple_of / int" do
    test "multiple_of" do
      assert {:ok, 15} = Schema.validate(Schema.integer(multiple_of: 5), 15)
      assert %Error{constraint: :multiple_of} = error(Schema.integer(multiple_of: 5), 7)
    end

    test "int on a float rejects fractional values" do
      schema = Schema.float(int: true)
      assert {:ok, 3.0} = Schema.validate(schema, 3.0)
      assert %Error{constraint: :int} = error(schema, 3.5)
    end
  end

  describe "string content checks" do
    test "non_empty" do
      assert %Error{constraint: :non_empty} = error(Schema.string(non_empty: true), "")
      assert {:ok, "x"} = Schema.validate(Schema.string(non_empty: true), "x")
    end

    test "starts_with / ends_with / includes" do
      assert {:ok, "hello"} = Schema.validate(Schema.string(starts_with: "he"), "hello")
      assert %Error{constraint: :starts_with} = error(Schema.string(starts_with: "he"), "world")
      assert %Error{constraint: :ends_with} = error(Schema.string(ends_with: "lo"), "hey")
      assert %Error{constraint: :includes} = error(Schema.string(includes: "ll"), "hey")
    end

    test "exact length" do
      assert {:ok, "abc"} = Schema.validate(Schema.string(length: 3), "abc")
      assert %Error{constraint: :length} = error(Schema.string(length: 3), "ab")
    end

    test "uppercase / lowercase" do
      assert %Error{constraint: :uppercase} = error(Schema.string(uppercase: true), "aB")
      assert %Error{constraint: :lowercase} = error(Schema.string(lowercase: true), "aB")
    end

    test "named formats" do
      assert {:ok, _} = Schema.validate(Schema.string(format: :email), "a@b.co")
      assert %Error{constraint: :format} = error(Schema.string(format: :email), "nope")
      assert %Error{constraint: :format} = error(Schema.string(format: :uuid), "not-a-uuid")
    end
  end

  describe "list non_empty" do
    test "rejects an empty list" do
      schema = Schema.list(Schema.integer(), non_empty: true)
      assert {:ok, [1]} = Schema.validate(schema, [1])
      assert %Error{constraint: :non_empty} = error(schema, [])
    end
  end

  describe "JSON Schema meta for the new checks" do
    test "numeric checks" do
      assert js(Schema.integer(greater_than: 0)) == %{
               "type" => "integer",
               "exclusiveMinimum" => 0
             }

      assert js(Schema.integer(less_than: 10)) == %{"type" => "integer", "exclusiveMaximum" => 10}
      assert js(Schema.integer(multiple_of: 5)) == %{"type" => "integer", "multipleOf" => 5}
    end

    test "string checks" do
      assert js(Schema.string(non_empty: true)) == %{"type" => "string", "minLength" => 1}
      assert js(Schema.string(starts_with: "he")) == %{"type" => "string", "pattern" => "^he"}
      assert js(Schema.string(format: :email)) == %{"type" => "string", "format" => "email"}

      assert js(Schema.string(length: 3)) == %{
               "type" => "string",
               "minLength" => 3,
               "maxLength" => 3
             }
    end
  end

  describe "properties" do
    property "greater_than accepts x > n and rejects x <= n" do
      check all(n <- integer(-20..20), delta <- integer(1..50)) do
        schema = Schema.integer(greater_than: n)
        assert {:ok, _} = Schema.validate(schema, n + delta)
        assert {:error, [%Error{constraint: :greater_than}]} = Schema.validate(schema, n)
      end
    end

    property "custom refine agrees with its predicate" do
      check all(v <- integer()) do
        schema = Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even")

        case Schema.validate(schema, v) do
          {:ok, ^v} -> assert rem(v, 2) == 0
          {:error, [%Error{constraint: :refine}]} -> assert rem(v, 2) != 0
        end
      end
    end
  end
end
