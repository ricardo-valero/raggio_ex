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
  Convert canonical raggio.schema.Type to adapter-specific format with options.

  Same as `from_schema/1` but accepts additional options specific to each adapter.
  """
  @callback from_schema(Raggio.Schema.Type.t(), keyword()) :: {:ok, any()} | {:error, term()}

  @optional_callbacks [from_schema: 2]
end
