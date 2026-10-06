defmodule Manuable.DataSchema.Types.Float do
  @moduledoc """
  Float type parser - strict mode, no automatic coercion.

  ## Constraints

  - `min` - Minimum value
  - `max` - Maximum value

  ## Accepted Values

  Only accepts actual float values. No automatic coercion from:
  - Integers (use explicit `transform()`)
  - Strings (use explicit `transform()`)

  ## Explicit Coercion

  For string/integer coercion, use explicit `transform()` pipes in your schema:

      field(:price, :float)
      |> transform(&MyTransforms.string_to_float/1)

  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(value, _opts) when is_float(value), do: {:ok, value}
  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be a float"}

  @impl true
  def check_constraints(value, opts) when is_float(value) do
    with :ok <- check_min(value, opts) do
      check_max(value, opts)
    end
  end

  @impl true
  def encode(value, _opts) when is_float(value), do: {:ok, value}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:error, "cannot encode #{inspect(value)} as float"}

  # Private helpers

  defp check_min(value, opts) do
    case Keyword.get(opts, :min) do
      nil -> :ok
      min when value >= min -> :ok
      min -> {:error, "must be greater than or equal to #{min}"}
    end
  end

  defp check_max(value, opts) do
    case Keyword.get(opts, :max) do
      nil -> :ok
      max when value <= max -> :ok
      max -> {:error, "must be less than or equal to #{max}"}
    end
  end
end
