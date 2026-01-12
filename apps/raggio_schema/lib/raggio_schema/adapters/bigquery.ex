defmodule Raggio.Schema.Adapters.BigQuery do
  @moduledoc """
  BigQuery DDL exporter for Raggio.Schema.

  Converts Raggio.Schema definitions to BigQuery standard SQL DDL.
  """

  @doc """
  Converts a Raggio.Schema to BigQuery DDL.

  ## Examples

      schema = Raggio.Schema.struct([
        {:id, Raggio.Schema.integer()},
        {:email, Raggio.Schema.string()}
      ])
      
      BigQuery.to_ddl(schema, "users")
      # => "CREATE TABLE `users` (\\n  id INT64,\\n  email STRING\\n)"
  """
  def to_ddl(%Raggio.Schema{} = schema, table_name, opts \\ []) do
    columns = generate_columns(schema)
    clauses = generate_clauses(opts)

    """
    CREATE TABLE `#{table_name}` (
    #{columns}
    )#{clauses}
    """
    |> String.trim()
  end

  defp generate_columns(%Raggio.Schema{type: :struct, fields: fields}) do
    fields
    |> Enum.map(fn {name, field_schema} ->
      column_def(name, field_schema)
    end)
    |> Enum.join(",\n")
    |> indent(2)
  end

  defp generate_columns(_schema) do
    raise ArgumentError, "Schema must be a struct type for table definition"
  end

  defp column_def(name, %Raggio.Schema{} = schema) do
    type_str = map_type(schema)
    mode = if required?(schema), do: " NOT NULL", else: ""
    default = default_clause(schema)

    "#{name} #{type_str}#{mode}#{default}"
  end

  defp map_type(%Raggio.Schema{type: :string}), do: "STRING"
  defp map_type(%Raggio.Schema{type: :integer}), do: "INT64"
  defp map_type(%Raggio.Schema{type: :float}), do: "FLOAT64"
  defp map_type(%Raggio.Schema{type: :boolean}), do: "BOOL"
  defp map_type(%Raggio.Schema{type: :decimal}), do: "NUMERIC"
  defp map_type(%Raggio.Schema{type: :datetime}), do: "DATETIME"
  defp map_type(%Raggio.Schema{type: :date}), do: "DATE"
  defp map_type(%Raggio.Schema{type: :atom}), do: "STRING"

  defp map_type(%Raggio.Schema{type: :array, fields: [element: element_schema]}) do
    "ARRAY<#{map_type(element_schema)}>"
  end

  defp map_type(%Raggio.Schema{type: :struct, fields: fields}) do
    field_defs =
      Enum.map(fields, fn {name, field_schema} ->
        type_str = map_type(field_schema)
        mode = if required?(field_schema), do: " NOT NULL", else: ""
        "#{name} #{type_str}#{mode}"
      end)

    "STRUCT<#{Enum.join(field_defs, ", ")}>"
  end

  defp map_type(%Raggio.Schema{type: type}) do
    raise ArgumentError, "Unsupported type for BigQuery: #{inspect(type)}"
  end

  defp required?(%Raggio.Schema{optional: false}), do: true
  defp required?(%Raggio.Schema{optional: true}), do: false

  defp default_clause(%Raggio.Schema{default: nil}), do: ""

  defp default_clause(%Raggio.Schema{default: value}) when is_binary(value) do
    " DEFAULT '#{value}'"
  end

  defp default_clause(%Raggio.Schema{default: value}) when is_number(value) do
    " DEFAULT #{value}"
  end

  defp default_clause(%Raggio.Schema{default: true}), do: " DEFAULT TRUE"
  defp default_clause(%Raggio.Schema{default: false}), do: " DEFAULT FALSE"
  defp default_clause(_), do: ""

  defp generate_clauses(opts) do
    partition = Keyword.get(opts, :partition_by)
    cluster = Keyword.get(opts, :cluster_by)

    clauses = []
    clauses = if partition, do: clauses ++ ["PARTITION BY #{partition}"], else: clauses

    clauses =
      if cluster && length(cluster) > 0,
        do: clauses ++ ["CLUSTER BY #{Enum.join(cluster, ", ")}"],
        else: clauses

    if Enum.empty?(clauses) do
      ""
    else
      "\n" <> Enum.join(clauses, "\n")
    end
  end

  defp indent(text, spaces) do
    padding = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map(&(padding <> &1))
    |> Enum.join("\n")
  end
end
