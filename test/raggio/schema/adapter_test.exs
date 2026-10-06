defmodule Raggio.Schema.AdapterTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema.Adapter

  describe "Adapter behaviour" do
    test "defines to_schema/1 callback" do
      callbacks = Adapter.behaviour_info(:callbacks)
      assert {:to_schema, 1} in callbacks
    end

    test "defines from_schema/1 callback" do
      callbacks = Adapter.behaviour_info(:callbacks)
      assert {:from_schema, 1} in callbacks
    end

    test "defines adapter_namespace/0 callback" do
      callbacks = Adapter.behaviour_info(:callbacks)
      assert {:adapter_namespace, 0} in callbacks
    end

    test "from_schema/2 is an optional callback" do
      optional = Adapter.behaviour_info(:optional_callbacks)
      assert {:from_schema, 2} in optional
    end
  end
end
