defmodule Raggio.Schema.AppConfigTest do
  # NOT async: the fixture modules below are compiled while the :raggio env
  # is set; the env is deleted again right after. Keeping the test module
  # sync avoids interleaving with anything else that might read the env.
  use ExUnit.Case, async: false

  # `config :raggio, decode: [...]` is read at COMPILE time of each schema
  # module (Application.compile_env). The fixtures are defined while the env
  # is set, then the env is removed before any test runs — proving the
  # modules carry the config baked in rather than reading it per call.
  Application.put_env(:raggio, :decode, mode: :all_errors)

  defmodule FromConfig do
    use Raggio.Schema

    schema do
      struct(
        name: string(min: 1),
        age: integer(min: 0)
      )
    end
  end

  defmodule LocalOverride do
    use Raggio.Schema, decode: [mode: :fail_fast]

    schema do
      struct(
        name: string(min: 1),
        age: integer(min: 0)
      )
    end
  end

  defmodule DirectImport do
    import Raggio.Schema.Definition, only: [schema: 1]

    schema do
      struct(
        name: string(min: 1),
        age: integer(min: 0)
      )
    end
  end

  Application.delete_env(:raggio, :decode)

  describe "config :raggio, decode: [...] as the app-wide default" do
    test "a bare `use Raggio.Schema` module inherits the config" do
      assert {:error, errors} = FromConfig.decode(%{name: "", age: -1})
      assert length(errors) == 2
    end

    test "the config was baked at compile time — deleting the env changes nothing" do
      assert Application.get_env(:raggio, :decode) == nil
      assert {:error, errors} = FromConfig.decode(%{name: "", age: -1})
      assert length(errors) == 2
    end

    test "`use` options win over the config (local opt-out)" do
      assert {:error, [_single]} = LocalOverride.decode(%{name: "", age: -1})
    end

    test "call-site options win over both" do
      assert {:error, [_single]} = FromConfig.decode(%{name: "", age: -1}, mode: :fail_fast)
      assert {:error, errors} = LocalOverride.decode(%{name: "", age: -1}, mode: :all_errors)
      assert length(errors) == 2
    end

    test "modules importing schema/1 directly (no `use`) inherit the config too" do
      assert {:error, errors} = DirectImport.decode(%{name: "", age: -1})
      assert length(errors) == 2
    end
  end

  describe "decode!/2 call-site options" do
    test "accepts the same options as decode/2, merged over the defaults" do
      error =
        assert_raise Raggio.Schema.ValidationError, fn ->
          LocalOverride.decode!(%{name: "", age: -1}, mode: :all_errors)
        end

      assert length(error.errors) == 2
    end

    test "without options, the module defaults still apply" do
      error =
        assert_raise Raggio.Schema.ValidationError, fn ->
          FromConfig.decode!(%{name: "", age: -1})
        end

      assert length(error.errors) == 2
    end
  end
end
