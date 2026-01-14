defmodule Raggio.Tabular.Adapters.CSV do
  @moduledoc """
  CSV adapter implementing the Tabular.Adapter behaviour.

  Supports:
  - Comma, tab, semicolon delimiters (configurable)
  - UTF-8 encoding with BOM detection
  - RFC4180-compatible parsing via NimbleCSV
  - Streaming for large files
  """

  @behaviour Raggio.Tabular.Adapter

  alias Raggio.Tabular.{Adapter, SheetInfo}

  @csv_extensions [".csv", ".tsv", ".txt"]
  @default_delimiter ","
  @bom_utf8 <<0xEF, 0xBB, 0xBF>>

  NimbleCSV.define(CommaParser, separator: ",", escape: "\"")
  NimbleCSV.define(TabParser, separator: "\t", escape: "\"")
  NimbleCSV.define(SemicolonParser, separator: ";", escape: "\"")

  @impl Raggio.Tabular.Adapter
  def sniff(path) when is_binary(path) do
    ext = Path.extname(path) |> String.downcase()

    if ext in @csv_extensions do
      :ok
    else
      :no
    end
  end

  @impl Raggio.Tabular.Adapter
  def list_sheets(path, _opts) do
    if File.exists?(path) do
      {:ok, [SheetInfo.new("CSV", 0)]}
    else
      {:error, Adapter.format_error(:not_found, "File not found: #{path}")}
    end
  end

  @impl Raggio.Tabular.Adapter
  def stream_rows(path, opts) do
    delimiter = Keyword.get(opts, :delimiter, detect_delimiter(path))
    encoding = Keyword.get(opts, :encoding, :utf8)

    cond do
      not File.exists?(path) ->
        {:error, Adapter.format_error(:not_found, "File not found: #{path}")}

      empty_file?(path) ->
        {:error, Adapter.format_error(:format_error, "File is empty: #{path}")}

      true ->
        stream = build_row_stream(path, delimiter, encoding)
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

  defp build_row_stream(path, delimiter, _encoding) do
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

  defp parser_for_delimiter(","), do: CommaParser
  defp parser_for_delimiter("\t"), do: TabParser
  defp parser_for_delimiter(";"), do: SemicolonParser
  defp parser_for_delimiter(_), do: CommaParser

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
