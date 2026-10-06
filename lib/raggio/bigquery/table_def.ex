defmodule Raggio.BigQuery.TableDef do
  @moduledoc """
  Represents a BigQuery table definition with schema and options.

  ## Fields

  - `name` - Table identifier
  - `columns` - List of `Raggio.BigQuery.Column` definitions
  - `partition_by` - Partitioning configuration (optional)
  - `cluster_by` - List of clustering columns, max 4 (optional)
  - `description` - Table description (optional)
  - `expiration_time` - Table expiration DateTime (optional)
  - `metadata` - Custom metadata map

  ## Partition Configuration

  The `partition_by` field supports:

  - `{:field, column_name, granularity}` - TIME partitioning on a column
  - `{:range, column_name, start, end, interval}` - RANGE partitioning
  - `{:ingestion_time, granularity}` - Partitioning by ingestion time

  Where `granularity` is one of: `:hour`, `:day`, `:month`, `:year`

  ## Validation Rules

  - `name` must match `^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$`
  - `columns` names must be unique within table
  - `cluster_by` max 4 columns, must reference valid column names
  - `partition_by` field must reference valid column or use pseudo-column

  ## Examples

      %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :created_at, type: %Type{kind: :datetime}, mode: :required}
        ],
        partition_by: {:field, :created_at, :day},
        cluster_by: [:user_id, :event_type]
      }
  """

  alias Raggio.BigQuery.{Column, Error}

  @type partition_config ::
          {:field, atom(), :hour | :day | :month | :year}
          | {:range, atom(), integer(), integer(), integer()}
          | {:ingestion_time, :hour | :day | :month | :year}
          | nil

  @type t :: %__MODULE__{
          name: String.t(),
          columns: [Column.t()],
          partition_by: partition_config(),
          cluster_by: [atom()] | nil,
          description: String.t() | nil,
          expiration_time: DateTime.t() | nil,
          metadata: map()
        }

  defstruct name: nil,
            columns: [],
            partition_by: nil,
            cluster_by: nil,
            description: nil,
            expiration_time: nil,
            metadata: %{}

  # Valid table name pattern
  @name_pattern ~r/^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$/

  # Valid partition granularities
  @valid_granularities [:hour, :day, :month, :year]

  # Max clustering columns
  @max_cluster_columns 4

  @doc """
  Creates a new TableDef struct.

  ## Options

  - `:partition_by` - Partitioning configuration
  - `:cluster_by` - List of clustering columns (max 4)
  - `:description` - Table description
  - `:expiration_time` - Table expiration DateTime
  - `:metadata` - Custom metadata map

  ## Examples

      iex> TableDef.new("events", columns, partition_by: {:field, :created_at, :day})
      %TableDef{name: "events", columns: columns, partition_by: {:field, :created_at, :day}}
  """
  @spec new(String.t(), [Column.t()], keyword()) :: t()
  def new(name, columns, opts \\ []) do
    %__MODULE__{
      name: name,
      columns: columns,
      partition_by: Keyword.get(opts, :partition_by),
      cluster_by: Keyword.get(opts, :cluster_by),
      description: Keyword.get(opts, :description),
      expiration_time: Keyword.get(opts, :expiration_time),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validates a TableDef struct and returns errors if any.

  ## Returns

  - `{:ok, table_def}` if valid
  - `{:error, errors}` if invalid, where errors is a list of `Error` structs

  ## Examples

      iex> TableDef.validate(%TableDef{name: "events", columns: [...]})
      {:ok, %TableDef{name: "events", columns: [...]}}

      iex> TableDef.validate(%TableDef{name: "123bad", columns: []})
      {:error, [%Error{type: :invalid_table_name, ...}]}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Error.t()]}
  def validate(%__MODULE__{} = table) do
    errors =
      []
      |> validate_name(table)
      |> validate_unique_columns(table)
      |> validate_columns(table)
      |> validate_partition_by(table)
      |> validate_cluster_by(table)

    case errors do
      [] -> {:ok, table}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Gets a column by name from the table.
  """
  @spec get_column(t(), atom() | String.t()) :: Column.t() | nil
  def get_column(%__MODULE__{columns: columns}, name) do
    name_atom = if is_binary(name), do: String.to_atom(name), else: name
    Enum.find(columns, fn col -> col.name == name_atom or col.name == name end)
  end

  @doc """
  Returns all column names in the table.
  """
  @spec column_names(t()) :: [atom() | String.t()]
  def column_names(%__MODULE__{columns: columns}) do
    Enum.map(columns, & &1.name)
  end

  # ============================================================================
  # DDL Generation
  # ============================================================================

  @doc """
  Generate BigQuery DDL (CREATE TABLE) for this table definition.

  ## Parameters

  - `table` - The TableDef struct
  - `qualified_prefix` - The project.dataset prefix (e.g., "my-project.analytics")

  ## Options

  - `:if_not_exists` - Add IF NOT EXISTS clause (default: false)

  ## Examples

      iex> TableDef.to_ddl(table, "my-project.analytics")
      "CREATE TABLE `my-project.analytics.events` (..."
  """
  @spec to_ddl(t(), String.t(), keyword()) :: String.t()
  def to_ddl(%__MODULE__{} = table, qualified_prefix, opts \\ []) do
    if_not_exists = if Keyword.get(opts, :if_not_exists, false), do: "IF NOT EXISTS ", else: ""
    full_name = "#{qualified_prefix}.#{table.name}"

    columns_ddl = build_columns_ddl(table.columns)
    partition_ddl = build_partition_ddl(table.partition_by)
    cluster_ddl = build_cluster_ddl(table.cluster_by)
    options_ddl = build_options_ddl(table.description)

    """
    CREATE TABLE #{if_not_exists}`#{full_name}` (
    #{columns_ddl}
    )#{partition_ddl}#{cluster_ddl}#{options_ddl}
    """
    |> String.trim_trailing()
  end

  @doc """
  Generate BigQuery REST API schema format for this table.

  Returns a list of field definitions suitable for the BigQuery API.

  ## Examples

      iex> TableDef.to_bigquery_schema(table)
      [%{"name" => "id", "type" => "STRING", "mode" => "REQUIRED"}, ...]
  """
  @spec to_bigquery_schema(t()) :: [map()]
  def to_bigquery_schema(%__MODULE__{columns: columns}) do
    Enum.map(columns, &column_to_schema_field/1)
  end

  # ============================================================================
  # DDL Generation Helpers
  # ============================================================================

  defp build_columns_ddl(columns) do
    columns
    |> Enum.map(&column_to_ddl/1)
    |> Enum.join(",\n")
  end

  defp column_to_ddl(%Column{name: name, type: type, mode: mode}) do
    type_str = type_to_ddl(type, mode)
    nullable_str = if mode == :required, do: " NOT NULL", else: ""
    "  #{name} #{type_str}#{nullable_str}"
  end

  defp type_to_ddl(%Raggio.Schema.Type{kind: :list, inner: inner}, _mode) do
    "ARRAY<#{type_to_ddl(inner, :nullable)}>"
  end

  defp type_to_ddl(%Raggio.Schema.Type{kind: :struct, fields: fields}, _mode) do
    field_defs =
      fields
      |> Enum.map(fn {name, type} ->
        "#{name} #{type_to_ddl(type, :nullable)}"
      end)
      |> Enum.join(", ")

    "STRUCT<#{field_defs}>"
  end

  defp type_to_ddl(%Raggio.Schema.Type{kind: kind}, :repeated) do
    "ARRAY<#{kind_to_bq_type(kind)}>"
  end

  defp type_to_ddl(%Raggio.Schema.Type{kind: kind}, _mode) do
    kind_to_bq_type(kind)
  end

  defp kind_to_bq_type(:string), do: "STRING"
  defp kind_to_bq_type(:integer), do: "INT64"
  defp kind_to_bq_type(:float), do: "FLOAT64"
  defp kind_to_bq_type(:boolean), do: "BOOL"
  defp kind_to_bq_type(:decimal), do: "NUMERIC"
  defp kind_to_bq_type(:datetime), do: "DATETIME"
  defp kind_to_bq_type(:date), do: "DATE"
  defp kind_to_bq_type(:time), do: "TIME"
  defp kind_to_bq_type(:timestamp), do: "TIMESTAMP"
  defp kind_to_bq_type(:binary), do: "BYTES"
  defp kind_to_bq_type(:atom), do: "STRING"
  defp kind_to_bq_type(_), do: "STRING"

  defp build_partition_ddl(nil), do: ""

  defp build_partition_ddl({:field, column, granularity}) do
    partition_expr = partition_expression(column, granularity)
    "\nPARTITION BY #{partition_expr}"
  end

  defp build_partition_ddl({:ingestion_time, granularity}) do
    partition_expr = ingestion_time_expression(granularity)
    "\nPARTITION BY #{partition_expr}"
  end

  defp build_partition_ddl({:range, column, start_val, end_val, interval}) do
    "\nPARTITION BY RANGE_BUCKET(#{column}, GENERATE_ARRAY(#{start_val}, #{end_val}, #{interval}))"
  end

  defp partition_expression(column, :hour), do: "TIMESTAMP_TRUNC(#{column}, HOUR)"
  defp partition_expression(column, :day), do: "DATE(#{column})"
  defp partition_expression(column, :month), do: "DATE_TRUNC(#{column}, MONTH)"
  defp partition_expression(column, :year), do: "DATE_TRUNC(#{column}, YEAR)"

  defp ingestion_time_expression(:hour), do: "TIMESTAMP_TRUNC(_PARTITIONTIME, HOUR)"
  defp ingestion_time_expression(:day), do: "_PARTITIONDATE"
  defp ingestion_time_expression(:month), do: "DATE_TRUNC(_PARTITIONDATE, MONTH)"
  defp ingestion_time_expression(:year), do: "DATE_TRUNC(_PARTITIONDATE, YEAR)"

  defp build_cluster_ddl(nil), do: ""
  defp build_cluster_ddl([]), do: ""

  defp build_cluster_ddl(columns) when is_list(columns) do
    "\nCLUSTER BY #{Enum.join(columns, ", ")}"
  end

  defp build_options_ddl(nil), do: ""

  defp build_options_ddl(description) when is_binary(description) do
    "\nOPTIONS (description = \"#{escape_string(description)}\")"
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  # BigQuery REST API schema format

  defp column_to_schema_field(%Column{name: name, type: type, mode: mode, description: desc}) do
    field = %{
      "name" => to_string(name),
      "type" => schema_field_type(type),
      "mode" => schema_field_mode(mode)
    }

    field = if desc, do: Map.put(field, "description", desc), else: field

    case type do
      %Raggio.Schema.Type{kind: :struct, fields: fields} ->
        nested_fields =
          Enum.map(fields, fn {n, t} ->
            %{
              "name" => to_string(n),
              "type" => schema_field_type(t),
              "mode" => "NULLABLE"
            }
          end)

        Map.put(field, "fields", nested_fields)

      _ ->
        field
    end
  end

  defp schema_field_type(%Raggio.Schema.Type{kind: :struct}), do: "RECORD"

  defp schema_field_type(%Raggio.Schema.Type{kind: :list, inner: inner}),
    do: schema_field_type(inner)

  defp schema_field_type(%Raggio.Schema.Type{kind: kind}), do: kind_to_bq_type(kind)

  defp schema_field_mode(:required), do: "REQUIRED"
  defp schema_field_mode(:repeated), do: "REPEATED"
  defp schema_field_mode(_), do: "NULLABLE"

  # ============================================================================
  # Private Validation Helpers
  # ============================================================================

  # Private validation helpers

  defp validate_name(errors, %{name: nil}) do
    [Error.new(:invalid_table_name, "Table name is required", [:name]) | errors]
  end

  defp validate_name(errors, %{name: name}) do
    if Regex.match?(@name_pattern, name) do
      errors
    else
      [
        Error.new(
          :invalid_table_name,
          "Table name must match pattern: starts with letter/underscore, max 1024 chars",
          [:name]
        )
        | errors
      ]
    end
  end

  defp validate_unique_columns(errors, %{columns: columns}) do
    names = Enum.map(columns, & &1.name)
    duplicates = names -- Enum.uniq(names)

    case duplicates do
      [] ->
        errors

      dups ->
        [
          Error.new(
            :duplicate_column,
            "Duplicate column names: #{inspect(Enum.uniq(dups))}",
            [:columns]
          )
          | errors
        ]
    end
  end

  defp validate_columns(errors, %{columns: columns}) do
    columns
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {column, idx}, acc ->
      case Column.validate(column) do
        {:ok, _} -> acc
        {:error, col_errors} -> prepend_path_errors(acc, col_errors, [:columns, idx])
      end
    end)
  end

  defp validate_partition_by(errors, %{partition_by: nil}), do: errors

  defp validate_partition_by(errors, %{partition_by: {:ingestion_time, granularity}}) do
    if granularity in @valid_granularities do
      errors
    else
      [
        Error.new(
          :invalid_partition_field,
          "Invalid partition granularity: #{inspect(granularity)}. Must be :hour, :day, :month, or :year",
          [:partition_by]
        )
        | errors
      ]
    end
  end

  defp validate_partition_by(errors, %{
         partition_by: {:field, column_name, granularity},
         columns: columns
       }) do
    errors = validate_granularity(errors, granularity)
    validate_column_exists(errors, column_name, columns, :partition_by)
  end

  defp validate_partition_by(errors, %{
         partition_by: {:range, column_name, _start, _end, _interval},
         columns: columns
       }) do
    validate_column_exists(errors, column_name, columns, :partition_by)
  end

  defp validate_partition_by(errors, %{partition_by: invalid}) do
    [
      Error.new(
        :invalid_partition_field,
        "Invalid partition configuration: #{inspect(invalid)}",
        [:partition_by]
      )
      | errors
    ]
  end

  defp validate_granularity(errors, granularity) when granularity in @valid_granularities,
    do: errors

  defp validate_granularity(errors, granularity) do
    [
      Error.new(
        :invalid_partition_field,
        "Invalid partition granularity: #{inspect(granularity)}. Must be :hour, :day, :month, or :year",
        [:partition_by]
      )
      | errors
    ]
  end

  defp validate_cluster_by(errors, %{cluster_by: nil}), do: errors
  defp validate_cluster_by(errors, %{cluster_by: []}), do: errors

  defp validate_cluster_by(errors, %{cluster_by: cluster_cols, columns: columns})
       when is_list(cluster_cols) do
    errors =
      if length(cluster_cols) > @max_cluster_columns do
        [
          Error.new(
            :invalid_clustering,
            "Clustering columns cannot exceed #{@max_cluster_columns}, got: #{length(cluster_cols)}",
            [:cluster_by]
          )
          | errors
        ]
      else
        errors
      end

    # Validate each cluster column exists
    Enum.reduce(cluster_cols, errors, fn col_name, acc ->
      validate_column_exists(acc, col_name, columns, :cluster_by)
    end)
  end

  defp validate_cluster_by(errors, %{cluster_by: invalid}) do
    [
      Error.new(
        :invalid_clustering,
        "cluster_by must be a list of column names, got: #{inspect(invalid)}",
        [:cluster_by]
      )
      | errors
    ]
  end

  defp validate_column_exists(errors, column_name, columns, path) do
    column_names = Enum.map(columns, & &1.name)
    name_atom = if is_binary(column_name), do: String.to_atom(column_name), else: column_name

    if name_atom in column_names or column_name in column_names do
      errors
    else
      error_type =
        if path == :partition_by, do: :invalid_partition_field, else: :invalid_clustering

      [
        Error.new(
          error_type,
          "Column '#{column_name}' referenced but not defined in table",
          [path]
        )
        | errors
      ]
    end
  end

  defp prepend_path_errors(errors, new_errors, prefix) do
    Enum.reduce(new_errors, errors, fn error, acc ->
      [%{error | path: prefix ++ error.path} | acc]
    end)
  end
end
