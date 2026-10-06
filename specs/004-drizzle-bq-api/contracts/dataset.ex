# API Contract: Raggio.BigQuery.Dataset
# This file defines the expected public API - not implementation

defmodule Raggio.BigQuery.Dataset do
  @moduledoc """
  BigQuery dataset container for grouping related tables.

  A Dataset represents a BigQuery dataset within a project.
  It contains multiple table definitions and optional settings.

  ## Examples

      %Raggio.BigQuery.Dataset{
        name: "analytics",
        tables: [
          %Raggio.BigQuery.TableDef{name: "events", ...},
          %Raggio.BigQuery.TableDef{name: "users", ...}
        ],
        location: "US"
      }
  """

  @type t :: %__MODULE__{
          name: String.t(),
          tables: [Raggio.BigQuery.TableDef.t()],
          location: String.t() | nil,
          default_partition_expiration_ms: non_neg_integer() | nil,
          metadata: map()
        }

  @enforce_keys [:name]
  defstruct [
    :name,
    :location,
    :default_partition_expiration_ms,
    tables: [],
    metadata: %{}
  ]

  @doc """
  Validates a dataset struct and returns errors if invalid.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Raggio.BigQuery.Error.t()]}
  def validate(%__MODULE__{} = dataset)

  @doc """
  Looks up a table by name within this dataset.
  """
  @spec get_table(t(), String.t()) ::
          {:ok, Raggio.BigQuery.TableDef.t()} | {:error, :not_found}
  def get_table(%__MODULE__{} = dataset, table_name)

  @doc """
  Generates CREATE SCHEMA DDL for this dataset.

  ## Options
    - `:if_not_exists` - Add IF NOT EXISTS clause (default: false)
    - `:project_id` - Project ID for qualified name
  """
  @spec to_create_schema_ddl(t(), keyword()) :: String.t()
  def to_create_schema_ddl(%__MODULE__{} = dataset, opts \\ [])
end

defmodule Raggio.BigQuery.TableDef do
  @moduledoc """
  BigQuery table schema definition.

  Represents a table's structure including columns, partitioning,
  and clustering configuration.
  """

  @type partition_config ::
          {:field, atom(), :hour | :day | :month | :year}
          | {:range, atom(), integer(), integer(), integer()}
          | {:ingestion_time, :hour | :day | :month | :year}

  @type t :: %__MODULE__{
          name: String.t(),
          columns: [Raggio.BigQuery.Column.t()],
          partition_by: partition_config() | nil,
          cluster_by: [atom()],
          description: String.t() | nil,
          expiration_time: DateTime.t() | nil,
          metadata: map()
        }

  @enforce_keys [:name, :columns]
  defstruct [
    :name,
    :partition_by,
    :description,
    :expiration_time,
    columns: [],
    cluster_by: [],
    metadata: %{}
  ]

  @doc """
  Validates a table definition and returns errors if invalid.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Raggio.BigQuery.Error.t()]}
  def validate(%__MODULE__{} = table)

  @doc """
  Generates CREATE TABLE DDL for this table.

  ## Options
    - `:if_not_exists` - Add IF NOT EXISTS clause (default: false)
    - `:project_id` - Project ID for qualified name
    - `:dataset` - Dataset name for qualified name
  """
  @spec to_ddl(t(), keyword()) :: String.t()
  def to_ddl(%__MODULE__{} = table, opts \\ [])

  @doc """
  Converts table to BigQuery REST API schema format.
  """
  @spec to_bigquery_schema(t()) :: map()
  def to_bigquery_schema(%__MODULE__{} = table)
end

defmodule Raggio.BigQuery.Column do
  @moduledoc """
  BigQuery column definition within a table.
  """

  @type mode :: :nullable | :required | :repeated

  @type t :: %__MODULE__{
          name: atom(),
          type: Raggio.Schema.Type.t(),
          mode: mode(),
          description: String.t() | nil,
          default_value: any(),
          metadata: map()
        }

  @enforce_keys [:name, :type]
  defstruct [
    :name,
    :type,
    :description,
    :default_value,
    mode: :nullable,
    metadata: %{}
  ]

  @doc """
  Creates a column definition.

  ## Examples

      Column.new(:id, Schema.string(), mode: :required)
      Column.new(:tags, Schema.list(Schema.string()), mode: :repeated)
  """
  @spec new(atom(), Raggio.Schema.Type.t(), keyword()) :: t()
  def new(name, type, opts \\ [])
end
