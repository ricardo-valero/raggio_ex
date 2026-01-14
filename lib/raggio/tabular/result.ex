defmodule Raggio.Tabular.Result do
  @moduledoc """
  Parse operation result containing valid rows, invalid rows, and metadata.

  Valid rows are typed maps matching the SheetSchema definition.
  Invalid rows are Raggio.Tabular.Error structs with row numbers.
  """

  alias Raggio.Tabular.Error

  @type t :: %__MODULE__{
          valid_rows: [map()],
          invalid_rows: [Error.t()],
          total_rows: non_neg_integer(),
          matched_schema: atom() | nil,
          metadata: map()
        }

  defstruct valid_rows: [],
            invalid_rows: [],
            total_rows: 0,
            matched_schema: nil,
            metadata: %{}

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      valid_rows: Keyword.get(opts, :valid_rows, []),
      invalid_rows: Keyword.get(opts, :invalid_rows, []),
      total_rows: Keyword.get(opts, :total_rows, 0),
      matched_schema: Keyword.get(opts, :matched_schema),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @spec add_valid_row(t(), map()) :: t()
  def add_valid_row(%__MODULE__{} = result, row) do
    %{result | valid_rows: [row | result.valid_rows], total_rows: result.total_rows + 1}
  end

  @spec add_invalid_row(t(), Error.t()) :: t()
  def add_invalid_row(%__MODULE__{} = result, error) do
    %{result | invalid_rows: [error | result.invalid_rows], total_rows: result.total_rows + 1}
  end

  @spec finalize(t()) :: t()
  def finalize(%__MODULE__{} = result) do
    %{
      result
      | valid_rows: Enum.reverse(result.valid_rows),
        invalid_rows: Enum.reverse(result.invalid_rows)
    }
  end
end
