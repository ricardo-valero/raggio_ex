defmodule Manuable.DataSchema.Types do
  @moduledoc """
  Registry and utilities for type modules.

  Maps type specifications to their implementation modules.
  """

  alias Manuable.DataSchema.Types.{
    Boolean,
    Decimal,
    Float,
    Integer,
    String
  }

  @doc """
  Returns the type module for a given type specification.

  ## Examples

      iex> Types.get_type_module(:string)
      Manuable.DataSchema.Types.String

      iex> Types.get_type_module(:integer)
      Manuable.DataSchema.Types.Integer

      iex> Types.get_type_module({:array, :string})
      Manuable.DataSchema.Types.Array
  """
  @spec get_type_module(atom() | tuple()) :: module()
  def get_type_module(:string), do: String
  def get_type_module(:integer), do: Integer
  def get_type_module(:float), do: Float
  def get_type_module(:boolean), do: Boolean

  def get_type_module(:decimal), do: Decimal
  def get_type_module(:datetime), do: Manuable.DataSchema.Types.DateTime
  def get_type_module(:date), do: Manuable.DataSchema.Types.Date
  def get_type_module(:atom), do: Manuable.DataSchema.Types.Atom
  def get_type_module({:array, _inner}), do: Manuable.DataSchema.Types.Array
  def get_type_module({:struct, _schema}), do: Manuable.DataSchema.Types.Struct
  def get_type_module(:struct), do: Manuable.DataSchema.Types.Struct
  def get_type_module({:enum, _values}), do: Manuable.DataSchema.Types.Enum
  def get_type_module(:enum), do: Manuable.DataSchema.Types.Enum

  # Custom type modules passed directly
  def get_type_module(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :decode, 2) do
      module
    else
      raise ArgumentError, "Unknown type: #{inspect(module)}"
    end
  end

  def get_type_module(type) do
    raise ArgumentError, "Unknown type specification: #{inspect(type)}"
  end
end
