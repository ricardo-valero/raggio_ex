defmodule Examples.Tabular.CSVParser do
  @moduledoc """
  Example CSV parser implementing `Raggio.Tabular.Parser` behaviour.

  This is a reference implementation using NimbleCSV. Copy and adapt
  for your own needs, or use as-is for development/testing.

  ## Setup

  Add to your mix.exs:

      {:nimble_csv, "~> 1.2"}

  ## Usage

      Raggio.Tabular.parse("data.csv", schema, parser: Examples.Tabular.CSVParser)

  ## Options

  - `:delimiter` - Field delimiter (default: ","). Use "\\t" for TSV.
  - `:encoding` - Character encoding hint (default: :utf8)
  """

  @behaviour Raggio.Tabular.Parser

  @csv_extensions [".csv", ".tsv", ".txt"]
  @default_delimiter ","
  @bom_utf8 <<0xEF, 0xBB, 0xBF>>

  NimbleCSV.define(__MODULE__.CommaParser, separator: ",", escape: "\"")
  NimbleCSV.define(__MODULE__.TabParser, separator: "\t", escape: "\"")
  NimbleCSV.define(__MODULE__.SemicolonParser, separator: ";", escape: "\"")

  @impl Raggio.Tabular.Parser
  def sheet_names(path) when is_binary(path) do
    if File.exists?(path) do
      {:ok, ["default"]}
    else
      {:error, %{type: :file_not_found, message: "File not found: #{path}"}}
    end
  end

  @impl Raggio.Tabular.Parser
  def stream_rows(path, opts) when is_binary(path) do
    delimiter = Keyword.get(opts, :delimiter, detect_delimiter(path))

    cond do
      not File.exists?(path) ->
        {:error, %{type: :file_not_found, message: "File not found: #{path}"}}

      empty_file?(path) ->
        {:error, %{type: :empty_file, message: "File is empty: #{path}"}}

      true ->
        stream = build_row_stream(path, delimiter)
        {:ok, stream}
    end
  end

  defp detect_delimiter(path) do
    case Path.extname(path) |> String.downcase() do
      ".tsv" -> "\t"
      _ -> @default_delimiter
    end
  end

  defp empty_file?(path) do
    case File.stat(path) do
      {:ok, %{size: 0}} -> true
      {:ok, _} -> false
      {:error, _} -> true
    end
  end

  defp build_row_stream(path, delimiter) do
    parser = parser_for_delimiter(delimiter)

    path
    |> File.stream!(read_ahead: 100_000)
    |> Stream.transform({1, true}, fn line, {row_num, is_first} ->
      line = if is_first, do: strip_bom(line), else: line
      {[{row_num, line}], {row_num + 1, false}}
    end)
    |> Stream.flat_map(fn {row_num, line} ->
      case parse_line(parser, line) do
        {:ok, cells} ->
          copied_cells = Enum.map(cells, &:binary.copy/1)
          [{row_num, copied_cells}]

        {:error, _} ->
          []
      end
    end)
  end

  defp parser_for_delimiter(","), do: __MODULE__.CommaParser
  defp parser_for_delimiter("\t"), do: __MODULE__.TabParser
  defp parser_for_delimiter(";"), do: __MODULE__.SemicolonParser
  defp parser_for_delimiter(_), do: __MODULE__.CommaParser

  defp strip_bom(<<@bom_utf8, rest::binary>>), do: rest
  defp strip_bom(line), do: line

  defp parse_line(parser, line) do
    try do
      case parser.parse_string(line, skip_headers: false) do
        [row] -> {:ok, row}
        [] -> {:ok, []}
        rows when is_list(rows) -> {:ok, List.first(rows)}
      end
    rescue
      _ -> {:error, :parse_error}
    end
  end
end
