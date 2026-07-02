defmodule Raggio.Schema.Declaration do
  @moduledoc """
  Opaque custom value-types — the escape hatch for anything with bespoke
  decode/encode/validation (effect's `declare`, Domain.Schema's `Declaration`).

  A declaration is a module implementing this behaviour; `Schema.declare(Mod)` (or the
  module itself, via the `__schema__/0` convention) references it from any schema
  position. Cross-cutting, context-free custom types live here — a declaration only
  sees its own value.

      defmodule MyApp.Type.Uri do
        use Raggio.Schema.Declaration

        @impl true
        def decode(value) when is_binary(value) do
          case URI.new(value) do
            {:ok, uri} -> {:ok, uri}
            {:error, _} -> {:error, "is not a valid URI"}
          end
        end

        def decode(%URI{} = uri), do: {:ok, uri}
        def decode(_), do: {:error, "is not a valid URI"}

        @impl true
        def encode(%URI{} = uri), do: URI.to_string(uri)

        @impl true
        def json_schema, do: %{"type" => "string", "format" => "uri"}
      end

      # anywhere a schema is expected:
      schema do
        struct(homepage: MyApp.Type.Uri)
      end

  `use Raggio.Schema.Declaration` sets `@behaviour`, provides `__schema__/0`
  (so the module composes via the module-as-schema convention) and `decode!/1`,
  plus a default `json_schema/0` (empty — accepts anything) that you can override.
  """

  @doc "Decode a wire value into the opaque type (may fail)."
  @callback decode(term()) :: {:ok, term()} | {:error, String.t()}

  @doc "Encode the opaque type back to its wire representation (total)."
  @callback encode(term()) :: term()

  @doc "The JSON Schema representation of the wire side."
  @callback json_schema() :: map()

  defmacro __using__(_opts) do
    quote do
      @behaviour Raggio.Schema.Declaration

      @doc "The runtime `Raggio.Schema` value for this declaration."
      def __schema__, do: Raggio.Schema.declare(__MODULE__)

      @impl Raggio.Schema.Declaration
      def json_schema, do: %{}

      @doc "Like `decode/1` but raises `Raggio.Schema.ValidationError` on failure."
      def decode!(data), do: Raggio.Schema.validate!(__schema__(), data)

      defoverridable json_schema: 0
    end
  end
end
