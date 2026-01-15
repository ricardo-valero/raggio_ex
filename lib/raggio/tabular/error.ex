defmodule Raggio.Tabular.Error do
  @moduledoc """
  Row-specific parsing error with location context.

  Errors include the original row number from the source file,
  enabling users to locate and fix issues in their input data.
  """

  @type t :: %__MODULE__{
          row: pos_integer(),
          path: String.t() | atom(),
          message: String.t(),
          value: any(),
          constraint: atom() | nil
        }

  @enforce_keys [:row, :path, :message]
  defstruct [:row, :path, :message, :value, :constraint]

  @spec new(pos_integer(), String.t() | atom(), String.t(), keyword()) :: t()
  def new(row, path, message, opts \\ []) do
    %__MODULE__{
      row: row,
      path: path,
      message: message,
      value: Keyword.get(opts, :value),
      constraint: Keyword.get(opts, :constraint)
    }
  end
end
