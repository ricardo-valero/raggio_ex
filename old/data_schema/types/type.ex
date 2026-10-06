defmodule Manuable.DataSchema.Type do
  @moduledoc """
  Behaviour that all type parsers must implement.

  Types are responsible for:
  1. Decoding/Parsing (validating input matches expected type)
  2. Checking constraints
  3. Encoding (converting internal format to output)

  Note: Types operate in strict mode - no automatic coercion.
  Use explicit `transform()` pipes in schemas for type conversions.

  ## Implementing a Custom Type

      defmodule MyApp.Types.PhoneNumber do
         Manuable.DataSchema.Type

        @impl true
        def decode(value, _opts) when is_binary(value) do
          cleaned = String.replace(value, ~r/[^\\d]/, "")
          if String.length(cleaned) == 10 do
            {:ok, cleaned}
          else
            {:error, "must be a 10-digit phone number"}
          end
        end

        def decode(_, _opts), do: {:error, "must be a string"}

        @impl true
        def check_constraints(_value, _opts), do: :ok

        @impl true
        def encode(value, _opts), do: {:ok, value}
      end
  """

  @doc """
  Decodes an input value to the internal representation.
  Called during parsing to coerce input data.
  """
  @callback decode(value :: any(), opts :: keyword()) ::
              {:ok, decoded_value :: any()} | {:error, String.t()}

  @doc """
  Checks constraints on a decoded value.
  Called after decode to verify type-specific constraints.
  """
  @callback check_constraints(value :: any(), opts :: keyword()) ::
              :ok | {:error, String.t()}

  @doc """
  Encodes an internal value to external representation.
  Called when serializing data for output (e.g., JSON, BigQuery).
  """
  @callback encode(value :: any(), opts :: keyword()) ::
              {:ok, encoded_value :: any()} | {:error, String.t()}
end
