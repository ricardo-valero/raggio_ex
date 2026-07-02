defmodule Raggio.Schema.DeclarationUnionTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error
  alias Raggio.Schema.Adapters.JsonSchema

  # --- §7.3 declaration: an opaque custom type -------------------------------

  defmodule Uri do
    use Raggio.Schema.Declaration

    @impl true
    def decode(value) when is_binary(value) do
      case URI.new(value) do
        {:ok, %URI{scheme: scheme} = uri} when not is_nil(scheme) -> {:ok, uri}
        _ -> {:error, "is not a valid URI"}
      end
    end

    def decode(%URI{} = uri), do: {:ok, uri}
    def decode(_), do: {:error, "is not a valid URI"}

    @impl true
    def encode(%URI{} = uri), do: URI.to_string(uri)

    @impl true
    def json_schema, do: %{"type" => "string", "format" => "uri"}
  end

  # --- §7.4 tagged union: notifier-style ---------------------------------------

  defmodule Push do
    use Raggio.Schema

    schema do
      struct(
        kind: literal(:push),
        priority: literal(:high, :low)
      )
    end
  end

  defmodule Webhook do
    use Raggio.Schema

    schema do
      struct(
        kind: literal(:webhook),
        priority: literal(:batch)
      )
    end
  end

  defmodule Notifier do
    use Raggio.Schema

    schema do
      union(:kind, [Push, Webhook])
    end
  end

  describe "declaration (§7.3)" do
    test "decodes through the module's decode/1" do
      assert {:ok, %URI{host: "x.co", scheme: "https"}} =
               Schema.validate(Uri.__schema__(), "https://x.co/a")
    end

    test "decode failure is a structured :declaration error" do
      assert {:error, [%Error{constraint: :declaration, message: "is not a valid URI"}]} =
               Schema.validate(Uri.__schema__(), "no-scheme")
    end

    test "encode reverses via the module's encode/1" do
      {:ok, uri} = Schema.validate(Uri.__schema__(), "https://x.co/a")
      assert {:ok, "https://x.co/a"} = Schema.encode(Uri.__schema__(), uri)
    end

    test "composes as a struct field via the module convention" do
      schema = Schema.struct([{:homepage, Uri}])

      assert {:ok, %{homepage: %URI{host: "x.co"}}} =
               Schema.validate(schema, %{homepage: "https://x.co"})

      assert {:error, [%Error{path: [:homepage], constraint: :declaration}]} =
               Schema.validate(schema, %{homepage: "bad"})
    end

    test "JSON Schema uses the module override" do
      assert JsonSchema.to_json_schema(Uri.__schema__(), root: false) ==
               %{"type" => "string", "format" => "uri"}
    end
  end

  describe "tagged union (§7.4)" do
    test "dispatches on the discriminator to the matching member" do
      assert {:ok, %Push{kind: :push, priority: :low}} =
               Notifier.decode(%{kind: :push, priority: :low})

      assert {:ok, %Webhook{priority: :batch}} =
               Notifier.decode(%{kind: :webhook, priority: :batch})
    end

    test "an unknown tag reports the allowed discriminator values" do
      assert {:error, [%Error{path: [:kind], constraint: :discriminator, value: :sms}]} =
               Notifier.decode(%{kind: :sms, priority: :low})
    end

    test "errors come from the matched member, not 'tried them all'" do
      # invalid notifier/priority pair is unrepresentable
      assert {:error, [%Error{path: [:priority], constraint: :literal}]} =
               Notifier.decode(%{kind: :push, priority: :batch})
    end

    test "a non-map input is a type error" do
      assert {:error, [%Error{constraint: :type}]} = Notifier.decode("fedex")
    end

    test "encode flattens the member struct back to a wire map" do
      {:ok, %Push{} = notifier} = Notifier.decode(%{kind: :push, priority: :low})
      assert {:ok, encoded} = Notifier.encode(notifier)
      assert encoded[:kind] == :push
      refute Map.has_key?(encoded, :__struct__)
    end

    test "a member without the discriminator literal raises at construction" do
      assert_raise ArgumentError, ~r/must declare the discriminator/, fn ->
        Schema.union(:kind, [Push.__schema__(), Schema.struct([{:priority, Schema.string()}])])
      end
    end

    test "non-struct members raise at construction" do
      assert_raise ArgumentError, ~r/must be struct schemas/, fn ->
        Schema.union(:kind, [Push.__schema__(), Schema.string()])
      end
    end

    test "JSON Schema emits oneOf + discriminator" do
      doc = JsonSchema.to_json_schema(Notifier.__schema__(), root: false)
      assert [%{"type" => "object"}, %{"type" => "object"}] = doc["oneOf"]
      assert doc["discriminator"] == %{"propertyName" => "kind"}
    end
  end
end
