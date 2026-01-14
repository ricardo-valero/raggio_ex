defmodule Raggio.Tabular.SheetInfo do
  @moduledoc """
  Worksheet metadata for multi-sheet workbooks.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          index: non_neg_integer()
        }

  @enforce_keys [:name, :index]
  defstruct [:name, :index]

  @spec new(String.t(), non_neg_integer()) :: t()
  def new(name, index) when is_binary(name) and is_integer(index) and index >= 0 do
    %__MODULE__{name: name, index: index}
  end
end
