defmodule Raggio.BigQuery.Table do
  @moduledoc """
  Behaviour for BigQuery table definitions.

  Implement this behaviour to define a BigQuery table schema with metadata.
  Uses Raggio.Schema for type definitions.

  ## Example

      defmodule MyApp.Tables.Charges do
        use Raggio.BigQuery.Table
        alias Raggio.Schema

        @impl true
        def __dataset__, do: "billing"

        @impl true
        def __table__, do: "charges"

        @impl true
        def __schema__ do
          Schema.struct([
            {:id, Schema.string()},
            {:amount, Schema.decimal()},
            {:status, Schema.literal(:pending, :completed, :failed)},
            {:created_at, Schema.datetime()}
          ])
        end

        @impl true
        def __time_partitioning__, do: [field: :created_at, type: :day]

        @impl true
        def __clustering__, do: [:status]
      end

  ## Generated Functions

  Using this module generates the following functions:

  - `__qualified_name__/0` - Returns "dataset.table"
  - `to_create_table_ddl/0` - Returns BigQuery CREATE TABLE DDL
  - `to_bigquery_schema/0` - Returns BigQuery REST API schema format
  """

  @callback __dataset__() :: String.t()
  @callback __table__() :: String.t()
  @callback __schema__() :: Raggio.Schema.AST.t()
  @callback __time_partitioning__() :: keyword() | nil
  @callback __clustering__() :: [atom()] | nil

  @optional_callbacks [__time_partitioning__: 0, __clustering__: 0]

  @type_mapping %{
    string: "STRING",
    integer: "INT64",
    float: "FLOAT64",
    boolean: "BOOL",
    decimal: "NUMERIC",
    datetime: "DATETIME",
    date: "DATE",
    atom: "STRING"
  }

  defmacro __using__(_opts) do
    quote do
      @behaviour Raggio.BigQuery.Table

      def __time_partitioning__, do: nil
      def __clustering__, do: nil

      def __qualified_name__ do
        "#{__dataset__()}.#{__table__()}"
      end

      def to_create_table_ddl do
        opts =
          []
          |> maybe_add_partition(__time_partitioning__())
          |> maybe_add_cluster(__clustering__())

        Raggio.Schema.Adapters.BigQuery.to_ddl(__schema__(), __qualified_name__(), opts)
      end

      def to_bigquery_schema do
        Raggio.BigQuery.Table.schema_to_bigquery_format(__schema__())
      end

      defp maybe_add_partition(opts, nil), do: opts

      defp maybe_add_partition(opts, partition) do
        field = Keyword.get(partition, :field)
        Keyword.put(opts, :partition_by, to_string(field))
      end

      defp maybe_add_cluster(opts, nil), do: opts
      defp maybe_add_cluster(opts, []), do: opts

      defp maybe_add_cluster(opts, fields) do
        Keyword.put(opts, :cluster_by, Enum.map(fields, &to_string/1))
      end

      defoverridable __time_partitioning__: 0, __clustering__: 0
    end
  end

  @doc false
  def schema_to_bigquery_format(%Raggio.Schema.AST{kind: :struct, fields: fields}) do
    %{
      "fields" =>
        Enum.map(fields, fn {name, type_schema} ->
          field_to_bigquery(name, type_schema)
        end)
    }
  end

  defp field_to_bigquery(name, %Raggio.Schema.AST{} = schema) do
    base = %{
      "name" => to_string(name),
      "type" => type_to_bigquery(schema),
      "mode" => mode_to_bigquery(schema)
    }

    case schema.kind do
      :struct ->
        Map.put(base, "fields", nested_fields_to_bigquery(schema.fields))

      :list ->
        case schema.inner do
          %Raggio.Schema.AST{kind: :struct, fields: inner_fields} ->
            Map.put(base, "fields", nested_fields_to_bigquery(inner_fields))

          _ ->
            base
        end

      _ ->
        base
    end
  end

  defp nested_fields_to_bigquery(fields) do
    Enum.map(fields, fn {name, schema} ->
      field_to_bigquery(name, schema)
    end)
  end

  defp type_to_bigquery(%Raggio.Schema.AST{kind: :list, inner: inner}) do
    type_to_bigquery(inner)
  end

  defp type_to_bigquery(%Raggio.Schema.AST{kind: :struct}) do
    "RECORD"
  end

  defp type_to_bigquery(%Raggio.Schema.AST{kind: kind}) do
    Map.get(@type_mapping, kind, "STRING")
  end

  defp mode_to_bigquery(%Raggio.Schema.AST{kind: :list}) do
    "REPEATED"
  end

  defp mode_to_bigquery(%Raggio.Schema.AST{context: %Raggio.Schema.Context{optional?: true}}) do
    "NULLABLE"
  end

  defp mode_to_bigquery(%Raggio.Schema.AST{context: %Raggio.Schema.Context{nullable?: true}}) do
    "NULLABLE"
  end

  defp mode_to_bigquery(_) do
    "REQUIRED"
  end
end
