defmodule Raggio.Schema.DefinitionTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema.AST

  defmodule Status do
    use Raggio.Schema

    schema do
      literal("on", "off")
    end
  end

  defmodule Level do
    use Raggio.Schema

    schema do
      any()
      |> decode_to(
        literal(["low", "high"]),
        &{:ok, if(is_binary(&1), do: String.downcase(&1), else: &1)}
      )
    end
  end

  defmodule Mode do
    use Raggio.Schema

    # list form still works
    schema do
      literal([:read, :write])
    end
  end

  defmodule User do
    use Raggio.Schema

    schema do
      struct(
        name: string(min: 1),
        age: integer(min: 0),
        status: literal(:active, :inactive),
        bio: string() |> optional()
      )
    end
  end

  # Exercises every branch of the @type t derivation — compiling this module IS the
  # assertion that the generated typespec is well-formed. Combinators unqualified.
  defmodule Kitchen do
    use Raggio.Schema

    schema do
      struct(
        count: number_from_string(),
        tags: list(string()),
        kind: union(string(), integer()),
        when: datetime_from_iso8601(),
        price: decimal() |> nullable(),
        even: integer() |> refine(&(rem(&1, 2) == 0), "must be even"),
        meta: record(string(), integer())
      )
    end
  end

  # Module composition + inline nested struct.
  defmodule Device do
    use Raggio.Schema

    schema do
      struct(
        name: string(min: 1),
        status: Status,
        owner: User,
        extra: struct(foo: string(min: 1), bar: string(min: 2)) |> optional()
      )
    end
  end

  # Generic head: the module IS a union of other schema modules (untagged, variadic).
  defmodule Actor do
    use Raggio.Schema

    schema do
      union(User, Device)
    end
  end

  describe "schema do struct ... end" do
    test "defines the struct with the declared fields" do
      assert %User{} |> Map.keys() |> Enum.sort() == [:__struct__, :age, :bio, :name, :status]
    end

    test "__schema__/0 returns the runtime schema bound to the module" do
      assert %AST{kind: :struct, module: User, fields: fields} = User.__schema__()
      assert Keyword.keys(fields) == [:name, :age, :status, :bio]
    end

    test "decode builds the struct with validated values" do
      assert {:ok, %User{name: "A", age: 30, status: :active}} =
               User.decode(%{name: "A", age: 30, status: :active})
    end

    test "absent optional fields fall back to the struct default (nil)" do
      assert {:ok, %User{bio: nil}} = User.decode(%{name: "A", age: 1, status: :active})
    end

    test "field transforms decode into the struct" do
      assert {:ok, %Kitchen{count: 42}} =
               Kitchen.decode(%{
                 count: "42",
                 tags: ["a"],
                 kind: 1,
                 when: "2026-07-02T12:00:00Z",
                 price: nil,
                 even: 2,
                 meta: %{"a" => 1}
               })
    end

    test "returns structured errors" do
      assert {:error, [%Raggio.Schema.Error{path: [:age], constraint: :min}]} =
               User.decode(%{name: "A", age: -1, status: :active})
    end

    test "decode!/1 raises on invalid data" do
      assert_raise Raggio.Schema.ValidationError, fn ->
        User.decode!(%{name: "A", age: -1, status: :active})
      end
    end

    test "encode round-trips through the wire shape" do
      wire = %{
        count: "42",
        tags: ["a"],
        kind: 1,
        when: "2026-07-02T12:00:00Z",
        price: nil,
        even: 2,
        meta: %{"a" => 1}
      }

      assert {:ok, %Kitchen{} = decoded} = Kitchen.decode(wire)
      assert {:ok, encoded} = Kitchen.encode(decoded)
      assert encoded[:count] == "42"
      assert encoded[:when] == "2026-07-02T12:00:00Z"
      refute Map.has_key?(encoded, :__struct__)
    end

    test "empty struct raises at compile time" do
      assert_raise ArgumentError, ~r/at least one field/, fn ->
        defmodule Empty do
          use Raggio.Schema

          schema do
            struct([])
          end
        end
      end
    end
  end

  describe "nested inline combinators" do
    test "an inline nested struct validates and rebuilds" do
      assert {:ok, %Device{extra: %{foo: "x", bar: "yy"}}} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: 1, status: :active},
                 extra: %{foo: "x", bar: "yy"}
               })
    end

    test "nested struct errors carry the full path" do
      assert {:error, [%Raggio.Schema.Error{path: [:extra, :bar], constraint: :min}]} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: 1, status: :active},
                 extra: %{foo: "x", bar: "y"}
               })
    end

    test "optional inline struct may be absent" do
      assert {:ok, %Device{extra: nil}} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: 1, status: :active}
               })
    end
  end

  describe "schema do literal ... end" do
    test "variadic form decodes a member and rejects a non-member" do
      assert {:ok, "on"} = Status.decode("on")
      assert {:error, [%Raggio.Schema.Error{constraint: :literal}]} = Status.decode("blue")
    end

    test "values/0 exposes the set" do
      assert Status.values() == ["on", "off"]
    end

    test "list form still works (atom values)" do
      assert {:ok, :read} = Mode.decode(:read)
      assert {:error, _} = Mode.decode(:delete)
    end

    test "unsugared normalizing set folds the wire value" do
      assert {:ok, "high"} = Level.decode("HIGH")
      assert {:ok, "low"} = Level.decode("Low")
      assert {:error, [%Raggio.Schema.Error{constraint: :literal}]} = Level.decode("MEDIUM")
    end

    test "encode is the canonical value" do
      assert {:ok, "high"} = Level.encode("high")
    end
  end

  describe "schema do union ... end (generic head)" do
    test "variadic union decodes to whichever member matches" do
      assert {:ok, %User{}} = Actor.decode(%{name: "A", age: 1, status: :active})

      assert {:ok, %Device{}} =
               Actor.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: 1, status: :active}
               })
    end

    test "rejects a value matching no member" do
      assert {:error, [%Raggio.Schema.Error{constraint: :union}]} = Actor.decode(%{})
    end
  end

  describe "module composition" do
    test "a literal-set module is usable as a field schema" do
      assert {:ok, %Device{status: "on"}} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: 1, status: :active}
               })
    end

    test "an embedded schema module decodes to its own struct" do
      assert {:ok, %Device{owner: %User{name: "A"}}} =
               Device.decode(%{
                 name: "lamp",
                 status: "off",
                 owner: %{name: "A", age: 1, status: :active}
               })
    end

    test "nested errors carry the full path" do
      assert {:error, [%Raggio.Schema.Error{path: [:owner, :age]}]} =
               Device.decode(%{
                 name: "lamp",
                 status: "on",
                 owner: %{name: "A", age: -1, status: :active}
               })
    end

    test "runtime combinators also accept modules" do
      schema = Raggio.Schema.list(Status)
      assert {:ok, ["on", "off"]} = Raggio.Schema.validate(schema, ["on", "off"])
    end

    test "optional/nullable/default resolve module schemas (pipe-friendly)" do
      schema =
        Raggio.Schema.struct(
          a: Raggio.Schema.optional(Status),
          b: Raggio.Schema.nullable(Status),
          c: Raggio.Schema.default(Status, "on")
        )

      assert {:ok, %{b: nil, c: "on"}} = Raggio.Schema.validate(schema, %{b: nil})
      assert {:ok, %{a: "off"}} = Raggio.Schema.validate(schema, %{a: "off", b: nil})
    end
  end

  describe "scoping fence" do
    test "Kernel.struct/2 is untouched outside the schema block" do
      # this test module `use`s Raggio.Schema — Kernel.struct must still work here
      assert %User{name: "K"} = Kernel.struct(User, %{name: "K"})
      assert %User{name: "K"} = struct(User, %{name: "K"})
    end
  end

  defmodule AllErrors do
    use Raggio.Schema, decode: [mode: :all_errors]

    schema do
      struct(
        name: string(min: 1),
        age: integer(min: 0)
      )
    end
  end

  describe "use Raggio.Schema, decode: [...] defaults" do
    test "the module default applies to bare decode/1" do
      assert {:error, errors} = AllErrors.decode(%{name: "", age: -1})
      assert length(errors) == 2
    end

    test "call-site options win over the module default" do
      assert {:error, [_single]} = AllErrors.decode(%{name: "", age: -1}, mode: :fail_fast)
    end

    test "decode!/1 carries the default too" do
      error =
        assert_raise Raggio.Schema.ValidationError, fn ->
          AllErrors.decode!(%{name: "", age: -1})
        end

      assert length(error.errors) == 2
    end

    test "without the option, decode stays fail-fast" do
      assert {:error, [_single]} = User.decode(%{name: "", age: -1, status: :active})
    end
  end

  defmodule ServiceCatalog do
    def services, do: [:priority, :ground]
  end

  defmodule ComputedSet do
    use Raggio.Schema

    schema do
      literal(ServiceCatalog.services())
    end
  end

  defmodule SigilSet do
    use Raggio.Schema

    schema do
      literal(~w(usd mxn))
    end
  end

  defmodule ComputedField do
    use Raggio.Schema

    schema do
      struct(service: literal(ServiceCatalog.services()))
    end
  end

  defmodule ComputedNormalizing do
    use Raggio.Schema

    schema do
      any()
      |> decode_to(
        literal(ServiceCatalog.services()),
        &{:ok, if(is_binary(&1), do: String.downcase(&1), else: &1)}
      )
    end
  end

  describe "runtime-computed literal sets" do
    test "a computed list is the set, not a one-list literal" do
      assert {:ok, :priority} = ComputedSet.decode(:priority)
      assert {:error, _} = ComputedSet.decode(:overnight)
      # regression: the miswrapped form accepted the whole list as one literal value
      assert {:error, _} = ComputedSet.decode([:priority, :ground])
    end

    test "values/0 evaluates the expression" do
      assert ComputedSet.values() == [:priority, :ground]
    end

    test "a sigil list is the set" do
      assert {:ok, "usd"} = SigilSet.decode("usd")
      assert {:error, _} = SigilSet.decode("eur")
      assert SigilSet.values() == ~w(usd mxn)
    end

    test "computed sets work as inline struct fields" do
      assert {:ok, %ComputedField{service: :ground}} = ComputedField.decode(%{service: :ground})
      assert {:error, _} = ComputedField.decode(%{service: :express})
    end

    test "computed sets work as a decode_to target (normalizing set)" do
      assert {:ok, :priority} = ComputedNormalizing.decode("PRIORITY")
      assert {:error, _} = ComputedNormalizing.decode("EXPRESS")
      assert ComputedNormalizing.values() == [:priority, :ground]
    end
  end

  defmodule Annotated do
    use Raggio.Schema

    schema do
      datetime_from_iso8601() |> annotate(%{format: "date-time"})
    end
  end

  describe "annotate/2" do
    test "merges metadata onto the node without touching validation" do
      assert Annotated.__schema__().metadata == %{format: "date-time"}
      assert {:ok, %DateTime{}} = Annotated.decode("2026-07-02T12:00:00Z")
      assert {:error, _} = Annotated.decode("not-a-date")
    end

    test "merges over existing metadata and resolves modules" do
      node = Raggio.Schema.annotate(Annotated, %{title: "When"})
      assert node.metadata == %{format: "date-time", title: "When"}
    end
  end
end
