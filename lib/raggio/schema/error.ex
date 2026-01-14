defmodule Raggio.Schema.Error do
  @moduledoc """
  Validation error returned when data fails schema validation.
  """

  @type t :: %__MODULE__{
          path: [atom() | integer()],
          message: String.t(),
          value: any(),
          constraint: atom() | nil
        }

  defstruct path: [],
            message: "",
            value: nil,
            constraint: nil
end
