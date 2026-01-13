defmodule RaggioTabular.SheetSchema do
  @moduledoc """
  DSL for defining column schemas for tabular data parsing.
  """

  defstruct [:columns, :header_variants, :row_range, :union_schemas]

  @type column :: {atom(), Raggio.Schema.t()}
  @type header_variant :: %{(column_name :: String.t()) => atom()}

  @type t :: %__MODULE__{
          columns: [column()],
          header_variants: [header_variant()],
          row_range: {non_neg_integer() | nil, non_neg_integer() | nil},
          union_schemas: [t()] | nil
        }

  @doc """
  Define a column schema from a list of field definitions.
  """
  def define(fields) when is_list(fields) do
    %__MODULE__{
      columns: fields,
      header_variants: [],
      row_range: {nil, nil},
      union_schemas: nil
    }
  end

  @doc """
  Add header variant mappings for flexible column detection.
  """
  def with_header_variants(%__MODULE__{} = schema, variants) when is_list(variants) do
    %{schema | header_variants: variants}
  end

  @doc """
  Set row range for parsing (from_row, to_row).
  """
  def with_row_range(%__MODULE__{} = schema, from_row, to_row \\ nil) do
    %{schema | row_range: {from_row, to_row}}
  end

  @doc """
  Skip specific rows during parsing.
  """
  def skip_rows(%__MODULE__{row_range: {from, to}} = schema, count) when is_integer(count) do
    new_from = (from || 1) + count
    %{schema | row_range: {new_from, to}}
  end

  @doc """
  Create a union schema that tries multiple schemas for format variance.
  """
  def union(schemas) when is_list(schemas) do
    %__MODULE__{
      columns: [],
      header_variants: [],
      row_range: {nil, nil},
      union_schemas: schemas
    }
  end

  @doc """
  Get column names from schema.
  """
  def column_names(%__MODULE__{columns: columns}) do
    Enum.map(columns, fn {name, _schema} -> name end)
  end

  @doc """
  Get the Raggio.Schema for a specific column.
  """
  def get_column_schema(%__MODULE__{columns: columns}, column_name) do
    case Enum.find(columns, fn {name, _} -> name == column_name end) do
      {_name, schema} -> {:ok, schema}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Convert header string to column atom using variants.
  """
  def resolve_header(%__MODULE__{columns: columns, header_variants: variants}, header_string) do
    normalized = String.trim(header_string) |> String.downcase()

    Enum.find_value(variants, fn variant_map ->
      Map.get(variant_map, normalized)
    end) ||
      Enum.find_value(columns, fn {name, _} ->
        if Atom.to_string(name) |> String.downcase() == normalized do
          name
        end
      end)
  end
end
