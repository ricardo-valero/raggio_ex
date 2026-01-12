defmodule Raggio.Schema.ValidationError do
  @moduledoc """
  Error raised when validation fails.
  """

  defexception [:errors]

  @type t :: %__MODULE__{
          errors: list()
        }

  @type error_detail :: %{
          path: list(atom() | integer()),
          message: String.t(),
          value: any(),
          constraint: atom()
        }

  def message(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(fn error ->
      path = Enum.join(error.path, ".")
      "#{path}: #{error.message}"
    end)
    |> Enum.join("\n")
  end

  def message(_), do: "Validation failed"
end

defmodule Raggio.Schema.CompositionError do
  @moduledoc """
  Error raised when composing incompatible schemas.
  """

  defexception [:message, :left_type, :right_type]

  @type t :: %__MODULE__{
          message: String.t(),
          left_type: atom(),
          right_type: atom() | nil
        }

  def message(%{message: msg, left_type: left, right_type: right}) when not is_nil(right) do
    "#{msg}: cannot compose #{inspect(left)} with #{inspect(right)}"
  end

  def message(%{message: msg, left_type: left}) do
    "#{msg} (type: #{inspect(left)})"
  end
end
