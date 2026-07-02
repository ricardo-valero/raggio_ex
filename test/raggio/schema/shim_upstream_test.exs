defmodule Raggio.Schema.ShimUpstreamTest do
  @moduledoc "Tasks 7.8–7.10: behaviors upstreamed from the production shim."
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error
  alias Raggio.Schema.Adapters.JsonSchema

  ## 7.10 fixtures — normalizing literal sets

  defmodule Size do
    use Raggio.Schema

    schema do
      literal([:small, :large], decode: :downcase)
    end
  end

  defmodule Money do
    use Raggio.Schema

    schema do
      literal(["USD", "MXN"], decode: :upcase)
    end
  end

  ## 7.8 fixtures — module validate/1 (cross-field, transforming, field-targeted)

  defmodule Region do
    use Raggio.Schema

    schema do
      struct(zone: string(), code: string())
    end

    # normalize, then cross-check two fields; may transform the struct
    def validate(%__MODULE__{zone: "north"} = r) do
      cond do
        String.length(r.code) != 5 -> {:error, :code, "must be 5 characters for north"}
        r.code != String.upcase(r.code) -> {:ok, %{r | code: String.upcase(r.code)}}
        true -> :ok
      end
    end

    def validate(_), do: :ok
  end

  defmodule Pair do
    use Raggio.Schema

    schema do
      struct(amount: number() |> optional(), currency: string() |> optional())
    end

    def validate(%__MODULE__{amount: a, currency: nil}) when not is_nil(a),
      do: {:error, "currency must be set when amount is set"}

    def validate(_), do: :ok
  end

  defmodule Shipment do
    use Raggio.Schema

    schema do
      struct(label: string(), dest: Region)
    end
  end

  describe "7.10 — non-lossy normalizing literal sets" do
    test "already-canonical atoms pass through (the bug)" do
      assert {:ok, :small} = Size.decode(:small)
    end

    test "already-canonical strings pass through" do
      assert {:ok, "USD"} = Money.decode("USD")
    end

    test "string wire input is case-folded to the canonical value" do
      assert {:ok, :small} = Size.decode("SMALL")
      assert {:ok, "MXN"} = Money.decode("mxn")
    end

    test "non-members still fail" do
      assert {:error, [%Error{constraint: :transform}]} = Size.decode("tiny")
      assert {:error, [%Error{constraint: :transform}]} = Size.decode(42)
    end

    test "JSON Schema projects the closed set, not a bare string" do
      assert JsonSchema.to_json_schema(Size.__schema__(), root: false) ==
               %{"type" => "string", "enum" => ["small", "large"]}

      assert JsonSchema.to_json_schema(Money.__schema__(), root: false) ==
               %{"type" => "string", "enum" => ["USD", "MXN"]}
    end
  end

  describe "7.9 — decode/2 with options on generated wrappers" do
    test "mode: :all_errors collects every failure" do
      assert {:error, errors} = Region.decode(%{}, mode: :all_errors)
      assert Enum.map(errors, & &1.path) |> Enum.sort() == [[:code], [:zone]]
    end

    test "errors: :tree returns the issue tree" do
      assert {:error, %Raggio.Schema.Issue.Pointer{}} = Region.decode(%{code: "x"}, errors: :tree)
    end

    test "decode/1 unchanged" do
      assert {:error, [%Error{}]} = Region.decode(%{})
    end
  end

  describe "7.8 — interpreter-native module validate/1" do
    test "cross-field rule: two fields together" do
      assert {:error, [%Error{constraint: :validate, message: "currency must be set" <> _}]} =
               Pair.decode(%{amount: 5})

      assert {:ok, %Pair{amount: 5, currency: "USD"}} =
               Pair.decode(%{amount: 5, currency: "USD"})
    end

    test "field-targeted error lands under that field" do
      assert {:error, [%Error{path: [:code], constraint: :validate}]} =
               Region.decode(%{zone: "north", code: "123"})
    end

    test "validate/1 may transform the struct" do
      assert {:ok, %Region{code: "ABCDE"}} = Region.decode(%{zone: "north", code: "abcde"})
    end

    test "runs on nested structs at their own path" do
      assert {:error, [%Error{path: [:dest, :code], constraint: :validate}]} =
               Shipment.decode(%{label: "x", dest: %{zone: "north", code: "12"}})
    end

    test "aggregation: a sibling failure does not hide a nested cross-field error" do
      # label has a type error AND dest's validate/1 fails — both must surface
      assert {:error, errors} =
               Shipment.decode(%{label: 1, dest: %{zone: "north", code: "12"}}, mode: :all_errors)

      assert Enum.map(errors, & &1.path) |> Enum.sort() == [[:dest, :code], [:label]]
    end

    test "skipped in partial mode" do
      schema = Region.__schema__()
      assert {:ok, _} = Schema.validate(schema, %{zone: "north"}, partial: true)
    end
  end
end
