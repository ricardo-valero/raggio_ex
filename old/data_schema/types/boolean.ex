defmodule Manuable.DataSchema.Types.Boolean do
  @moduledoc """
  Boolean type parser - strict mode, no automatic coercion.

  ## Accepted Values

  Only accepts actual boolean values:
  - `true`
  - `false`

  ## Explicit Coercion

  For string/integer coercion, use explicit `transform()` pipes in your schema:

      field(:active, :boolean)
      |> transform(&MyTransforms.string_to_boolean/1)
  """

  @behaviour Manuable.DataSchema.Type

  @impl true
  def decode(true, _opts), do: {:ok, true}
  def decode(false, _opts), do: {:ok, false}
  def decode(nil, _opts), do: {:error, "must be present"}
  def decode(_value, _opts), do: {:error, "must be a boolean"}

  @impl true
  def check_constraints(_value, _opts), do: :ok

  @impl true
  def encode(true, _opts), do: {:ok, true}
  def encode(false, _opts), do: {:ok, false}
  def encode(nil, _opts), do: {:ok, nil}
  def encode(value, _opts), do: {:error, "cannot encode #{inspect(value)} as boolean"}
end
