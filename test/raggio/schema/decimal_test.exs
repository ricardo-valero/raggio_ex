defmodule Raggio.Schema.DecimalTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error

  describe "decode casts (Ecto-style)" do
    test "a Decimal passes as-is" do
      dec = Decimal.new("1.5")
      assert {:ok, ^dec} = Schema.validate(Schema.decimal(), dec)
    end

    test "a fully-numeric string casts, preserving precision" do
      assert {:ok, %Decimal{} = dec} = Schema.validate(Schema.decimal(), "12.30")
      assert Decimal.equal?(dec, Decimal.new("12.30"))
      # trailing zero is significant — no float round-trip
      assert to_string(dec) == "12.30"
    end

    test "a partially-numeric or empty string is a type error" do
      for bad <- ["12.3x", "abc", ""] do
        assert {:error, [%Error{constraint: :type}]} = Schema.validate(Schema.decimal(), bad)
      end
    end

    test "an integer casts exactly" do
      assert {:ok, %Decimal{} = dec} = Schema.validate(Schema.decimal(), 2)
      assert Decimal.equal?(dec, Decimal.new(2))
    end

    test "a float casts via its shortest representation" do
      assert {:ok, %Decimal{} = dec} = Schema.validate(Schema.decimal(), 1.5)
      assert to_string(dec) == "1.5"
    end

    test "anything else is a type error" do
      for bad <- [nil, :atom, [], %{}] do
        assert {:error, [%Error{constraint: :type}]} = Schema.validate(Schema.decimal(), bad)
      end
    end
  end

  describe "checks (Decimal.compare, not Kernel comparison)" do
    test "min/max are inclusive" do
      schema = Schema.decimal(min: 0, max: "10.5")
      assert {:ok, _} = Schema.validate(schema, "0")
      assert {:ok, _} = Schema.validate(schema, "10.5")
      assert {:error, [%Error{constraint: :min}]} = Schema.validate(schema, "-0.01")
      assert {:error, [%Error{constraint: :max}]} = Schema.validate(schema, "10.51")
    end

    test "numeric semantics, not structural struct comparison" do
      # Kernel `>=` on %Decimal{} would compare fields and let 9 pass min: 10
      assert {:error, [%Error{constraint: :min}]} =
               Schema.validate(Schema.decimal(min: 10), "9")

      assert {:ok, _} = Schema.validate(Schema.decimal(min: 10), "10")
    end

    test "gt/lt are exclusive" do
      assert {:error, [%Error{constraint: :greater_than}]} =
               Schema.validate(Schema.decimal(gt: 0), "0")

      assert {:ok, _} = Schema.validate(Schema.decimal(gt: 0), "0.01")

      assert {:error, [%Error{constraint: :less_than}]} =
               Schema.validate(Schema.decimal(lt: 1), "1")
    end

    test "a bound may be a Decimal" do
      schema = Schema.decimal(min: Decimal.new("0.5"))
      assert {:ok, _} = Schema.validate(schema, "0.5")
      assert {:error, [%Error{constraint: :min}]} = Schema.validate(schema, "0.49")
    end
  end

  describe "encode" do
    test "a Decimal passes through type-checked" do
      dec = Decimal.new("1.5")
      assert {:ok, ^dec} = Schema.encode(Schema.decimal(), dec)
    end

    test "a non-Decimal is an encode type error" do
      assert {:error, [%Error{constraint: :type}]} = Schema.encode(Schema.decimal(), 1.5)
    end
  end

  defmodule Price do
    use Raggio.Schema

    schema do
      struct(
        amount: decimal(min: 0),
        currency: literal("USD", "MXN")
      )
    end
  end

  describe "in a module schema" do
    test "decodes wire strings into Decimal fields" do
      assert {:ok, %Price{amount: %Decimal{} = amount}} =
               Price.decode(%{amount: "12.30", currency: "USD"})

      assert to_string(amount) == "12.30"
    end

    test "check errors carry the field path" do
      assert {:error, [%Error{path: [:amount], constraint: :min}]} =
               Price.decode(%{amount: "-1", currency: "USD"})
    end
  end
end
