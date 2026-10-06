defmodule Manuable.DataSchema.Types.String do
  @moduledoc """
  String type parser with constraints.

  ## Constraints

  - `min` - Minimum string length
  - `max` - Maximum string length
  - `format` - Regex pattern the string must match
  - `trim` - Whether to trim whitespace (default: true)
  - `allow_blank` - Whether to allow empty strings (default: false)

  ## Decoding

  Converts any value to string via `to_string/1`.
  Note: String type still supports coercion from numbers/atoms for convenience.
  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(value, opts) when is_binary(value) do
    trimmed =
      if Keyword.get(opts, :trim, true) do
        String.trim(value)
      else
        value
      end

    {:ok, trimmed}
  end

  def decode(value, opts) when is_number(value) do
    decode(to_string(value), opts)
  end

  def decode(value, opts) when is_atom(value) and not is_nil(value) do
    decode(Atom.to_string(value), opts)
  end

  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be a string"}

  @impl true
  def check_constraints(value, opts) when is_binary(value) do
    with :ok <- check_allow_blank(value, opts),
         :ok <- check_min_length(value, opts),
         :ok <- check_max_length(value, opts) do
      check_format(value, opts)
    end
  end

  @impl true
  def encode(value, _opts) when is_binary(value), do: {:ok, value}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:ok, to_string(value)}

  # Private helpers

  defp check_allow_blank("", opts) do
    if Keyword.get(opts, :allow_blank, false) do
      :ok
    else
      {:error, "must not be blank"}
    end
  end

  defp check_allow_blank(_value, _opts), do: :ok

  defp check_min_length(value, opts) do
    case Keyword.get(opts, :min) do
      nil ->
        :ok

      min when is_integer(min) ->
        if String.length(value) >= min do
          :ok
        else
          {:error, "is too short (minimum is #{min} characters)"}
        end
    end
  end

  defp check_max_length(value, opts) do
    case Keyword.get(opts, :max) do
      nil ->
        :ok

      max when is_integer(max) ->
        if String.length(value) <= max do
          :ok
        else
          {:error, "is too long (maximum is #{max} characters)"}
        end
    end
  end

  defp check_format(value, opts) do
    case Keyword.get(opts, :format) do
      nil ->
        :ok

      %Regex{} = regex ->
        if Regex.match?(regex, value) do
          :ok
        else
          {:error, "is invalid"}
        end
    end
  end
end
