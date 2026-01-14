defmodule Raggio.Tabular.WorksheetSelector do
  @moduledoc """
  Worksheet selection by name or index for multi-sheet workbooks.
  """

  @type t :: {:name, String.t()} | {:index, non_neg_integer()}

  @spec by_name(String.t()) :: t()
  def by_name(name) when is_binary(name), do: {:name, name}

  @spec by_index(non_neg_integer()) :: t()
  def by_index(index) when is_integer(index) and index >= 0, do: {:index, index}

  @spec first() :: t()
  def first, do: {:index, 0}

  @spec match?(t(), String.t(), non_neg_integer()) :: boolean()
  def match?({:name, target_name}, sheet_name, _index) do
    String.downcase(target_name) == String.downcase(sheet_name)
  end

  def match?({:index, target_index}, _sheet_name, index) do
    target_index == index
  end
end
