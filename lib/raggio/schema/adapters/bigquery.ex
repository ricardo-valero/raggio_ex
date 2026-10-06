defmodule Raggio.Schema.Adapters.BigQuery do
  @moduledoc """
  BigQuery adapter implementing the `Raggio.Schema.Adapter` behaviour.

  Provides bidirectional conversion between BigQuery.TableDef and raggio.schema.Type,
  as well as DDL generation.

  ## Converting BigQuery to Canonical

      table_def = %BigQuery.TableDef{
        name: "events",
        columns: [%Column{name: :id, type: Schema.string(), mode: :required}],
        partition_by: {:field, :created_at, :day}
      }

      canonical = Raggio.Schema.Adapters.BigQuery.to_schema(table_def)
      # => %Type{
      #      kind: :struct,
      #      fields: [{:id, %Type{kind: :string}}],
      #      metadata: %{
      #        bigquery: %{
      #          table_name: "events",
      #          partition_by: {:field, :created_at, :day}
      #        }
      #      }
      #    }

  ## Converting Canonical to BigQuery

      canonical = %Type{kind: :struct, fields: [...]}
      {:ok, table_def} = Raggio.Schema.Adapters.BigQuery.from_schema(canonical, name: "events")

  ## DDL Generation

      ddl = Raggio.Schema.Adapters.BigQuery.to_ddl(schema, "table_name", opts)
  """

  @behaviour Raggio.Schema.Adapter

  require Logger

  alias Raggio.Schema.Type
  alias Raggio.BigQuery.{Column, TableDef}

  # Mapping from raggio.schema kinds to BigQuery SQL types
  @schema_to_bq_type %{
    string: "STRING",
    integer: "INT64",
    float: "FLOAT64",
    boolean: "BOOL",
    decimal: "NUMERIC",
    datetime: "DATETIME",
    date: "DATE",
    time: "TIME",
    timestamp: "TIMESTAMP",
    binary: "BYTES",
    atom: "STRING"
  }

  # Reverse mapping from BigQuery types to raggio.schema kinds
  @bq_to_schema_type %{
    "STRING" => :string,
    "INT64" => :integer,
    "INTEGER" => :integer,
    "FLOAT64" => :float,
    "FLOAT" => :float,
    "BOOL" => :boolean,
    "BOOLEAN" => :boolean,
    "NUMERIC" => :decimal,
    "BIGNUMERIC" => :decimal,
    "DATETIME" => :datetime,
    "DATE" => :date,
    "TIME" => :time,
    "TIMESTAMP" => :timestamp,
    "BYTES" => :binary
  }

  # Known adapter namespaces for warning about foreign metadata
  @known_adapters [:bigquery, :api, :openapi, :json_schema]

  # ============================================================================
  # Adapter Behaviour Implementation
  # ============================================================================

  @impl Raggio.Schema.Adapter
  @doc """
  Returns `:bigquery` as the namespace for BigQuery-specific metadata.
  """
  @spec adapter_namespace() :: :bigquery
  def adapter_namespace, do: :bigquery

  @impl Raggio.Schema.Adapter
  @doc """
  Convert BigQuery.TableDef to canonical raggio.schema.Type.

  Preserves BigQuery-specific metadata (partitioning, clustering, etc.)
  under the `:bigquery` namespace in `Type.metadata`.

  ## Examples

      iex> table_def = %TableDef{name: "events", columns: [...]}
      iex> Raggio.Schema.Adapters.BigQuery.to_schema(table_def)
      %Type{kind: :struct, fields: [...], metadata: %{bigquery: %{table_name: "events"}}}
  """
  @spec to_schema(TableDef.t()) :: Type.t()
  def to_schema(%TableDef{} = table_def) do
    fields =
      table_def.columns
      |> Enum.map(fn %Column{name: name, type: type, mode: mode, description: desc} ->
        field_type = apply_mode_to_type(type, mode)

        field_type =
          if desc do
            %{field_type | metadata: Map.put(field_type.metadata, :description, desc)}
          else
            field_type
          end

        {normalize_name(name), field_type}
      end)

    bq_metadata =
      %{table_name: table_def.name}
      |> maybe_put(:partition_by, table_def.partition_by)
      |> maybe_put(:cluster_by, table_def.cluster_by)
      |> maybe_put(:description, table_def.description)

    base_metadata =
      if table_def.description do
        %{description: table_def.description}
      else
        %{}
      end

    %Type{
      kind: :struct,
      fields: fields,
      metadata: Map.put(base_metadata, :bigquery, bq_metadata)
    }
  end

  @impl Raggio.Schema.Adapter
  @doc """
  Convert canonical raggio.schema.Type to BigQuery.TableDef.

  Warns about metadata from other adapters that cannot be mapped.

  ## Options

  - `:name` - Table name (required if not in metadata)
  - `:warn` - Whether to log warnings for unmapped metadata (default: true)

  ## Returns

  - `{:ok, table_def}` on success
  - `{:error, reason}` if the schema cannot be converted

  ## Examples

      iex> schema = %Type{kind: :struct, fields: [{:id, %Type{kind: :string}}]}
      iex> {:ok, table_def} = Raggio.Schema.Adapters.BigQuery.from_schema(schema, name: "users")
      iex> table_def.name
      "users"
  """
  @spec from_schema(Type.t(), keyword()) :: {:ok, TableDef.t()} | {:error, term()}
  def from_schema(%Type{} = schema, opts \\ []) do
    warn? = Keyword.get(opts, :warn, true)

    if warn? do
      warn_foreign_metadata(schema.metadata)
    end

    case schema.kind do
      :struct ->
        bq_metadata = get_in(schema.metadata, [:bigquery]) || %{}

        table_name =
          Keyword.get(opts, :name) ||
            Map.get(bq_metadata, :table_name) ||
            "unnamed_table"

        columns = convert_fields_to_columns(schema.fields || [])

        table_def = %TableDef{
          name: table_name,
          columns: columns,
          partition_by: Map.get(bq_metadata, :partition_by),
          cluster_by: Map.get(bq_metadata, :cluster_by),
          description:
            Map.get(bq_metadata, :description) || Map.get(schema.metadata, :description),
          metadata: Map.drop(bq_metadata, [:table_name, :partition_by, :cluster_by, :description])
        }

        {:ok, table_def}

      other ->
        {:error,
         {:unsupported_type, other, "BigQuery tables require a struct type at root level"}}
    end
  end

  # ============================================================================
  # Type Mapping Functions
  # ============================================================================

  @doc """
  Convert a BigQuery SQL type string to raggio.schema kind.

  ## Examples

      iex> bigquery_type_to_schema("STRING")
      :string

      iex> bigquery_type_to_schema("INT64")
      :integer

      iex> bigquery_type_to_schema("ARRAY<STRING>")
      {:list, :string}
  """
  @spec bigquery_type_to_schema(String.t()) :: atom() | {:list, atom()} | {:struct, list()}
  def bigquery_type_to_schema(bq_type) when is_binary(bq_type) do
    bq_type = String.upcase(bq_type)

    cond do
      String.starts_with?(bq_type, "ARRAY<") ->
        inner = String.slice(bq_type, 6..-2//1)
        {:list, bigquery_type_to_schema(inner)}

      String.starts_with?(bq_type, "STRUCT<") ->
        # Parse struct fields - simplified parsing
        inner = String.slice(bq_type, 7..-2//1)
        {:struct, parse_struct_fields(inner)}

      true ->
        Map.get(@bq_to_schema_type, bq_type, :string)
    end
  end

  @doc """
  Convert a raggio.schema kind to BigQuery SQL type string.

  ## Examples

      iex> schema_to_bigquery_type(:string)
      "STRING"

      iex> schema_to_bigquery_type(:integer)
      "INT64"
  """
  @spec schema_to_bigquery_type(atom()) :: String.t()
  def schema_to_bigquery_type(kind) when is_atom(kind) do
    Map.get(@schema_to_bq_type, kind, "STRING")
  end

  @doc """
  Convert a Type struct to BigQuery SQL type string.
  """
  @spec type_to_bq_sql(Type.t()) :: String.t()
  def type_to_bq_sql(%Type{kind: :list, inner: inner}) do
    "ARRAY<#{type_to_bq_sql(inner)}>"
  end

  def type_to_bq_sql(%Type{kind: :struct, fields: fields}) do
    field_defs =
      fields
      |> Enum.map(fn {name, type} ->
        "#{name} #{type_to_bq_sql(type)}"
      end)
      |> Enum.join(", ")

    "STRUCT<#{field_defs}>"
  end

  def type_to_bq_sql(%Type{kind: kind}) do
    schema_to_bigquery_type(kind)
  end

  # ============================================================================
  # DDL Generation (Legacy API - kept for backward compatibility)
  # ============================================================================

  @doc """
  Generate BigQuery DDL from a schema Type.

  ## Examples

      iex> schema = %Type{kind: :struct, fields: [{:id, %Type{kind: :string}}]}
      iex> to_ddl(schema, "my_table")
      "CREATE TABLE `my_table` (\\n  id STRING NOT NULL\\n)"
  """
  @spec to_ddl(Type.t(), String.t()) :: String.t()
  def to_ddl(schema, table_name), do: to_ddl(schema, table_name, [])

  @spec to_ddl(Type.t(), String.t(), keyword()) :: String.t()
  def to_ddl(%Type{kind: :struct, fields: fields}, table_name, opts) do
    columns = build_columns(fields, "  ")
    partition = build_partition(opts)
    cluster = build_cluster(opts)
    description = build_description(opts)

    """
    CREATE TABLE `#{table_name}` (
    #{columns}
    )#{partition}#{cluster}#{description}
    """
    |> String.trim_trailing()
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp apply_mode_to_type(type, :repeated) do
    %Type{kind: :list, inner: type, metadata: type.metadata}
  end

  defp apply_mode_to_type(type, :required) do
    %{type | nullable: false, optional: false}
  end

  defp apply_mode_to_type(type, :nullable) do
    %{type | nullable: true}
  end

  defp apply_mode_to_type(type, _), do: type

  defp convert_fields_to_columns(fields) do
    Enum.map(fields, fn {name, type} ->
      {mode, inner_type} = extract_mode_and_type(type)

      %Column{
        name: name,
        type: inner_type,
        mode: mode,
        description: Map.get(type.metadata, :description),
        metadata: Map.drop(type.metadata, [:description])
      }
    end)
  end

  defp extract_mode_and_type(%Type{kind: :list, inner: inner}) do
    {:repeated, inner}
  end

  defp extract_mode_and_type(%Type{nullable: false, optional: false} = type) do
    {:required, type}
  end

  defp extract_mode_and_type(type) do
    {:nullable, type}
  end

  defp normalize_name(name) when is_atom(name), do: name
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp warn_foreign_metadata(metadata) when is_map(metadata) do
    foreign_keys =
      metadata
      |> Map.keys()
      |> Enum.filter(fn key ->
        key in @known_adapters and key != :bigquery
      end)

    Enum.each(foreign_keys, fn adapter ->
      adapter_metadata = Map.get(metadata, adapter, %{})
      keys = Map.keys(adapter_metadata)

      if keys != [] do
        Logger.warning("BigQuery adapter ignoring #{adapter} metadata: #{inspect(keys)}")
      end
    end)
  end

  defp warn_foreign_metadata(_), do: :ok

  defp parse_struct_fields(fields_str) do
    # Simple field parsing - handles basic cases
    # Full parsing would require proper lexer for nested types
    fields_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn field ->
      case String.split(field, " ", parts: 2) do
        [name, type] -> {String.to_atom(name), bigquery_type_to_schema(type)}
        [name] -> {String.to_atom(name), :string}
      end
    end)
  end

  # DDL building helpers (kept from original implementation)

  defp build_columns(fields, indent) do
    fields
    |> Enum.map(fn {name, schema} ->
      type_str = type_to_bq_sql(schema)
      nullable = if schema.optional or schema.nullable, do: "", else: " NOT NULL"
      "#{indent}#{name} #{type_str}#{nullable}"
    end)
    |> Enum.join(",\n")
  end

  defp build_partition(opts) do
    case Keyword.get(opts, :partition_by) do
      nil -> ""
      partition -> "\nPARTITION BY #{partition}"
    end
  end

  defp build_cluster(opts) do
    case Keyword.get(opts, :cluster_by) do
      nil -> ""
      [] -> ""
      fields -> "\nCLUSTER BY #{Enum.join(fields, ", ")}"
    end
  end

  defp build_description(opts) do
    case Keyword.get(opts, :description) do
      nil -> ""
      desc -> "\nOPTIONS (description = \"#{desc}\")"
    end
  end
end
