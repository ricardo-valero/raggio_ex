defmodule Raggio.Schema.EncodePresenceTest do
  @moduledoc """
  D18 — encode presence semantics (tasks 5.8/5.9), aligned with effect-smol:

    * `optional?`/defaulted field, nil or absent → key omitted (nil ≡ absent on the
      typed side; Elixir structs cannot drop keys)
    * `nullable?` field, nil → `key => nil` emitted (effect's `NullOr` emits null);
      nullable wins over optional
    * plain required field, nil → issue (defensive encode, D14); absent key on
      plain-map input → `MissingKey` issue
    * the encoder agrees with the JSON Schema adapter: every key the adapter marks
      `required` is present in encoded output
  """
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error
  alias Raggio.Schema.Adapters.JsonSchema

  defmodule Shipment do
    use Raggio.Schema

    schema do
      struct(
        label: string(),
        tracking: string() |> nullable(),
        note: string() |> optional(),
        carrier: string() |> default("upsx"),
        meta: any()
      )
    end
  end

  defmodule Flexible do
    use Raggio.Schema

    schema do
      struct(both: string() |> optional() |> nullable())
    end
  end

  defp shipment(overrides) do
    struct(Shipment, Map.merge(%{label: "box", tracking: "T1", meta: %{}}, overrides))
  end

  describe "nullable emits" do
    test "nil encodes as `key => nil`, not omission" do
      assert {:ok, encoded} = Schema.encode(Shipment.__schema__(), shipment(%{tracking: nil}))
      assert %{tracking: nil} = encoded
      assert Map.has_key?(encoded, :tracking)
    end

    test "round-trips: decode(encode(x)) == x and the wire carries the key" do
      s = Shipment.__schema__()
      x = shipment(%{tracking: nil, note: nil, carrier: "dhl"})
      {:ok, wire} = Schema.encode(s, x)
      assert Map.has_key?(wire, :tracking)
      assert {:ok, ^x} = Schema.validate(s, wire)
    end

    test "nullable wins over optional: nil emits" do
      assert {:ok, %{both: nil}} =
               Schema.encode(Flexible.__schema__(), struct(Flexible, %{both: nil}))
    end
  end

  describe "optional/defaulted omits" do
    test "optional nil is omitted" do
      {:ok, encoded} = Schema.encode(Shipment.__schema__(), shipment(%{note: nil}))
      refute Map.has_key?(encoded, :note)
    end

    test "optional absent key (plain-map input) is omitted" do
      {:ok, encoded} =
        Schema.encode(Shipment.__schema__(), %{label: "box", tracking: "T1", meta: %{}})

      refute Map.has_key?(encoded, :note)
    end

    test "defaulted nil is omitted (defaults are decode-side only)" do
      {:ok, encoded} = Schema.encode(Shipment.__schema__(), shipment(%{carrier: nil}))
      refute Map.has_key?(encoded, :carrier)
    end

    test "optional/defaulted values still encode when present" do
      {:ok, encoded} =
        Schema.encode(Shipment.__schema__(), shipment(%{note: "fragile", carrier: "dhl"}))

      assert %{note: "fragile", carrier: "dhl"} = encoded
    end
  end

  describe "required errors (defensive encode)" do
    test "nil in a required typed field is a pointered issue, not a silent drop" do
      assert {:error, [%Error{path: [:label], constraint: :type}]} =
               Schema.encode(Shipment.__schema__(), shipment(%{label: nil}))
    end

    test "absent required key on plain-map input is MissingKey" do
      assert {:error, [%Error{path: [:label], constraint: :required}]} =
               Schema.encode(Shipment.__schema__(), %{tracking: "T1", meta: %{}})
    end

    test "mode: :all_errors collects every presence failure" do
      assert {:error, errors} =
               Schema.encode(Shipment.__schema__(), %{label: nil, tracking: "T1", meta: %{}},
                 mode: :all_errors
               )

      assert Enum.map(errors, & &1.path) |> Enum.sort() == [[:label]]

      assert {:error, errors} = Schema.encode(Shipment.__schema__(), %{}, mode: :all_errors)
      assert [:label, :meta, :tracking] = errors |> Enum.map(&hd(&1.path)) |> Enum.sort()
    end

    test "any() admits nil (unknown admits null) — required any emits `key => nil`" do
      assert {:ok, %{meta: nil} = encoded} =
               Schema.encode(Shipment.__schema__(), shipment(%{meta: nil}))

      assert Map.has_key?(encoded, :meta)
    end
  end

  describe "encoder/adapter agreement" do
    test "encoded output carries every key the JSON Schema adapter marks required" do
      json = JsonSchema.to_json_schema(Shipment.__schema__(), root: false)

      {:ok, encoded} =
        Schema.encode(Shipment.__schema__(), shipment(%{tracking: nil, note: nil}))

      encoded_keys = encoded |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

      for key <- json["required"] do
        assert key in encoded_keys, "adapter requires #{key} but encode omitted it"
      end
    end
  end
end
