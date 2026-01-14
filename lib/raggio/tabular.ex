defmodule Raggio.Tabular do
  @moduledoc """
  Tabular file parsing with declarative schema mapping.

  Parse CSV and XLSX files into typed rows using a SheetSchema,
  returning valid rows and row-numbered errors separately.

  ## Example

      schema = Raggio.Tabular.SheetSchema.define([
        {:name, Raggio.Schema.string()},
        {:age, Raggio.Schema.integer()}
      ])

      {:ok, result} = Raggio.Tabular.parse_file("users.csv", schema)
      # result.valid_rows => [%{name: "Alice", age: 30}, ...]
      # result.invalid_rows => [%Raggio.Tabular.Error{row: 5, ...}, ...]

  """

  alias Raggio.Tabular.{Parser, Registry, Result, SheetSchema, Union}

  @type path :: String.t()
  @type schema_or_union :: SheetSchema.t() | Union.t()
  @type parse_opts :: [
          format: :csv | :xlsx,
          delimiter: String.t(),
          encoding: atom(),
          worksheet: {:name, String.t()} | {:index, non_neg_integer()},
          header: :auto | :present | :absent
        ]

  @spec parse_file(path(), schema_or_union()) :: {:ok, Result.t()} | {:error, map()}
  def parse_file(path, schema_or_union) do
    parse_file(path, schema_or_union, [])
  end

  @spec parse_file(path(), schema_or_union(), parse_opts()) :: {:ok, Result.t()} | {:error, map()}
  def parse_file(path, schema_or_union, opts) do
    with {:ok, adapter} <- Registry.adapter_for(path, opts),
         {:ok, stream} <- adapter.stream_rows(path, opts) do
      Parser.parse(stream, schema_or_union, opts)
    end
  end

  @spec list_sheets(path()) :: {:ok, [map()]} | {:error, map()}
  def list_sheets(path) do
    list_sheets(path, [])
  end

  @spec list_sheets(path(), keyword()) :: {:ok, [map()]} | {:error, map()}
  def list_sheets(path, opts) do
    with {:ok, adapter} <- Registry.adapter_for(path, opts) do
      adapter.list_sheets(path, opts)
    end
  end
end
