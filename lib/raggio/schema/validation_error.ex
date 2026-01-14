defmodule Raggio.Schema.ValidationError do
  defexception [:errors]

  @impl true
  def message(%{errors: errors}) do
    count = length(errors)
    "validation failed with #{count} error(s)"
  end
end
