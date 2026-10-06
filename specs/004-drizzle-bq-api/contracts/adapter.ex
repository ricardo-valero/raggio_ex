# API Contract: Raggio.Schema.Adapter
# This file defines the expected public API - not implementation

defmodule Raggio.Schema.Adapter do
  @moduledoc """
  Behaviour for adapters that convert between raggio.schema.Type (canonical format)
  and adapter-specific formats.

  This enables "define once, deploy anywhere" workflows where schemas can be:
  - Defined in any adapter format (e.g., BigQuery DDL)
  - Converted to canonical raggio.schema.Type
  - Exported to any other adapter (e.g., future API, JSON-Schema)

  ## Implementing an Adapter

      defmodule MyApp.Adapters.CustomFormat do
        @behaviour Raggio.Schema.Adapter

        @impl true
        def adapter_namespace, do: :custom_format

        @impl true
        def to_schema(custom_struct) do
          # Convert to %Raggio.Schema.Type{}
          # Store adapter-specific metadata under namespace
          %Raggio.Schema.Type{
            kind: :struct,
            fields: convert_fields(custom_struct),
            metadata: %{
              custom_format: extract_custom_metadata(custom_struct)
            }
          }
        end

        @impl true
        def from_schema(%Raggio.Schema.Type{} = schema) do
          warn_foreign_metadata(schema.metadata, :custom_format)
          {:ok, convert_to_custom(schema)}
        end
      end

  ## Metadata Handling

  Adapter-specific metadata is stored under namespaced keys in `Type.metadata`:

      %Type{
        kind: :struct,
        metadata: %{
          bigquery: %{partition_by: {:field, :created_at, :day}},
          api: %{endpoint: "/users"},
          description: "Shared description"
        }
      }

  When converting via `from_schema/1`, adapters should:
  1. Extract their own namespace metadata
  2. Warn about foreign adapter metadata that can't be mapped
  3. Use portable metadata (e.g., :description) where applicable
  """

  @doc """
  Returns the namespace key used in Type.metadata for this adapter.

  ## Examples

      iex> Raggio.Schema.Adapters.BigQuery.adapter_namespace()
      :bigquery
  """
  @callback adapter_namespace() :: atom()

  @doc """
  Convert adapter-specific format to canonical raggio.schema.Type.

  Adapter-specific metadata should be preserved under the adapter's namespace
  key in `Type.metadata`.

  ## Examples

      # BigQuery TableDef → canonical Type
      table_def = %BigQuery.TableDef{name: "events", columns: [...], partition_by: ...}
      schema = Raggio.Schema.Adapters.BigQuery.to_schema(table_def)
      # => %Type{kind: :struct, metadata: %{bigquery: %{partition_by: ...}}}
  """
  @callback to_schema(adapter_format :: any()) :: Raggio.Schema.Type.t()

  @doc """
  Convert canonical raggio.schema.Type to adapter-specific format.

  Should emit warnings (via Logger) for metadata from other adapters that
  cannot be mapped to this adapter's format.

  ## Returns

  - `{:ok, adapter_format}` on success
  - `{:error, reason}` if the schema cannot be represented in this adapter's format

  ## Examples

      # Canonical Type → BigQuery TableDef
      schema = %Type{kind: :struct, fields: [...], metadata: %{api: %{endpoint: "/users"}}}
      {:ok, table_def} = Raggio.Schema.Adapters.BigQuery.from_schema(schema)
      # Logs: "BigQuery adapter ignoring api metadata: [:endpoint]"
  """
  @callback from_schema(Raggio.Schema.Type.t()) :: {:ok, any()} | {:error, term()}

  @doc """
  Optional callback to check if a Type can be converted to this adapter's format.

  Default implementation returns true for all types.
  """
  @callback can_convert?(Raggio.Schema.Type.t()) :: boolean()

  @optional_callbacks [can_convert?: 1]
end

defmodule Raggio.Schema.Adapters.BigQuery do
  @moduledoc """
  BigQuery adapter implementing the Raggio.Schema.Adapter behaviour.

  Provides bidirectional conversion between BigQuery.TableDef and raggio.schema.Type.

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
      {:ok, table_def} = Raggio.Schema.Adapters.BigQuery.from_schema(canonical)
  """

  @behaviour Raggio.Schema.Adapter

  @doc """
  Returns :bigquery as the namespace for BigQuery-specific metadata.
  """
  @spec adapter_namespace() :: :bigquery
  def adapter_namespace

  @doc """
  Convert BigQuery.TableDef to canonical raggio.schema.Type.

  Preserves BigQuery-specific metadata (partitioning, clustering, etc.)
  under the :bigquery namespace in Type.metadata.
  """
  @spec to_schema(Raggio.BigQuery.TableDef.t()) :: Raggio.Schema.Type.t()
  def to_schema(%Raggio.BigQuery.TableDef{} = table_def)

  @doc """
  Convert canonical raggio.schema.Type to BigQuery.TableDef.

  Warns about metadata from other adapters that cannot be mapped.

  ## Options

  - `:name` - Table name (required if not in metadata)
  - `:warn` - Whether to log warnings for unmapped metadata (default: true)
  """
  @spec from_schema(Raggio.Schema.Type.t(), keyword()) ::
          {:ok, Raggio.BigQuery.TableDef.t()} | {:error, term()}
  def from_schema(%Raggio.Schema.Type{} = schema, opts \\ [])

  @doc """
  Check if a Type can be represented as a BigQuery table.

  Returns false for types that have no BigQuery equivalent.
  """
  @spec can_convert?(Raggio.Schema.Type.t()) :: boolean()
  def can_convert?(%Raggio.Schema.Type{} = schema)
end
