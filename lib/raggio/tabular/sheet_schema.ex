defmodule Raggio.Tabular.SheetSchema do
  @moduledoc """
  Declarative schema for mapping tabular columns to typed fields.

  ## Overview

  A `SheetSchema` defines how to map columns from a tabular source (CSV, XLSX, etc.)
  to typed Elixir fields. It specifies:

  - Column-to-field mappings with type validation
  - Header handling (auto-detect, explicit present/absent)
  - Header variants for alternate column names
  - Row filtering (skip rows, row ranges)
  - Value transforms (cleanup spreadsheet messiness)

  ## Basic Usage

      alias Raggio.Tabular.SheetSchema
      alias Raggio.Schema

      schema = SheetSchema.define([
        {:name, Schema.string()},
        {:age, Schema.integer()},
        {:email, Schema.string(), header: "Email Address", required: false}
      ])

      # Parse with explicit parser (parser-agnostic architecture)
      {:ok, result} = Raggio.Tabular.parse("users.csv", schema,
        parser: MyApp.CSVParser
      )

  ## Column Definition Options

  Each column is a tuple of `{field_name, type_schema}` or `{field_name, type_schema, opts}`:

      {:field, Schema.string()}                    # Basic column
      {:field, Schema.integer(), required: false}  # Optional column
      {:field, Schema.string(), header: "Column"}  # Custom header name
      {:field, Schema.integer(), at: 0}            # Column by index (0-based)

  ## Header Variants

  Support alternate header names that map to the same field:

      schema
      |> SheetSchema.with_header_variants(%{
        "id" => :user_id,
        "uid" => :user_id,
        "user_id" => :user_id,
        "name" => :full_name,
        "full_name" => :full_name
      })

  ## Row Filtering

  Skip leading rows or process only a range:

      schema
      |> SheetSchema.with_row_filters(%{
        skip_rows: 2,        # Skip first 2 data rows
        row_range: 3..100    # Process only rows 3-100
      })

  ## Value Transforms

  Apply transforms to clean up messy spreadsheet values:

      alias Raggio.Tabular.Transform

      schema
      |> SheetSchema.with_transforms([
        Transform.trim_whitespace(),
        Transform.strip_currency(),
        Transform.remove_thousand_separators()
      ])

  ## Union Schemas

  Handle multiple format variants with union schemas:

      v1_schema = SheetSchema.define([{:id, Schema.integer()}, ...])
      v2_schema = SheetSchema.define([{:identifier, Schema.string()}, ...])

      union = SheetSchema.union([v1_schema, v2_schema], strategy: :first_match)

  See `Raggio.Tabular.Union` for more on union schema strategies.
  """

  alias Raggio.Tabular.{ColumnDef, Union}

  @type header_mode :: :auto | :present | :absent
  @type header_variants :: %{String.t() => atom()}
  @type row_filters :: %{
          optional(:skip_rows) => non_neg_integer(),
          optional(:row_range) => Range.t()
        }

  @type transforms :: [function()] | function() | nil

  @type t :: %__MODULE__{
          columns: [ColumnDef.t()],
          header_mode: header_mode(),
          header_variants: header_variants(),
          row_filters: row_filters(),
          transforms: transforms()
        }

  defstruct columns: [],
            header_mode: :auto,
            header_variants: %{},
            row_filters: %{},
            transforms: nil

  @spec define([tuple()]) :: t()
  def define(fields) when is_list(fields) do
    columns = Enum.with_index(fields) |> Enum.map(&build_column/1)
    %__MODULE__{columns: columns}
  end

  @spec with_header_mode(t(), header_mode()) :: t()
  def with_header_mode(%__MODULE__{} = schema, mode) when mode in [:auto, :present, :absent] do
    %{schema | header_mode: mode}
  end

  @spec with_header_variants(t(), header_variants() | [{String.t(), atom()}]) :: t()
  def with_header_variants(%__MODULE__{} = schema, variants) when is_map(variants) do
    %{schema | header_variants: variants}
  end

  def with_header_variants(%__MODULE__{} = schema, variants) when is_list(variants) do
    %{schema | header_variants: Map.new(variants)}
  end

  @spec with_row_filters(t(), row_filters()) :: t()
  def with_row_filters(%__MODULE__{} = schema, filters) when is_map(filters) do
    %{schema | row_filters: filters}
  end

  @spec with_transforms(t(), transforms()) :: t()
  def with_transforms(%__MODULE__{} = schema, transforms) do
    %{schema | transforms: transforms}
  end

  @spec required_headers(t()) :: [String.t()]
  def required_headers(%__MODULE__{columns: columns}) do
    columns
    |> Enum.filter(& &1.required)
    |> Enum.map(fn col -> col.header || Atom.to_string(col.field_name) end)
  end

  @spec union([t()], keyword()) :: Union.t()
  def union(schemas, opts \\ []) when is_list(schemas) do
    Union.new(schemas, opts)
  end

  defp build_column({{field_name, type_schema}, index}) do
    ColumnDef.new(field_name, type_schema, at: index)
  end

  defp build_column({{field_name, type_schema, opts}, index}) do
    opts = Keyword.put_new(opts, :at, index)
    ColumnDef.new(field_name, type_schema, opts)
  end
end
