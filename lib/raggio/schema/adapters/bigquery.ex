defmodule Raggio.Schema.Adapters.BigQuery do
  @moduledoc """
  Export Raggio.Schema definitions to BigQuery Standard SQL DDL.
  """

  alias Raggio.Schema.{AST, Context}

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

  def to_ddl(schema, table_name), do: to_ddl(schema, table_name, [])

  def to_ddl(%AST{kind: :struct, fields: fields}, table_name, opts) do
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

  defp build_columns(fields, indent) do
    fields
    |> Enum.map(fn {name, schema} ->
      type_str = to_bq_type(schema)
      %Context{optional?: optional?, nullable?: nullable?} = schema.context
      nullable = if optional? or nullable?, do: "", else: " NOT NULL"
      "#{indent}#{name} #{type_str}#{nullable}"
    end)
    |> Enum.join(",\n")
  end

  defp to_bq_type(%AST{kind: :list, inner: inner}) do
    "ARRAY<#{to_bq_type(inner)}>"
  end

  defp to_bq_type(%AST{kind: :struct, fields: fields}) do
    field_defs =
      fields
      |> Enum.map(fn {name, schema} ->
        type_str = to_bq_type(schema)
        "#{name} #{type_str}"
      end)
      |> Enum.join(", ")

    "STRUCT<#{field_defs}>"
  end

  defp to_bq_type(%AST{kind: kind}) do
    Map.get(@type_mapping, kind, "STRING")
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
