defmodule Raggio.Schema.StructDefaultsTest do
  # Struct-literal construction of `schema do struct ... end` modules: `default:`
  # values are baked into the defstruct and required fields (no default, not
  # optional, not nullable) are @enforce_keys — decode/encode are unaffected.
  use ExUnit.Case, async: true

  alias Raggio.Schema

  defmodule Widget do
    use Raggio.Schema

    schema do
      struct(
        req: string(min: 1),
        name: string() |> default("anon"),
        count: integer(0),
        flag: boolean() |> default(false),
        tags: list(string(), default: []),
        meta: record(string(), integer()) |> default(%{}),
        kind: literal(:a, :b) |> default(:a),
        bio: string() |> optional(),
        note: string() |> nullable(),
        stamp: datetime() |> default(fn -> ~U[2026-07-07 00:00:00Z] end)
      )
    end
  end

  defmodule Owner do
    use Raggio.Schema

    schema do
      struct(name: string())
    end
  end

  defmodule Nested do
    use Raggio.Schema

    schema do
      struct(
        owner: Owner,
        inline: struct(foo: string()),
        opt_owner: Owner |> optional()
      )
    end
  end

  defmodule OptionalWithDefault do
    use Raggio.Schema

    schema do
      struct(a: string(), b: string() |> default("x") |> optional())
    end
  end

  describe "baked defaults in struct literals" do
    test "a bare-but-for-required literal gets every baked default" do
      widget = %Widget{req: "r"}

      assert widget.name == "anon"
      assert widget.count == 0
      assert widget.flag == false
      assert widget.tags == []
      assert widget.meta == %{}
      assert widget.kind == :a
    end

    test "a partial literal overrides only the given fields" do
      widget = %Widget{req: "r", name: "bob", tags: ["x"]}

      assert widget.name == "bob"
      assert widget.tags == ["x"]
      assert widget.count == 0
    end

    test "optional and nullable fields default to nil" do
      widget = %Widget{req: "r"}

      assert widget.bio == nil
      assert widget.note == nil
    end

    test "a lazy (0-arity thunk) default is not baked — nil in the literal" do
      assert %Widget{req: "r"}.stamp == nil
    end

    test "an optional field's default is not baked (decode skips it too)" do
      assert %OptionalWithDefault{a: "z"}.b == nil
    end
  end

  describe "@enforce_keys for required fields" do
    test "a struct literal missing a required key raises at compile time" do
      assert_raise ArgumentError, ~r/must also be given.*:req/s, fn ->
        Code.eval_string("%Raggio.Schema.StructDefaultsTest.Widget{}")
      end
    end

    test "module-reference and inline-struct fields are enforced; optional ones are not" do
      assert_raise ArgumentError, ~r/must also be given/, fn ->
        Code.eval_string(
          "%Raggio.Schema.StructDefaultsTest.Nested{owner: %{name: \"a\"}}",
          []
        )
      end

      nested = %Nested{owner: %Owner{name: "a"}, inline: %{foo: "b"}}
      assert nested.opt_owner == nil
    end
  end

  describe "decode/encode semantics are unchanged" do
    test "decode still applies defaults, thunks, and nil for optional/nullable" do
      assert {:ok, decoded} = Widget.decode(%{req: "r"})

      assert %Widget{
               req: "r",
               name: "anon",
               count: 0,
               flag: false,
               tags: [],
               meta: %{},
               kind: :a,
               bio: nil,
               note: nil,
               stamp: %DateTime{}
             } = decoded
    end

    test "a missing required field is still a decode error, not a raise" do
      assert {:error, [%Raggio.Schema.Error{path: [:req]}]} = Widget.decode(%{})
    end

    test "an absent optional field with a default still decodes to nil" do
      assert {:ok, %OptionalWithDefault{b: nil}} = OptionalWithDefault.decode(%{a: "y"})
    end

    test "partial decode still builds the struct despite @enforce_keys" do
      assert {:ok, %Widget{req: nil, name: "bob"}} =
               Schema.validate(Widget.__schema__(), %{name: "bob"}, partial: true)
    end

    test "encode round-trips a decoded struct" do
      assert {:ok, decoded} = Widget.decode(%{req: "r"})
      assert {:ok, encoded} = Widget.encode(decoded)
      assert encoded[:req] == "r"
      refute Map.has_key?(encoded, :__struct__)
    end
  end
end
