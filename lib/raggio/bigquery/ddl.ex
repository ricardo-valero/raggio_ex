defmodule Raggio.BigQuery.DDL do
  @moduledoc """
  Generates BigQuery DDL (Data Definition Language) statements from Changes.
  """

  alias Raggio.BigQuery.Differ.Change

  @spec generate_up([Change.t()], keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def generate_up(changes, opts \\ []) do
    statements =
      changes
      |> Enum.map(&generate_statement(&1, :up, opts))
      |> Enum.reject(&is_nil/1)

    {:ok, statements}
  end

  @spec generate_down([Change.t()], keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def generate_down(changes, opts \\ []) do
    non_reversible = Enum.find(changes, &(not Change.reversible?(&1)))

    if non_reversible do
      {:error, {:not_reversible, non_reversible}}
    else
      statements =
        changes
        |> Enum.reverse()
        |> Enum.map(&generate_statement(&1, :down, opts))
        |> Enum.reject(&is_nil/1)

      {:ok, statements}
    end
  end

  @spec generate_statement(Change.t(), :up | :down, keyword()) :: String.t() | nil
  def generate_statement(change, direction, opts \\ [])

  def generate_statement(%Change{type: :create_table, table: table, details: details}, :up, opts) do
    fields = Map.get(details, :fields, [])
    project = Keyword.get(opts, :project)

    qualified_table = qualify_table(table, project)
    columns_sql = format_columns(fields)

    "CREATE TABLE IF NOT EXISTS `#{qualified_table}` (\n#{columns_sql}\n)"
  end

  def generate_statement(%Change{type: :create_table, table: table}, :down, opts) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "DROP TABLE IF EXISTS `#{qualified_table}`"
  end

  def generate_statement(%Change{type: :drop_table, table: table}, :up, opts) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "DROP TABLE IF EXISTS `#{qualified_table}`"
  end

  def generate_statement(
        %Change{type: :drop_table, table: table, details: %{schema: fields}},
        :down,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)
    columns_sql = format_columns(fields)

    "CREATE TABLE `#{qualified_table}` (\n#{columns_sql}\n)"
  end

  def generate_statement(%Change{type: :drop_table}, :down, _opts), do: nil

  def generate_statement(
        %Change{type: :add_column, table: table, column: column, details: details},
        :up,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    bq_type = Map.get(details, :bq_type, "STRING")
    mode = Map.get(details, :mode, "NULLABLE")
    description = Map.get(details, :description)

    type_clause = if mode == "REQUIRED", do: "#{bq_type} NOT NULL", else: bq_type

    sql = "ALTER TABLE `#{qualified_table}` ADD COLUMN #{column} #{type_clause}"

    if description do
      "#{sql} OPTIONS(description='#{escape_string(description)}')"
    else
      sql
    end
  end

  def generate_statement(%Change{type: :add_column, table: table, column: column}, :down, opts) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "ALTER TABLE `#{qualified_table}` DROP COLUMN #{column}"
  end

  def generate_statement(%Change{type: :drop_column, table: table, column: column}, :up, opts) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "ALTER TABLE `#{qualified_table}` DROP COLUMN #{column}"
  end

  def generate_statement(
        %Change{type: :drop_column, table: table, column: column, details: details},
        :down,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    bq_type = Map.get(details, :bq_type, "STRING")
    mode = Map.get(details, :mode, "NULLABLE")

    type_clause = if mode == "REQUIRED", do: "#{bq_type} NOT NULL", else: bq_type

    "ALTER TABLE `#{qualified_table}` ADD COLUMN #{column} #{type_clause}"
  end

  def generate_statement(
        %Change{type: :rename_column, table: table, details: %{from: from, to: to}},
        :up,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "ALTER TABLE `#{qualified_table}` RENAME COLUMN #{from} TO #{to}"
  end

  def generate_statement(
        %Change{type: :rename_column, table: table, details: %{from: from, to: to}},
        :down,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "ALTER TABLE `#{qualified_table}` RENAME COLUMN #{to} TO #{from}"
  end

  def generate_statement(
        %Change{type: :change_type, table: table, column: column, details: %{to: to_type}},
        :up,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} SET DATA TYPE #{to_type}"
  end

  def generate_statement(%Change{type: :change_type}, :down, _opts), do: nil

  def generate_statement(
        %Change{type: :change_mode, table: table, column: column, details: %{to: to_mode}},
        :up,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    case to_mode do
      "REQUIRED" ->
        "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} SET NOT NULL"

      "NULLABLE" ->
        "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} DROP NOT NULL"

      _ ->
        nil
    end
  end

  def generate_statement(
        %Change{type: :change_mode, table: table, column: column, details: %{from: from_mode}},
        :down,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    case from_mode do
      "REQUIRED" ->
        "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} SET NOT NULL"

      "NULLABLE" ->
        "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} DROP NOT NULL"

      _ ->
        nil
    end
  end

  def generate_statement(
        %Change{
          type: :change_description,
          table: table,
          column: column,
          details: %{to: description}
        },
        :up,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} SET OPTIONS(description='#{escape_string(description)}')"
  end

  def generate_statement(
        %Change{
          type: :change_description,
          table: table,
          column: column,
          details: %{from: description}
        },
        :down,
        opts
      ) do
    project = Keyword.get(opts, :project)
    qualified_table = qualify_table(table, project)

    if description do
      "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} SET OPTIONS(description='#{escape_string(description)}')"
    else
      "ALTER TABLE `#{qualified_table}` ALTER COLUMN #{column} SET OPTIONS(description=NULL)"
    end
  end

  def generate_statement(_change, _direction, _opts), do: nil

  defp qualify_table(table, nil), do: table
  defp qualify_table(table, project), do: "#{project}.#{table}"

  defp format_columns(fields) do
    Enum.map_join(fields, ",\n", &format_column/1)
  end

  defp format_column(field) do
    name = field["name"]
    type = field["type"]
    mode = field["mode"]
    description = field["description"]

    type_clause =
      case mode do
        "REQUIRED" -> "#{type} NOT NULL"
        "REPEATED" -> "ARRAY<#{type}>"
        _ -> type
      end

    base = "  #{name} #{type_clause}"

    if description do
      "#{base} OPTIONS(description='#{escape_string(description)}')"
    else
      base
    end
  end

  defp escape_string(nil), do: ""

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  @spec join_statements([String.t()], keyword()) :: String.t()
  def join_statements(statements, opts \\ []) do
    separator = Keyword.get(opts, :separator, ";\n\n")

    statements
    |> Enum.join(separator)
    |> Kernel.<>(";")
  end
end
