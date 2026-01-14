defmodule Raggio.BigQuery.AuthTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{Auth, MockAuth}

  describe "behaviour compliance" do
    test "MockAuth implements Auth behaviour" do
      behaviours = MockAuth.__info__(:attributes)[:behaviour] || []
      assert Auth in behaviours
    end

    test "Auth behaviour has get_token/1 callback" do
      callbacks = Auth.behaviour_info(:callbacks)
      assert {:get_token, 1} in callbacks
    end

    test "Auth behaviour has optional refresh_token/2 callback" do
      optional = Auth.behaviour_info(:optional_callbacks)
      assert {:refresh_token, 2} in optional
    end
  end

  describe "MockAuth.get_token/1" do
    test "returns {:ok, token} tuple" do
      result = MockAuth.get_token(%{})

      assert {:ok, token} = result
      assert is_binary(token)
    end

    test "returns unique tokens on each call" do
      {:ok, token1} = MockAuth.get_token(%{})
      {:ok, token2} = MockAuth.get_token(%{})

      refute token1 == token2
    end

    test "token starts with 'mock-token-'" do
      {:ok, token} = MockAuth.get_token(%{})
      assert String.starts_with?(token, "mock-token-")
    end
  end

  describe "MockAuth.refresh_token/2" do
    test "returns {:ok, token} tuple" do
      result = MockAuth.refresh_token(%{}, "old-token")

      assert {:ok, token} = result
      assert is_binary(token)
    end

    test "returns a new token different from old token" do
      old_token = "old-token-123"
      {:ok, new_token} = MockAuth.refresh_token(%{}, old_token)

      refute new_token == old_token
    end
  end
end
