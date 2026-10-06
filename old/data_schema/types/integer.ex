defmodule Manuable.DataSchema.Types.Integer do
  @moduledoc """
  Integer type parser - strict mode, no automatic coercion.

  ## Constraints

  - `min` - Minimum value (inclusive)
  - `max` - Maximum value (inclusive)
  - `greater_than` - Must be greater than this value
  - `less_than` - Must be less than this value

  ## Accepted Values

  Only accepts actual integer values. No automatic coercion from:
  - Floats (use explicit `transform()`)
  - Strings (use explicit `transform()`)

  ## Explicit Coercion

  For string/float coercion, use explicit `transform()` pipes in your schema:

      field(:quantity, :integer)
      |> transform(&MyTransforms.string_to_integer/1)

  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(value, _opts) when is_integer(value), do: {:ok, value}
  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be an integer"}

  @impl true
  def check_constraints(value, opts) when is_integer(value) do
    with :ok <- check_min(value, opts),
         :ok <- check_max(value, opts),
         :ok <- check_greater_than(value, opts) do
      check_less_than(value, opts)
    end
  end

  @impl true
  def encode(value, _opts) when is_integer(value), do: {:ok, value}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:error, "cannot encode #{inspect(value)} as integer"}

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

  defp check_greater_than(value, opts) do
    case Keyword.get(opts, :greater_than) do
      nil -> :ok
      limit when value > limit -> :ok
      limit -> {:error, "must be greater than #{limit}"}
    end
  end

  defp check_less_than(value, opts) do
    case Keyword.get(opts, :less_than) do
      nil -> :ok
      limit when value < limit -> :ok
      limit -> {:error, "must be less than #{limit}"}
    end
  end
end
