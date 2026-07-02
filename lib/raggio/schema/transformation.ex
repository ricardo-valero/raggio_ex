defmodule Raggio.Schema.Transformation do
  @moduledoc """
  A pure bidirectional transform between an encoded value and a decoded (typed) value
  — one link in a schema's `encoding` chain (mirrors effect-smol's `Transformation`).

    * `decode` — `(encoded -> {:ok, typed} | {:error, message})` (may fail)
    * `encode` — `(typed -> encoded)` (total)

  No effect runtime: getters are plain functions.
  """

  defstruct [:decode, :encode]

  @type t :: %__MODULE__{
          decode: (any() -> {:ok, any()} | {:error, String.t()}),
          encode: (any() -> any())
        }
end
