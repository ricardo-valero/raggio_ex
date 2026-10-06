defmodule Manuable.DataSchema.Types.DateTime do
  @moduledoc """
  DateTime type parser.

  ## Accepted Values

  - `DateTime.t()` struct
  - ISO8601 datetime string (e.g., "2024-01-15T10:30:00Z")

  ## Encoding

  Encodes to ISO8601 datetime string.

  ## BigQuery Mapping

  Maps to BigQuery `TIMESTAMP` type.
  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(%DateTime{} = datetime, _opts), do: {:ok, datetime}

  def decode(value, _opts) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _} -> {:error, "must be a valid ISO8601 datetime"}
    end
  end

  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be a DateTime or ISO8601 string"}

  @impl true
  def check_constraints(_value, _opts), do: :ok

  @impl true
  def encode(%DateTime{} = datetime, _opts), do: {:ok, DateTime.to_iso8601(datetime)}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:error, "cannot encode #{inspect(value)} as datetime"}
end
