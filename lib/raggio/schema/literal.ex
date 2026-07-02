defmodule Raggio.Schema.Literal do
  @moduledoc """
  Opt-in macro for a **named literal set** — a reusable enum module without a struct
  (effect's `Literals`, Domain.Schema's `literal` construct).

      defmodule Status do
        use Raggio.Schema.Literal, values: ["on", "off"]
      end

      Status.decode("on")    #=> {:ok, "on"}
      Status.values()        #=> ["on", "off"]

  Pass `decode: :downcase | :upcase` for string value sets to case-fold the incoming
  string before matching — the wire is lenient, the decoded value canonical:

      defmodule Level do
        use Raggio.Schema.Literal, values: ["low", "high"], decode: :downcase
      end

      Level.decode("HIGH")   #=> {:ok, "high"}

  Generated: `@type t` (atoms/integers become a value union, strings widen to
  `String.t()`), `__schema__/0`, `values/0`, `decode/1`, `decode!/1`, `encode/1`.
  Because the module exports `__schema__/0`, it is usable anywhere a schema is
  expected — e.g. `defschema status: Status`.
  """

  defmacro __using__(opts) do
    values = Keyword.fetch!(opts, :values)
    fold = Keyword.get(opts, :decode)

    if not is_list(values) or values == [] do
      raise ArgumentError,
            "use Raggio.Schema.Literal expects values: a non-empty list, got: #{inspect(values)}"
    end

    if fold not in [nil, :downcase, :upcase] do
      raise ArgumentError, "decode: must be :downcase or :upcase, got: #{inspect(fold)}"
    end

    schema_opts = if fold, do: [decode: fold], else: []
    type = Raggio.Schema.Struct.__type_for__({:literals, [], [values]})

    quote do
      @type t :: unquote(type)

      @doc "The allowed values of this literal set."
      def values, do: unquote(values)

      @doc "The runtime `Raggio.Schema` value for this literal set."
      def __schema__, do: Raggio.Schema.literals(unquote(values), unquote(schema_opts))

      @doc "Decode a wire value into a member of this set."
      def decode(data), do: Raggio.Schema.decode(__schema__(), data)

      @doc "Like `decode/1` but raises `Raggio.Schema.ValidationError` on failure."
      def decode!(data), do: Raggio.Schema.validate!(__schema__(), data)

      @doc "Encode a member back to its wire representation."
      def encode(value), do: Raggio.Schema.encode(__schema__(), value)
    end
  end
end
