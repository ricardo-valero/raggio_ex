defmodule RaggioTabular do
  @moduledoc """
  CSV/Excel parsing and validation library built on Raggio.Schema.

  Provides tools for parsing tabular data from CSV/TSV files and validating
  rows against schema definitions.

  ## Example

      schema = RaggioTabular.SheetSchema.define([
        {:id, Raggio.Schema.integer()},
        {:name, Raggio.Schema.string(min: 1)},
        {:email, Raggio.Schema.string(pattern: Raggio.Schema.email())}
      ])

      result = RaggioTabular.parse("data.csv", schema)
      # => {:ok, %{valid_rows: [...], invalid_rows: [...], errors: [...]}}
  """

  alias RaggioTabular.{Parser, SheetSchema, Adapter}

  @doc """
  Parse a CSV file using the given schema.
  """
  def parse(path, schema, opts \\ []) do
    Parser.parse_file(path, schema, opts)
  end

  @doc """
  Parse CSV content string using the given schema.
  """
  def parse_string(content, schema, opts \\ []) do
    Parser.parse_string(content, schema, opts)
  end

  @doc """
  Define a schema for tabular data parsing.
  """
  def define_schema(fields) do
    SheetSchema.define(fields)
  end

  @doc """
  Process rows in batches with progress tracking.
  """
  def process_batch(rows, schema, opts \\ []) do
    Adapter.process_batch(rows, schema, opts)
  end
end
