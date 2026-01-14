defmodule Raggio.Tabular.ColumnDef do
  @moduledoc """
  Column definition mapping a tabular column to a typed field.

  Columns can be resolved by header name, fixed position, or both.
  At least one of `header` or `at` must be specified.
  """

  @type t :: %__MODULE__{
          field_name: atom(),
          header: String.t() | nil,
          at: non_neg_integer() | nil,
          required: boolean(),
          type_schema: any()
        }

  @enforce_keys [:field_name, :type_schema]
  defstruct [:field_name, :header, :at, :type_schema, required: true]

  @spec new(atom(), any(), keyword()) :: t()
  def new(field_name, type_schema, opts \\ []) do
    header = Keyword.get(opts, :header) || default_header(field_name)
    at = Keyword.get(opts, :at)
    required = Keyword.get(opts, :required, true)

    %__MODULE__{
      field_name: field_name,
      header: header,
      at: at,
      required: required,
      type_schema: type_schema
    }
  end

  defp default_header(field_name) do
    field_name
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
