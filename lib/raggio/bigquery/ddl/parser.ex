defmodule Raggio.BigQuery.DDL.Parser do
  @moduledoc """
  Parse BigQuery CREATE TABLE DDL into raggio schema definitions.

  This parser uses a combination of NimbleParsec for lexing and manual
  recursive descent for complex nested types.

  ## Usage

      {:ok, parsed} = Parser.parse_create_table(ddl_string)
      {:ok, table_def} = Parser.to_table_def(parsed)

  ## Supported DDL Features

  - Simple and qualified table names
  - All BigQuery scalar types (STRING, INT64, FLOAT64, BOOL, etc.)
  - ARRAY and STRUCT types with nesting
  - NOT NULL constraints
  - PARTITION BY (DATE, TIMESTAMP_TRUNC, _PARTITIONDATE)
  - CLUSTER BY
  - OPTIONS (description)
  - IF NOT EXISTS
  """

  alias Raggio.BigQuery.{TableDef, Column}
  alias Raggio.Schema.Type

  # ===========================================================================
  # Type Mappings
  # ===========================================================================

  @type_mapping %{
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

  @simple_types Map.keys(@type_mapping)

  # ===========================================================================
  # Public API
  # ===========================================================================

  @doc """
  Parse a BigQuery type string into a Type struct.

  ## Examples

      iex> Parser.parse_type("STRING")
      {:ok, %Type{kind: :string}}

      iex> Parser.parse_type("ARRAY<STRING>")
      {:ok, %Type{kind: :list, inner: %Type{kind: :string}}}
  """
  @spec parse_type(String.t()) :: {:ok, Type.t()} | {:error, String.t()}
  def parse_type(type_str) do
    type_str = String.trim(type_str)

    case parse_data_type(type_str) do
      {:ok, type, ""} -> {:ok, type}
      {:ok, _type, rest} -> {:error, "Unexpected trailing content: #{rest}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parse a BigQuery CREATE TABLE statement.

  ## Returns

  A map with:
  - `:table_name` - The table name
  - `:dataset` - The dataset name (if qualified)
  - `:project` - The project name (if fully qualified)
  - `:columns` - List of column definitions
  - `:partition_by` - Partition configuration (if present)
  - `:cluster_by` - List of clustering columns (if present)
  - `:options` - Map of table options (if present)
  - `:if_not_exists` - Boolean (if IF NOT EXISTS was specified)
  """
  @spec parse_create_table(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_create_table(ddl) do
    ddl = String.trim(ddl)

    with {:ok, rest, if_not_exists} <- parse_create_table_header(ddl),
         {:ok, rest, table_name} <- parse_table_name(rest),
         {:ok, rest, columns} <- parse_column_list(rest),
         {:ok, rest, partition_by} <- parse_partition_clause(rest),
         {:ok, rest, cluster_by} <- parse_cluster_clause(rest),
         {:ok, _rest, options} <- parse_options_clause(rest) do
      {project, dataset, table} = parse_qualified_name(table_name)

      {:ok,
       %{
         table_name: table,
         dataset: dataset,
         project: project,
         columns: columns,
         partition_by: partition_by,
         cluster_by: cluster_by,
         options: options,
         if_not_exists: if_not_exists
       }}
    end
  end

  @doc """
  Convert parsed DDL result to a TableDef struct.
  """
  @spec to_table_def(map()) :: {:ok, TableDef.t()} | {:error, String.t()}
  def to_table_def(parsed) when is_map(parsed) do
    columns =
      parsed.columns
      |> Enum.map(fn {name, type, mode} ->
        %Column{
          name: String.to_atom(name),
          type: type,
          mode: mode
        }
      end)

    partition_by = convert_partition_by(parsed[:partition_by])
    cluster_by = convert_cluster_by(parsed[:cluster_by])

    table_def = %TableDef{
      name: parsed.table_name,
      columns: columns,
      partition_by: partition_by,
      cluster_by: cluster_by,
      description: get_in(parsed, [:options, :description])
    }

    {:ok, table_def}
  end

  @doc """
  Convert parsed type to Schema.Type.
  """
  @spec to_schema_type(any()) :: Type.t()
  def to_schema_type(parsed_type), do: parsed_type

  # ===========================================================================
  # Parser Implementation
  # ===========================================================================

  defp parse_create_table_header(input) do
    input = skip_whitespace(input)

    with {:ok, rest} <- expect_keyword(input, "CREATE"),
         rest <- skip_whitespace(rest),
         {:ok, rest} <- expect_keyword(rest, "TABLE"),
         rest <- skip_whitespace(rest) do
      # Check for IF NOT EXISTS
      case try_keyword(rest, "IF") do
        {:ok, rest} ->
          rest = skip_whitespace(rest)

          with {:ok, rest} <- expect_keyword(rest, "NOT"),
               rest <- skip_whitespace(rest),
               {:ok, rest} <- expect_keyword(rest, "EXISTS") do
            {:ok, skip_whitespace(rest), true}
          end

        :no_match ->
          {:ok, rest, false}
      end
    end
  end

  defp parse_table_name(input) do
    input = skip_whitespace(input)

    case input do
      "`" <> rest ->
        # Quoted identifier
        case String.split(rest, "`", parts: 2) do
          [name, rest] -> {:ok, skip_whitespace(rest), name}
          _ -> {:error, "Unterminated quoted identifier"}
        end

      _ ->
        # Unquoted identifier (may be qualified with dots: project.dataset.table)
        {name, rest} = take_qualified_identifier(input)

        if name == "" do
          {:error, "Expected table name"}
        else
          {:ok, skip_whitespace(rest), name}
        end
    end
  end

  defp parse_column_list(input) do
    input = skip_whitespace(input)

    case input do
      "(" <> rest ->
        parse_columns(skip_whitespace(rest), [])

      _ ->
        {:error, "Expected '(' to start column list"}
    end
  end

  defp parse_columns(input, acc) do
    input = skip_whitespace(input)

    case input do
      ")" <> rest ->
        {:ok, skip_whitespace(rest), Enum.reverse(acc)}

      _ ->
        with {:ok, rest, column} <- parse_column_def(input) do
          rest = skip_whitespace(rest)

          case rest do
            "," <> rest ->
              parse_columns(skip_whitespace(rest), [column | acc])

            ")" <> rest ->
              {:ok, skip_whitespace(rest), Enum.reverse([column | acc])}

            _ ->
              {:error,
               "Expected ',' or ')' after column definition, got: #{String.slice(rest, 0, 20)}"}
          end
        end
    end
  end

  defp parse_column_def(input) do
    {name, rest} = take_identifier(input)

    if name == "" do
      {:error, "Expected column name"}
    else
      rest = skip_whitespace(rest)

      with {:ok, type, rest} <- parse_data_type(rest) do
        rest = skip_whitespace(rest)

        # Check for NOT NULL
        {mode, rest} =
          case try_keyword(rest, "NOT") do
            {:ok, rest} ->
              rest = skip_whitespace(rest)

              case expect_keyword(rest, "NULL") do
                {:ok, rest} -> {:required, rest}
                _ -> {:nullable, rest}
              end

            :no_match ->
              {:nullable, rest}
          end

        {:ok, rest, {name, type, mode}}
      end
    end
  end

  defp parse_data_type(input) do
    input = skip_whitespace(input)
    {type_name, rest} = take_identifier(input)
    type_upper = String.upcase(type_name)

    cond do
      type_upper == "ARRAY" ->
        parse_array_type(rest)

      type_upper == "STRUCT" ->
        parse_struct_type(rest)

      type_upper in @simple_types ->
        kind = Map.get(@type_mapping, type_upper)
        {:ok, %Type{kind: kind}, rest}

      type_name == "" ->
        {:error, "Expected type name"}

      true ->
        {:error, "Unknown type: #{type_name}"}
    end
  end

  defp parse_array_type(input) do
    input = skip_whitespace(input)

    case input do
      "<" <> rest ->
        rest = skip_whitespace(rest)

        with {:ok, inner_type, rest} <- parse_data_type(rest) do
          rest = skip_whitespace(rest)

          case rest do
            ">" <> rest ->
              {:ok, %Type{kind: :list, inner: inner_type}, rest}

            _ ->
              {:error, "Expected '>' to close ARRAY type"}
          end
        end

      _ ->
        {:error, "Expected '<' after ARRAY"}
    end
  end

  defp parse_struct_type(input) do
    input = skip_whitespace(input)

    case input do
      "<" <> rest ->
        parse_struct_fields(skip_whitespace(rest), [])

      _ ->
        {:error, "Expected '<' after STRUCT"}
    end
  end

  defp parse_struct_fields(input, acc) do
    input = skip_whitespace(input)

    case input do
      ">" <> rest ->
        {:ok, %Type{kind: :struct, fields: Enum.reverse(acc)}, rest}

      _ ->
        {name, rest} = take_identifier(input)

        if name == "" do
          {:error, "Expected field name in STRUCT"}
        else
          rest = skip_whitespace(rest)

          with {:ok, type, rest} <- parse_data_type(rest) do
            rest = skip_whitespace(rest)
            field = {String.to_atom(name), type}

            case rest do
              "," <> rest ->
                parse_struct_fields(skip_whitespace(rest), [field | acc])

              ">" <> rest ->
                {:ok, %Type{kind: :struct, fields: Enum.reverse([field | acc])}, rest}

              _ ->
                {:error, "Expected ',' or '>' in STRUCT definition"}
            end
          end
        end
    end
  end

  defp parse_partition_clause(input) do
    input = skip_whitespace(input)

    case try_keyword(input, "PARTITION") do
      {:ok, rest} ->
        rest = skip_whitespace(rest)

        with {:ok, rest} <- expect_keyword(rest, "BY") do
          rest = skip_whitespace(rest)
          parse_partition_expr(rest)
        end

      :no_match ->
        {:ok, input, nil}
    end
  end

  defp parse_partition_expr(input) do
    cond do
      String.starts_with?(input, "_PARTITIONDATE") ->
        rest = String.slice(input, 14..-1//1)
        {:ok, skip_whitespace(rest), %{type: :ingestion_time, granularity: :day}}

      true ->
        {func_name, rest} = take_identifier(input)
        func_upper = String.upcase(func_name)
        rest = skip_whitespace(rest)

        case rest do
          "(" <> rest ->
            rest = skip_whitespace(rest)
            {col_name, rest} = take_identifier(rest)
            rest = skip_whitespace(rest)

            case func_upper do
              "DATE" ->
                case rest do
                  ")" <> rest ->
                    {:ok, skip_whitespace(rest),
                     %{type: :date, column: col_name, granularity: :day}}

                  _ ->
                    {:error, "Expected ')' after DATE(column)"}
                end

              func when func in ["TIMESTAMP_TRUNC", "DATE_TRUNC"] ->
                case rest do
                  "," <> rest ->
                    rest = skip_whitespace(rest)
                    {granularity, rest} = take_identifier(rest)
                    rest = skip_whitespace(rest)

                    case rest do
                      ")" <> rest ->
                        type = if func == "TIMESTAMP_TRUNC", do: :timestamp, else: :date_trunc
                        gran = parse_granularity(granularity)

                        {:ok, skip_whitespace(rest),
                         %{type: type, column: col_name, granularity: gran}}

                      _ ->
                        {:error, "Expected ')' after #{func}(column, granularity)"}
                    end

                  _ ->
                    {:error, "Expected ',' in #{func}"}
                end

              _ ->
                {:error, "Unknown partition function: #{func_name}"}
            end

          _ ->
            {:error, "Expected '(' after partition function"}
        end
    end
  end

  defp parse_cluster_clause(input) do
    input = skip_whitespace(input)

    case try_keyword(input, "CLUSTER") do
      {:ok, rest} ->
        rest = skip_whitespace(rest)

        with {:ok, rest} <- expect_keyword(rest, "BY") do
          rest = skip_whitespace(rest)
          parse_identifier_list(rest, [])
        end

      :no_match ->
        {:ok, input, nil}
    end
  end

  defp parse_identifier_list(input, acc) do
    {name, rest} = take_identifier(input)

    if name == "" do
      {:ok, input, Enum.reverse(acc)}
    else
      rest = skip_whitespace(rest)

      case rest do
        "," <> rest ->
          parse_identifier_list(skip_whitespace(rest), [name | acc])

        _ ->
          {:ok, rest, Enum.reverse([name | acc])}
      end
    end
  end

  defp parse_options_clause(input) do
    input = skip_whitespace(input)

    case try_keyword(input, "OPTIONS") do
      {:ok, rest} ->
        rest = skip_whitespace(rest)

        case rest do
          "(" <> rest ->
            parse_options(skip_whitespace(rest), %{})

          _ ->
            {:error, "Expected '(' after OPTIONS"}
        end

      :no_match ->
        {:ok, input, %{}}
    end
  end

  defp parse_options(input, acc) do
    input = skip_whitespace(input)

    case input do
      ")" <> rest ->
        {:ok, skip_whitespace(rest), acc}

      _ ->
        {key, rest} = take_identifier(input)

        if key == "" do
          {:ok, input, acc}
        else
          rest = skip_whitespace(rest)

          case rest do
            "=" <> rest ->
              rest = skip_whitespace(rest)

              case parse_string_literal(rest) do
                {:ok, value, rest} ->
                  rest = skip_whitespace(rest)
                  acc = Map.put(acc, String.to_atom(key), value)

                  case rest do
                    "," <> rest -> parse_options(skip_whitespace(rest), acc)
                    ")" <> rest -> {:ok, skip_whitespace(rest), acc}
                    _ -> {:error, "Expected ',' or ')' in OPTIONS"}
                  end

                {:error, reason} ->
                  {:error, reason}
              end

            _ ->
              {:error, "Expected '=' after option key"}
          end
        end
    end
  end

  defp parse_string_literal(input) do
    case input do
      "\"" <> rest ->
        parse_string_content(rest, [])

      _ ->
        {:error, "Expected '\"' to start string literal"}
    end
  end

  defp parse_string_content("", _acc), do: {:error, "Unterminated string literal"}

  defp parse_string_content("\\\"" <> rest, acc) do
    parse_string_content(rest, [?" | acc])
  end

  defp parse_string_content("\\\\" <> rest, acc) do
    parse_string_content(rest, [?\\ | acc])
  end

  defp parse_string_content("\"" <> rest, acc) do
    {:ok, acc |> Enum.reverse() |> List.to_string(), rest}
  end

  defp parse_string_content(<<char::utf8, rest::binary>>, acc) do
    parse_string_content(rest, [char | acc])
  end

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

  defp skip_whitespace(input) do
    input
    |> String.trim_leading()
  end

  defp take_identifier(input) do
    case Regex.run(~r/^([a-zA-Z_][a-zA-Z0-9_]*)/, input) do
      [match, name] ->
        rest = String.slice(input, String.length(match)..-1//1)
        {name, rest}

      _ ->
        {"", input}
    end
  end

  defp take_qualified_identifier(input) do
    # Match qualified name: identifier.identifier.identifier (project.dataset.table)
    case Regex.run(~r/^([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*)/, input) do
      [match, name] ->
        rest = String.slice(input, String.length(match)..-1//1)
        {name, rest}

      _ ->
        {"", input}
    end
  end

  defp expect_keyword(input, keyword) do
    input_upper = String.upcase(String.slice(input, 0, String.length(keyword)))

    if input_upper == String.upcase(keyword) do
      rest = String.slice(input, String.length(keyword)..-1//1)

      # Make sure keyword is followed by non-word character
      if rest == "" or not Regex.match?(~r/^[a-zA-Z0-9_]/, rest) do
        {:ok, rest}
      else
        {:error, "Expected keyword #{keyword}"}
      end
    else
      {:error, "Expected keyword #{keyword}, got: #{String.slice(input, 0, 20)}"}
    end
  end

  defp try_keyword(input, keyword) do
    case expect_keyword(input, keyword) do
      {:ok, rest} -> {:ok, rest}
      {:error, _} -> :no_match
    end
  end

  defp parse_qualified_name(name) do
    parts = String.split(name, ".")

    case parts do
      [table] -> {nil, nil, table}
      [dataset, table] -> {nil, dataset, table}
      [project, dataset, table] -> {project, dataset, table}
      _ -> {nil, nil, name}
    end
  end

  defp parse_granularity(g) when is_binary(g) do
    case String.upcase(g) do
      "HOUR" -> :hour
      "DAY" -> :day
      "MONTH" -> :month
      "YEAR" -> :year
      _ -> :day
    end
  end

  defp convert_partition_by(nil), do: nil

  defp convert_partition_by(%{type: :ingestion_time, granularity: g}) do
    {:ingestion_time, g}
  end

  defp convert_partition_by(%{type: :date, column: col, granularity: g}) do
    {:field, String.to_atom(col), g}
  end

  defp convert_partition_by(%{type: :timestamp, column: col, granularity: g}) do
    {:field, String.to_atom(col), g}
  end

  defp convert_partition_by(%{type: :date_trunc, column: col, granularity: g}) do
    {:field, String.to_atom(col), g}
  end

  defp convert_partition_by(_), do: nil

  defp convert_cluster_by(nil), do: nil
  defp convert_cluster_by([]), do: nil

  defp convert_cluster_by(columns) when is_list(columns) do
    Enum.map(columns, &String.to_atom/1)
  end
end
