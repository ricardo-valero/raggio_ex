defmodule Raggio.Schema.DecodeToTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema
  alias Raggio.Schema.Error

  defmodule Level do
    use Raggio.Schema

    schema do
      literal([:low, :high])
    end
  end

  defmodule Toggle do
    use Raggio.Schema

    schema do
      struct(state: string() |> decode_to(literal(["on", "off"]), &{:ok, String.downcase(&1)}))
    end
  end

  test "pipes a decode step between two schemas; target validates the result" do
    schema =
      Schema.string()
      |> Schema.decode_to(
        Schema.literal(["on", "off"]),
        &{:ok, &1 |> String.trim() |> String.downcase()}
      )

    assert {:ok, "on"} = Schema.validate(schema, "  ON  ")
    assert {:error, [%Error{constraint: :literal}]} = Schema.validate(schema, "maybe")
    assert {:error, [%Error{constraint: :type}]} = Schema.validate(schema, 5)
  end

  test "target may be a module schema" do
    schema = Schema.string() |> Schema.decode_to(Level, &{:ok, String.downcase(&1)})
    assert {:ok, :high} = Schema.validate(schema, "HIGH")
  end

  test "encode reverses through the chain" do
    schema =
      Schema.string()
      |> Schema.decode_to(
        Schema.literal(["on", "off"]),
        &{:ok, String.downcase(&1)},
        &String.upcase/1
      )

    assert {:ok, "on"} = Schema.validate(schema, "On")
    assert {:ok, "ON"} = Schema.encode(schema, "on")
  end

  test "works unqualified inside schema blocks" do
    assert {:ok, %Toggle{state: "off"}} = Toggle.decode(%{state: "OFF"})
  end
end
