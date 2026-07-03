defmodule Raggio.Schema.AcceptanceTest do
  @moduledoc """
  Acceptance gate for the consumer-driven parity plan (task 7.7): mirrors the behaviour
  suite of the downstream effect-smol-shaped engine this library is meant to back —
  per combinator, decode success + failure, encode, defaults, optionality, nested error
  paths, constraint metadata, and AST introspection. Fixture names/fields are neutral.

  Wire conventions exercised here (and now supported by the engine):
  string-keyed input maps, atom literals decoding from their string wire form,
  nil fields omitted on encode.
  """
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.{AST, Error}

  ## Fixtures (anonymized)

  defmodule ScaleKind do
    use Raggio.Schema

    schema do
      literal(:metric, :imperial)
    end
  end

  defmodule Code do
    use Raggio.Schema.Declaration

    @impl true
    def decode(v) when is_binary(v), do: {:ok, v |> String.trim() |> String.upcase()}
    def decode(_), do: {:error, "must be a string"}

    @impl true
    def encode(v), do: v

    @impl true
    def json_schema, do: %{"type" => "string"}
  end

  defmodule Item do
    use Raggio.Schema

    schema do
      struct(
        weight: float(gt: 0),
        scale: ScaleKind,
        memo: string() |> optional(),
        marked: boolean() |> default(false)
      )
    end
  end

  defmodule Profile do
    use Raggio.Schema

    schema do
      struct(
        label: string(min: 1, max: 5),
        contact: string(pattern: ~r/@/),
        level: integer(min: 0, max: 120),
        style: literal(:compact, :wide) |> default(:compact)
      )
    end
  end

  defmodule Region do
    use Raggio.Schema

    schema do
      struct(zone: string(), code: Code)
    end
  end

  defmodule Order do
    use Raggio.Schema

    schema do
      struct(
        dest: Region,
        items: list(struct(weight: float(gt: 0), scale: ScaleKind), min: 1)
      )
    end
  end

  defmodule Ref do
    use Raggio.Schema

    schema do
      struct(id: union(integer(), string()))
    end
  end

  defmodule Alpha do
    use Raggio.Schema

    schema do
      struct(tag: literal(:alpha), mode: literal(:fast, :slow))
    end
  end

  defmodule Beta do
    use Raggio.Schema

    schema do
      struct(tag: literal(:beta), mode: literal(:solo))
    end
  end

  defmodule Channel do
    use Raggio.Schema

    schema do
      union(:tag, [Alpha, Beta])
    end
  end

  defmodule Style do
    use Raggio.Schema

    schema do
      literal(:solid, :dotted, :dashed)
    end
  end

  defmodule Sketch do
    use Raggio.Schema

    schema do
      struct(style: Style |> default(:solid))
    end
  end

  defmodule SizeCode do
    use Raggio.Schema

    schema do
      any()
      |> decode_to(
        literal([:small, :medium, :large]),
        &{:ok, if(is_binary(&1), do: String.downcase(&1), else: &1)}
      )
    end
  end

  defmodule RegionCode do
    use Raggio.Schema

    schema do
      any()
      |> decode_to(
        literal(["AA", "BB"]),
        &{:ok, if(is_binary(&1), do: String.upcase(&1), else: &1)}
      )
    end
  end

  defmodule Combo do
    use Raggio.Schema

    schema do
      struct(size: SizeCode, code: RegionCode)
    end
  end

  ## Primitives

  describe "primitives" do
    test "decode accepts the right type, rejects the wrong one" do
      assert {:ok, %Profile{label: "ab", contact: "a@b", level: 5}} =
               Profile.decode(%{"label" => "ab", "contact" => "a@b", "level" => 5})

      assert {:error, [%Error{path: [:label], constraint: :type}]} =
               Profile.decode(%{"label" => 1, "contact" => "a@b", "level" => 5})
    end

    test "integer rejects a float; float widens an integer" do
      assert {:error, [%Error{path: [:level], constraint: :type}]} =
               Profile.decode(%{"label" => "ab", "contact" => "a@b", "level" => 1.5})

      assert {:ok, %Item{weight: 2.0}} = Item.decode(%{"weight" => 2, "scale" => "metric"})
      assert {:ok, %Item{weight: 2.5}} = Item.decode(%{"weight" => 2.5, "scale" => "metric"})
    end
  end

  ## Literals

  describe "literal" do
    test "a single atom literal decodes from its string wire form" do
      assert {:ok, %Alpha{tag: :alpha}} = Alpha.decode(%{"tag" => "alpha", "mode" => "slow"})
    end

    test "a literal set accepts members and rejects others" do
      assert {:ok, %Profile{style: :wide}} =
               Profile.decode(%{
                 "label" => "a",
                 "contact" => "a@b",
                 "level" => 1,
                 "style" => "wide"
               })

      assert {:error, [%Error{path: [:style], constraint: :literal}]} =
               Profile.decode(%{
                 "label" => "a",
                 "contact" => "a@b",
                 "level" => 1,
                 "style" => "huge"
               })
    end
  end

  ## Struct

  describe "struct fields" do
    test "emits a struct with nil defaults for the declared fields" do
      assert %Item{weight: nil, scale: nil, memo: nil} = %Item{}
    end

    test "applies a default when the field is absent" do
      assert {:ok, %Item{marked: false}} = Item.decode(%{"weight" => 1.0, "scale" => "metric"})

      assert {:ok, %Profile{style: :compact}} =
               Profile.decode(%{"label" => "a", "contact" => "a@b", "level" => 1})
    end

    test "optional field: absent stays nil, explicit null stays nil" do
      assert {:ok, %Item{memo: nil}} = Item.decode(%{"weight" => 1.0, "scale" => "metric"})

      assert {:ok, %Item{memo: nil}} =
               Item.decode(%{"weight" => 1.0, "scale" => "metric", "memo" => nil})
    end

    test "required field missing → :required at the field path" do
      assert {:error, [%Error{path: [:weight], constraint: :required, message: "is required"}]} =
               Item.decode(%{"scale" => "metric"})
    end

    test "extra keys are ignored (and dropped from the output)" do
      assert {:ok, %Item{}} =
               Item.decode(%{"weight" => 1.0, "scale" => "metric", "surprise" => "x"})
    end

    test "accepts atom-keyed input too" do
      assert {:ok, %Item{weight: 1.0, scale: :metric}} =
               Item.decode(%{weight: 1.0, scale: :metric})
    end
  end

  ## Array

  describe "array" do
    @dest %{"zone" => "US", "code" => "10001"}

    test "decodes each element" do
      input = %{
        "dest" => @dest,
        "items" => [
          %{"weight" => 1.0, "scale" => "metric"},
          %{"weight" => 2.0, "scale" => "imperial"}
        ]
      }

      assert {:ok, %Order{items: [%{weight: 1.0}, %{weight: 2.0}]}} = Order.decode(input)
    end

    test "min items rejects an empty list" do
      assert {:error, [%Error{path: [:items], constraint: :min}]} =
               Order.decode(%{"dest" => @dest, "items" => []})
    end

    test "an element error is located by index then field" do
      input = %{
        "dest" => @dest,
        "items" => [%{"weight" => 1.0, "scale" => "metric"}, %{"scale" => "metric"}]
      }

      assert {:error, [%Error{path: [:items, 1, :weight], constraint: :required}]} =
               Order.decode(input)
    end

    test "rejects a non-list" do
      assert {:error, [%Error{path: [:items], constraint: :type}]} =
               Order.decode(%{"dest" => @dest, "items" => "nope"})
    end
  end

  ## Named literal sets

  describe "named literal set modules" do
    test "decodes the wire string to the atom, rejects others" do
      assert {:ok, :solid} = Style.decode("solid")
      assert {:ok, :dotted} = Style.decode("dotted")
      assert {:error, [%Error{constraint: :literal}]} = Style.decode("wavy")
    end

    test "is reusable as a field type with a default" do
      assert {:ok, %Sketch{style: :dotted}} = Sketch.decode(%{"style" => "dotted"})
      assert {:ok, %Sketch{style: :solid}} = Sketch.decode(%{})
      assert {:error, _} = Sketch.decode(%{"style" => "wavy"})
    end
  end

  describe "normalizing literal sets" do
    test "downcase folds the incoming string before matching (atom values)" do
      assert {:ok, :small} = SizeCode.decode("SMALL")
      assert {:ok, :small} = SizeCode.decode("small")
      assert {:error, [%Error{constraint: :literal}]} = SizeCode.decode("tiny")
    end

    test "upcase folds the incoming string and preserves the string value" do
      assert {:ok, "AA"} = RegionCode.decode("aa")
      assert {:ok, "AA"} = RegionCode.decode("AA")
      assert {:error, [%Error{constraint: :literal}]} = RegionCode.decode("zz")
    end

    test "is reusable as a field type, normalizing each element on decode" do
      assert {:ok, %Combo{size: :small, code: "AA"}} =
               Combo.decode(%{"size" => "SMALL", "code" => "aa"})

      assert {:error, [%Error{path: [:size]}]} =
               Combo.decode(%{"size" => "nope", "code" => "AA"})
    end
  end

  ## Unions

  describe "untagged union" do
    test "tries each member; first that decodes wins" do
      assert {:ok, %Ref{id: 7}} = Ref.decode(%{"id" => 7})
      assert {:ok, %Ref{id: "abc"}} = Ref.decode(%{"id" => "abc"})
    end

    test "rejects a value matching no member" do
      assert {:error, [%Error{path: [:id], constraint: :union}]} = Ref.decode(%{"id" => true})
    end
  end

  describe "tagged union" do
    test "decodes to the matching member struct, constrained to its catalog" do
      assert {:ok, %Alpha{tag: :alpha, mode: :fast}} =
               Channel.decode(%{"tag" => "alpha", "mode" => "fast"})

      assert {:ok, %Beta{tag: :beta, mode: :solo}} =
               Channel.decode(%{"tag" => "beta", "mode" => "solo"})
    end

    test "rejects a mode from another variant's catalog" do
      assert {:error, [%Error{path: [:mode], constraint: :literal}]} =
               Channel.decode(%{"tag" => "alpha", "mode" => "solo"})
    end

    test "rejects an unknown discriminator" do
      assert {:error, [%Error{path: [:tag], constraint: :discriminator}]} =
               Channel.decode(%{"tag" => "gamma", "mode" => "fast"})
    end

    test "missing discriminator reports the discriminator path" do
      assert {:error, [%Error{path: [:tag], constraint: :discriminator, value: nil}]} =
               Channel.decode(%{"mode" => "fast"})
    end

    test "a member without the discriminator field raises at build time" do
      assert_raise ArgumentError, ~r/must declare the discriminator/, fn ->
        Schema.union(:tag, [Alpha.__schema__(), Schema.struct([{:mode, Schema.string()}])])
      end
    end
  end

  ## Checks

  describe "checks" do
    test "numbers: gt / min / max" do
      assert {:error, [%Error{path: [:weight], constraint: :greater_than}]} =
               Item.decode(%{"weight" => 0, "scale" => "metric"})

      assert {:error, [%Error{path: [:level], constraint: :min}]} =
               Profile.decode(%{"label" => "a", "contact" => "a@b", "level" => -1})

      assert {:error, [%Error{path: [:level], constraint: :max}]} =
               Profile.decode(%{"label" => "a", "contact" => "a@b", "level" => 200})
    end

    test "strings: length and pattern" do
      assert {:error, [%Error{path: [:label], constraint: :min}]} =
               Profile.decode(%{"label" => "", "contact" => "a@b", "level" => 1})

      assert {:error, [%Error{path: [:label], constraint: :max}]} =
               Profile.decode(%{"label" => "toolong", "contact" => "a@b", "level" => 1})

      assert {:error, [%Error{path: [:contact], constraint: :pattern}]} =
               Profile.decode(%{"label" => "ab", "contact" => "no-at", "level" => 1})
    end

    test "constraint metadata is on the AST node for the JSON-Schema reader" do
      {_n, weight} = Enum.find(Item.__schema__().fields, &(elem(&1, 0) == :weight))
      assert [%{meta: %{"exclusiveMinimum" => 0}}] = weight.checks

      {_n, level} = Enum.find(Profile.__schema__().fields, &(elem(&1, 0) == :level))
      assert Enum.map(level.checks, & &1.meta) == [%{"minimum" => 0}, %{"maximum" => 120}]
    end
  end

  ## Declarations

  describe "declaration" do
    test "normalizes on decode" do
      assert {:ok, %Region{code: "M5V 3A8"}} =
               Region.decode(%{"zone" => "US", "code" => "  m5v 3a8 "})
    end

    test "surfaces its own decode error at the field path" do
      assert {:error,
              [%Error{path: [:code], constraint: :declaration, message: "must be a string"}]} =
               Region.decode(%{"zone" => "US", "code" => 123})
    end
  end

  ## Error collection

  describe "error collection (mode: :all_errors)" do
    test "collects every sibling field error" do
      assert {:error, errors} =
               Schema.validate(Profile.__schema__(), %{"label" => "", "level" => 200},
                 mode: :all_errors
               )

      by_path = Map.new(errors, &{&1.path, &1.constraint})
      assert by_path[[:label]] == :min
      assert by_path[[:contact]] == :required
      assert by_path[[:level]] == :max
    end

    test "nests deep paths (struct → field)" do
      input = %{"dest" => %{"zone" => "US"}, "items" => [%{"weight" => 1.0, "scale" => "metric"}]}

      assert {:error, [%Error{path: [:dest, :code], constraint: :required}]} =
               Order.decode(input)
    end
  end

  ## AST introspection

  describe "AST introspection" do
    test "struct node exposes module + ordered fields" do
      ast = Item.__schema__()
      assert ast.kind == :struct
      assert ast.module == Item
      assert Keyword.keys(ast.fields) == [:weight, :scale, :memo, :marked]
    end

    test "union node exposes discriminator + members" do
      ast = Channel.__schema__()
      assert ast.kind == :union
      assert ast.discriminator == :tag
      assert length(ast.elements) == 2
    end

    test "a literal field is a :literal node" do
      {_n, tag} = Enum.find(Alpha.__schema__().fields, &(elem(&1, 0) == :tag))
      assert %AST{kind: :literal, values: [:alpha]} = tag
    end

    test "array node carries its element + item checks" do
      {_n, items} = Enum.find(Order.__schema__().fields, &(elem(&1, 0) == :items))
      assert items.kind == :list
      assert items.inner.kind == :struct
      assert [%{meta: %{"minItems" => 1}}] = items.checks
    end
  end

  ## Encode (round-trip)

  describe "encode" do
    test "round-trips a scalar struct through decode" do
      {:ok, item} =
        Item.decode(%{"weight" => 2.0, "scale" => "metric", "memo" => "x", "marked" => true})

      {:ok, encoded} = Item.encode(item)
      assert {:ok, ^item} = Item.decode(encoded)
    end

    test "skips nil fields on encode" do
      {:ok, item} = Item.decode(%{"weight" => 1.0, "scale" => "metric"})
      {:ok, encoded} = Item.encode(item)
      refute Map.has_key?(encoded, :memo)
    end

    test "round-trips nested structs + arrays" do
      input = %{
        "dest" => %{"zone" => "US", "code" => "10001"},
        "items" => [%{"weight" => 1.0, "scale" => "metric"}]
      }

      {:ok, order} = Order.decode(input)
      {:ok, encoded} = Order.encode(order)
      assert {:ok, ^order} = Order.decode(encoded)
    end

    test "tagged union round-trips" do
      {:ok, channel} = Channel.decode(%{"tag" => "alpha", "mode" => "slow"})
      {:ok, encoded} = Channel.encode(channel)
      assert encoded == %{tag: :alpha, mode: :slow}
      assert {:ok, ^channel} = Channel.decode(encoded)
    end
  end

  ## decode!

  describe "decode!/1" do
    test "raises on failure" do
      assert_raise Raggio.Schema.ValidationError, fn ->
        Item.decode!(%{"weight" => 0, "scale" => "metric"})
      end
    end

    test "returns the value on success" do
      assert %Item{weight: 1.0} = Item.decode!(%{"weight" => 1.0, "scale" => "metric"})
    end
  end
end
