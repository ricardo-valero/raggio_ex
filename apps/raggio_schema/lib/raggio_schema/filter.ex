defmodule Raggio.Schema.Filter do
  @moduledoc """
  Represents a single validation constraint.
  """

  defstruct [:predicate, path: [], message: nil, metadata: %{}]

  @type t :: %__MODULE__{
          predicate: (any() -> boolean() | {:error, String.t()}),
          path: [atom() | integer()],
          message: String.t() | nil,
          metadata: map()
        }

  def new(predicate, opts \\ []) when is_function(predicate, 1) do
    %__MODULE__{
      predicate: predicate,
      path: Keyword.get(opts, :path, []),
      message: Keyword.get(opts, :message),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  def validate(%__MODULE__{predicate: predicate, message: custom_message}, value) do
    case predicate.(value) do
      true -> :ok
      :ok -> :ok
      false -> {:error, custom_message || "validation failed"}
      {:error, msg} -> {:error, custom_message || msg}
    end
  end
end
