defmodule Manuable.DataSchema.SheetSchema do
  @moduledoc """
  Declarative sheet schema definitions using plain Elixir data structures.

  SheetSchema provides a functional API for defining how to parse tabular data
  (Excel, CSV) without macros or behaviours. Schemas are plain data structures
  that can be inspected, validated, and tested.

  ## Usage

      import DataSchema.SheetSchema
      import DataSchema.Builders
      import DataSchema.Transforms.Excel

      schema = sheet(
        %{
          tracking: [at: 2, header: "Guia", type: string() |> excel_string()],
          carrier:  [at: 3, header: "Mensajeria", type: string() |> excel_string()],
          amount:   [at: 4, header: "Total", type: decimal() |> excel_decimal()]
        },
        name: :total_v1
      )

      {:ok, {valid, invalid}} = parse(rows, schema)

  ## Column Definition

  Each column is defined as a keyword list with:

  - `:at` - 0-based column index (required if no `:header`)
  - `:header` - Expected header text, exact match (required if no `:at`)
  - `:type` - TypeDef from `DataSchema.Builders` (required)
  - `:optional` - Whether the column can be missing (default: `false`)

  At least one of `:at` or `:header` must be specified. If both are specified,
  both must match during header detection.

  ## Sheet Options

  - `:name` - Optional atom identifier for debugging/matching
  - `:range` - Row ranges to parse, e.g., `[2..10, 15..]`

  ## Unions

  Use `union/2` to handle multiple sheet formats:

      schema = union([
        sheet(%{tracking: [at: 2, header: "Guia", type: string()]}),
        sheet(%{tracking: [at: 2, header: "guia", type: string()]})
      ])

  ## Header Modes

  - **Header-enabled**: If any column declares `:header`, the first row is
    treated as a header row and validated.
  - **Header-disabled**: If no columns declare `:header`, parsing starts from
    the first row with no header validation.
  """

  alias Manuable.DataSchema.SheetSchema.{ColumnDef, Parser, SheetDef, Union, Validator}

  # =============================================================================
  # Builder Functions
  # =============================================================================

  @doc """
  Creates a sheet schema from a column definition map.

  ## Parameters

  - `columns` - Map of `%{column_name => [opts]}` where opts include:
    - `:at` - 0-based column index
    - `:header` - Header text (exact match)
    - `:type` - TypeDef from DataSchema.Builders
    - `:optional` - Whether column can be missing (default: false)

  - `opts` - Sheet options:
    - `:name` - Optional identifier
    - `:range` - Row ranges to parse

  ## Examples

      # Position + header (strongest matching)
      sheet(%{
        tracking: [at: 2, header: "Guia", type: string()],
        amount:   [at: 4, header: "Total", type: decimal()]
      })

      # Header-only (position discovered at runtime)
      sheet(%{
        tracking: [header: "Guia", type: string()],
        amount:   [header: "Total", type: decimal()]
      })

      # Position-only (no header detection)
      sheet(%{
        tracking: [at: 0, type: string()],
        amount:   [at: 1, type: decimal()]
      })

      # With row range
      sheet(%{tracking: [at: 0, type: string()]}, range: [2..100])
  """
  @spec sheet(map(), keyword()) :: SheetDef.t()
  def sheet(columns, opts \\ []) when is_map(columns) do
    column_defs = build_columns(columns)
    header_mode = derive_header_mode(column_defs)

    schema = %SheetDef{
      columns: column_defs,
      range: Keyword.get(opts, :range),
      name: Keyword.get(opts, :name),
      header_mode: header_mode,
      metadata: Keyword.get(opts, :metadata, [])
    }

    # Validate at build time - raise on error
    Validator.validate!(schema)

    schema
  end

  @doc """
  Creates a union of sheet schemas.

  Parsing succeeds if at least one schema matches (`:first_match` strategy)
  or exactly one schema matches (`:exact_one` strategy).

  ## Options

  - `:strategy` - `:first_match` (default) or `:exact_one`

  ## Examples

      union([
        sheet(%{tracking: [at: 2, header: "Guia", type: string()]}),
        sheet(%{tracking: [at: 2, header: "guia", type: string()]})
      ])

      # Require exactly one match
      union([schema1, schema2], strategy: :exact_one)
  """
  @spec union([SheetDef.t()], keyword()) :: Union.t()
  def union(schemas, opts \\ []) when is_list(schemas) do
    %Union{
      schemas: schemas,
      strategy: Keyword.get(opts, :strategy, :first_match)
    }
  end

  # =============================================================================
  # Parsing Functions
  # =============================================================================

  @doc """
  Parses rows using a sheet schema or union.

  ## Returns

  - `{:ok, {valid_rows, invalid_rows}}` on success
  - `{:error, reason}` on failure (e.g., no header match)

  Where:
  - `valid_rows` - List of `{row_number, parsed_map}` tuples
  - `invalid_rows` - List of `%ParseError{}` structs

  ## Examples

      {:ok, {valid, invalid}} = parse(rows, schema)
      # valid = [{2, %{tracking: "123", amount: Decimal.new("100")}}]
  """
  @spec parse([list()], SheetDef.t() | Union.t()) ::
          {:ok, {[{pos_integer(), map()}], [DataSchema.ParseError.t()]}}
          | {:error, term()}
  defdelegate parse(rows, schema), to: Parser

  @doc """
  Parses rows and raises on error.
  """
  @spec parse!([list()], SheetDef.t() | Union.t()) ::
          {[{pos_integer(), map()}], [DataSchema.ParseError.t()]}
  defdelegate parse!(rows, schema), to: Parser

  # =============================================================================
  # Private Helpers
  # =============================================================================

  defp build_columns(columns) do
    Map.new(columns, fn {name, opts} ->
      column = %ColumnDef{
        name: name,
        at: Keyword.get(opts, :at),
        header: Keyword.get(opts, :header),
        type: Keyword.fetch!(opts, :type),
        optional: Keyword.get(opts, :optional, false)
      }

      {name, column}
    end)
  end

  defp derive_header_mode(columns) do
    has_headers = Enum.any?(columns, fn {_, col} -> col.header != nil end)
    if has_headers, do: :enabled, else: :disabled
  end
end
