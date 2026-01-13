defmodule RaggioTabular.Parser do
  @moduledoc """
  CSV parsing with schema validation.
  """

  alias RaggioTabular.SheetSchema
  alias Raggio.Schema

  @type parse_result :: %{
          valid_rows: [map()],
          invalid_rows: [map()],
          errors: [error()],
          total_rows: non_neg_integer()
        }

  @type error :: %{
          row: non_neg_integer(),
          column: atom(),
          message: String.t(),
          value: any()
        }

  @doc """
  Parse CSV file with schema validation.
  """
  def parse_file(path, %SheetSchema{} = schema, opts \\ []) do
    case File.read(path) do
      {:ok, content} -> parse_string(content, schema, opts)
      {:error, reason} -> {:error, {:file_error, reason}}
    end
  end

  @doc """
  Parse CSV content string with schema validation.
  """
  def parse_string(content, %SheetSchema{} = schema, opts \\ []) do
    delimiter = Keyword.get(opts, :delimiter, ",")
    has_header = Keyword.get(opts, :has_header, true)

    lines =
      content
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [] ->
        {:ok, empty_result()}

      [_single] when has_header ->
        {:ok, empty_result()}

      _ ->
        {headers, data_lines} = extract_headers(lines, schema, has_header, delimiter)
        process_data_lines(data_lines, headers, schema, delimiter, opts)
    end
  end

  defp empty_result do
    %{valid_rows: [], invalid_rows: [], errors: [], total_rows: 0}
  end

  defp extract_headers(lines, schema, true, delimiter) do
    [header_line | data_lines] = lines
    raw_headers = parse_line(header_line, delimiter)

    headers =
      Enum.map(raw_headers, fn h ->
        SheetSchema.resolve_header(schema, h) || String.to_atom(h)
      end)

    {headers, data_lines}
  end

  defp extract_headers(lines, schema, false, _delimiter) do
    headers = SheetSchema.column_names(schema)
    {headers, lines}
  end

  defp parse_line(line, delimiter) do
    line
    |> String.split(delimiter)
    |> Enum.map(&String.trim/1)
  end

  defp process_data_lines(lines, headers, schema, delimiter, opts) do
    mode = Keyword.get(opts, :mode, :all_errors)
    {from_row, to_row} = schema.row_range

    indexed_lines =
      lines
      |> Enum.with_index(2)
      |> maybe_filter_rows(from_row, to_row)

    {valid, invalid, errors} =
      Enum.reduce(indexed_lines, {[], [], []}, fn {line, row_num},
                                                  {valid_acc, invalid_acc, errors_acc} ->
        values = parse_line(line, delimiter)
        row_map = build_row_map(headers, values)

        case validate_row(row_map, schema, row_num) do
          {:ok, validated_row} ->
            {[validated_row | valid_acc], invalid_acc, errors_acc}

          {:error, row_errors} when mode == :fail_fast ->
            {valid_acc, [row_map | invalid_acc], row_errors ++ errors_acc}

          {:error, row_errors} ->
            {valid_acc, [row_map | invalid_acc], row_errors ++ errors_acc}
        end
      end)

    {:ok,
     %{
       valid_rows: Enum.reverse(valid),
       invalid_rows: Enum.reverse(invalid),
       errors: Enum.reverse(errors),
       total_rows: length(indexed_lines)
     }}
  end

  defp maybe_filter_rows(indexed_lines, nil, nil), do: indexed_lines

  defp maybe_filter_rows(indexed_lines, from_row, nil) do
    Enum.filter(indexed_lines, fn {_line, row_num} -> row_num >= from_row end)
  end

  defp maybe_filter_rows(indexed_lines, nil, to_row) do
    Enum.filter(indexed_lines, fn {_line, row_num} -> row_num <= to_row end)
  end

  defp maybe_filter_rows(indexed_lines, from_row, to_row) do
    Enum.filter(indexed_lines, fn {_line, row_num} ->
      row_num >= from_row and row_num <= to_row
    end)
  end

  defp build_row_map(headers, values) do
    headers
    |> Enum.zip(values ++ List.duplicate("", max(0, length(headers) - length(values))))
    |> Map.new()
  end

  defp validate_row(row_map, %SheetSchema{columns: columns}, row_num) do
    errors =
      Enum.flat_map(columns, fn {column_name, column_schema} ->
        value = Map.get(row_map, column_name, "")
        coerced_value = coerce_value(value, column_schema)

        case Schema.validate(column_schema, coerced_value) do
          {:ok, _} ->
            []

          {:error, validation_errors} ->
            Enum.map(validation_errors, fn err ->
              %{
                row: row_num,
                column: column_name,
                message: err.message,
                value: value
              }
            end)
        end
      end)

    if Enum.empty?(errors) do
      coerced_row =
        Enum.reduce(columns, row_map, fn {column_name, column_schema}, acc ->
          value = Map.get(acc, column_name, "")
          Map.put(acc, column_name, coerce_value(value, column_schema))
        end)

      {:ok, coerced_row}
    else
      {:error, errors}
    end
  end

  defp coerce_value("", _schema), do: nil

  defp coerce_value(value, %Schema{type: :integer}) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> value
    end
  end

  defp coerce_value(value, %Schema{type: :float}) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> value
    end
  end

  defp coerce_value(value, %Schema{type: :boolean}) when is_binary(value) do
    String.downcase(value) in ["true", "yes", "1", "t", "y"]
  end

  defp coerce_value(value, _schema), do: value
end
