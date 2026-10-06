defmodule Manuable.DataSchema.Types.Date do
  @moduledoc """
  Date type parser (without time component).

  ## Accepted Values

  - `Date.t()` struct
  - ISO8601 date string (e.g., "2024-01-15")

  ## Encoding

  Encodes to ISO8601 date string.

  ## BigQuery Mapping

  Maps to BigQuery `DATE` type.
  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(%Date{} = date, _opts), do: {:ok, date}

  def decode(value, _opts) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "must be a valid ISO8601 date (YYYY-MM-DD)"}
    end
  end

  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be a Date or ISO8601 date string"}

  @impl true
  def check_constraints(_value, _opts), do: :ok

  @impl true
  def encode(%Date{} = date, _opts), do: {:ok, Date.to_iso8601(date)}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:error, "cannot encode #{inspect(value)} as date"}
end
