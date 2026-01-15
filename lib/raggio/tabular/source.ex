defmodule Raggio.Tabular.Source do
  @moduledoc """
  Represents a tabular file source with optional parsing hints.

  Sources can be file paths or in-memory content, with hints
  for delimiter, encoding, and worksheet selection.
  """

  @type source_type :: :file | :binary
  @type hints :: %{
          optional(:delimiter) => String.t(),
          optional(:encoding) => atom(),
          optional(:worksheet) => {:name, String.t()} | {:index, non_neg_integer()}
        }

  @type t :: %__MODULE__{
          type: source_type(),
          location: String.t() | binary(),
          hints: hints()
        }

  @enforce_keys [:type, :location]
  defstruct [:type, :location, hints: %{}]

  @spec from_file(String.t(), keyword()) :: t()
  def from_file(path, opts \\ []) do
    %__MODULE__{
      type: :file,
      location: path,
      hints: build_hints(opts)
    }
  end

  @spec from_binary(binary(), keyword()) :: t()
  def from_binary(content, opts \\ []) do
    %__MODULE__{
      type: :binary,
      location: content,
      hints: build_hints(opts)
    }
  end

  defp build_hints(opts) do
    opts
    |> Keyword.take([:delimiter, :encoding, :worksheet])
    |> Map.new()
  end
end
