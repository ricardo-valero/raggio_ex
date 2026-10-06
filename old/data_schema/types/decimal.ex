defmodule Manuable.DataSchema.Types.Decimal do
  @moduledoc """
  Decimal type parser - strict mode, no automatic coercion.

  ## Constraints

  - `min` - Minimum value (as Decimal)
  - `max` - Maximum value (as Decimal)
  - `precision` - Maximum total digits (optional)
  - `scale` - Maximum decimal places (optional)

  ## Accepted Values

  Only accepts `Decimal` struct values. No automatic coercion from:
  - Integers (use explicit `transform()`)
  - Floats (use explicit `transform()`)
  - Strings (use explicit `transform()`)

  ## Explicit Coercion

  For string/number coercion, use explicit `transform()` pipes in your schema:

      field(:amount, :decimal)
      |> transform(&MyTransforms.string_to_decimal/1)

  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(%Decimal{} = value, _opts), do: {:ok, value}
  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be a Decimal"}

  @impl true
  def check_constraints(%Decimal{} = value, opts) do
    with :ok <- check_min(value, opts),
         :ok <- check_max(value, opts),
         :ok <- check_greater_than(value, opts),
         :ok <- check_less_than(value, opts),
         :ok <- check_precision(value, opts) do
      check_scale(value, opts)
    end
  end

  @impl true
  def encode(%Decimal{} = value, _opts), do: {:ok, value}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:error, "cannot encode #{inspect(value)} as Decimal"}

  # Private helpers

  defp check_min(value, opts) do
    case Keyword.get(opts, :min) do
      nil ->
        :ok

      min ->
        min_decimal = ensure_decimal(min)

        if Decimal.compare(value, min_decimal) in [:gt, :eq] do
          :ok
        else
          {:error, "must be greater than or equal to #{min}"}
        end
    end
  end

  defp check_max(value, opts) do
    case Keyword.get(opts, :max) do
      nil ->
        :ok

      max ->
        max_decimal = ensure_decimal(max)

        if Decimal.compare(value, max_decimal) in [:lt, :eq] do
          :ok
        else
          {:error, "must be less than or equal to #{max}"}
        end
    end
  end

  defp check_precision(value, opts) do
    case Keyword.get(opts, :precision) do
      nil ->
        :ok

      precision ->
        # Get the absolute value and count total digits
        abs_value = Decimal.abs(value)
        # Convert to string and count non-decimal-point characters
        str = Decimal.to_string(abs_value, :normal)
        digit_count = str |> String.replace(~r/[^0-9]/, "") |> String.length()

        if digit_count <= precision do
          :ok
        else
          {:error, "exceeds maximum precision of #{precision} digits"}
        end
    end
  end

  defp check_scale(value, opts) do
    case Keyword.get(opts, :scale) do
      nil ->
        :ok

      max_scale ->
        # Decimal.scale/1 returns the scale (number of decimal places)
        actual_scale = get_scale(value)

        if actual_scale <= max_scale do
          :ok
        else
          {:error, "exceeds maximum scale of #{max_scale} decimal places"}
        end
    end
  end

  defp get_scale(%Decimal{exp: exp}) when exp < 0, do: -exp
  defp get_scale(%Decimal{}), do: 0

  defp check_greater_than(value, opts) do
    case Keyword.get(opts, :greater_than) do
      nil ->
        :ok

      limit ->
        limit_decimal = ensure_decimal(limit)

        if Decimal.compare(value, limit_decimal) == :gt do
          :ok
        else
          {:error, "must be greater than #{limit}"}
        end
    end
  end

  defp check_less_than(value, opts) do
    case Keyword.get(opts, :less_than) do
      nil ->
        :ok

      limit ->
        limit_decimal = ensure_decimal(limit)

        if Decimal.compare(value, limit_decimal) == :lt do
          :ok
        else
          {:error, "must be less than #{limit}"}
        end
    end
  end

  defp ensure_decimal(%Decimal{} = d), do: d
  defp ensure_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp ensure_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp ensure_decimal(n) when is_binary(n), do: Decimal.new(n)
end
