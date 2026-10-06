defmodule Raggio.BigQuery.Column do
  @moduledoc """
  Represents a column definition in a BigQuery table.

  ## Fields

  - `name` - Column identifier (atom or string)
  - `type` - The column data type as a `Raggio.Schema.Type`
  - `mode` - Column mode: `:nullable` (default), `:required`, or `:repeated`
  - `description` - Optional column description
  - `default_value` - Optional default value expression
  - `metadata` - Custom metadata map

  ## Validation Rules

  - `name` must be a valid identifier (starts with letter/underscore)
  - `type.kind` must be BigQuery-compatible
  - `mode` must be `:nullable`, `:required`, or `:repeated`

  ## Examples

      %Column{
        name: :user_id,
        type: %Raggio.Schema.Type{kind: :string},
        mode: :required,
        description: "Unique user identifier"
      }
  """

  alias Raggio.Schema.Type
  alias Raggio.BigQuery.Error

  @type mode :: :nullable | :required | :repeated

  @type t :: %__MODULE__{
          name: atom() | String.t(),
          type: Type.t(),
          mode: mode(),
          description: String.t() | nil,
          default_value: any(),
          metadata: map()
        }

  defstruct name: nil,
            type: nil,
            mode: :nullable,
            description: nil,
            default_value: nil,
            metadata: %{}

  # Valid column name pattern: starts with letter or underscore
  @name_pattern ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/

  # BigQuery-compatible type kinds
  @supported_types ~w(string integer float boolean decimal datetime date time timestamp binary atom struct list)a

  # Valid modes
  @valid_modes [:nullable, :required, :repeated]

  @doc """
  Creates a new Column struct.

  ## Examples

      iex> Column.new(:id, %Type{kind: :string}, mode: :required)
      %Column{name: :id, type: %Type{kind: :string}, mode: :required}
  """
  @spec new(atom() | String.t(), Type.t(), keyword()) :: t()
  def new(name, type, opts \\ []) do
    %__MODULE__{
      name: name,
      type: type,
      mode: Keyword.get(opts, :mode, :nullable),
      description: Keyword.get(opts, :description),
      default_value: Keyword.get(opts, :default_value),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validates a Column struct and returns errors if any.

  ## Returns

  - `{:ok, column}` if valid
  - `{:error, errors}` if invalid, where errors is a list of `Error` structs

  ## Examples

      iex> Column.validate(%Column{name: :id, type: %Type{kind: :string}})
      {:ok, %Column{name: :id, type: %Type{kind: :string}}}

      iex> Column.validate(%Column{name: "123bad", type: %Type{kind: :string}})
      {:error, [%Error{type: :invalid_column_name, ...}]}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Error.t()]}
  def validate(%__MODULE__{} = column) do
    errors =
      []
      |> validate_name(column)
      |> validate_type(column)
      |> validate_mode(column)

    case errors do
      [] -> {:ok, column}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  # Private validation helpers

  defp validate_name(errors, %{name: nil}) do
    [Error.new(:invalid_column_name, "Column name is required", [:name]) | errors]
  end

  defp validate_name(errors, %{name: name}) do
    name_str = to_string(name)

    if Regex.match?(@name_pattern, name_str) do
      errors
    else
      [
        Error.new(
          :invalid_column_name,
          "Column name must start with letter or underscore: #{name_str}",
          [:name]
        )
        | errors
      ]
    end
  end

  defp validate_type(errors, %{type: nil}) do
    [Error.new(:unsupported_type, "Column type is required", [:type]) | errors]
  end

  defp validate_type(errors, %{type: %Type{kind: kind}}) do
    if kind in @supported_types do
      errors
    else
      [
        Error.new(
          :unsupported_type,
          "Unsupported BigQuery type: #{kind}",
          [:type]
        )
        | errors
      ]
    end
  end

  defp validate_type(errors, _) do
    [Error.new(:unsupported_type, "Column type must be a Raggio.Schema.Type", [:type]) | errors]
  end

  defp validate_mode(errors, %{mode: mode}) when mode in @valid_modes do
    errors
  end

  defp validate_mode(errors, %{mode: mode}) do
    [
      Error.new(
        :invalid_mode,
        "Invalid column mode: #{inspect(mode)}. Must be :nullable, :required, or :repeated",
        [:mode]
      )
      | errors
    ]
  end
end
