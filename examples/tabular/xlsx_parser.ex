defmodule Examples.Tabular.XLSXParser do
  @moduledoc """
  Example XLSX parser implementing `Raggio.Tabular.Parser` behaviour.

  This is a reference implementation using XlsxReader. Copy and adapt
  for your own needs, or use as-is for development/testing.

  ## Setup

  Add to your mix.exs:

      {:xlsx_reader, "~> 0.8"}

  ## Usage

      Raggio.Tabular.parse("data.xlsx", schema, parser: Examples.Tabular.XLSXParser)

      # With specific sheet
      Raggio.Tabular.parse("data.xlsx", schema,
        parser: Examples.Tabular.XLSXParser,
        sheet: "Sheet2"
      )

  ## Options

  - `:sheet` - Sheet name to read (default: first sheet)
  """

  @behaviour Raggio.Tabular.Parser

  @impl Raggio.Tabular.Parser
  def sheet_names(path) when is_binary(path) do
    with :ok <- check_file_exists(path),
         {:ok, package} <- open_package(path) do
      {:ok, XlsxReader.sheet_names(package)}
    end
  end

  @impl Raggio.Tabular.Parser
  def stream_rows(path, opts) when is_binary(path) do
    sheet_name = Keyword.get(opts, :sheet, nil)

    with :ok <- check_file_exists(path),
         {:ok, package} <- open_package(path),
         {:ok, resolved_sheet} <- resolve_sheet(package, sheet_name) do
      stream = build_row_stream(package, resolved_sheet)
      {:ok, stream}
    end
  end

  defp check_file_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, %{type: :file_not_found, message: "File not found: #{path}"}}
    end
  end

  defp open_package(path) do
    case XlsxReader.open(path) do
      {:ok, package} ->
        {:ok, package}

      {:error, reason} ->
        {:error, %{type: :invalid_format, message: "Failed to open XLSX: #{inspect(reason)}"}}
    end
  end

  defp resolve_sheet(package, nil) do
    case XlsxReader.sheet_names(package) do
      [first | _] -> {:ok, first}
      [] -> {:error, %{type: :no_sheets, message: "Workbook has no sheets"}}
    end
  end

  defp resolve_sheet(package, sheet_name) when is_binary(sheet_name) do
    sheet_names = XlsxReader.sheet_names(package)
    target_lower = String.downcase(sheet_name)

    case Enum.find(sheet_names, fn name -> String.downcase(name) == target_lower end) do
      nil ->
        available = Enum.join(sheet_names, ", ")

        {:error,
         %{
           type: :sheet_not_found,
           message: "Sheet '#{sheet_name}' not found. Available: #{available}",
           details: %{requested: sheet_name, available: sheet_names}
         }}

      name ->
        {:ok, name}
    end
  end

  defp build_row_stream(package, sheet_name) do
    case XlsxReader.sheet(package, sheet_name) do
      {:ok, rows} ->
        rows
        |> Stream.with_index(1)
        |> Stream.map(fn {row, row_num} ->
          cells = normalize_cells(row)
          {row_num, cells}
        end)

      {:error, _reason} ->
        Stream.map([], & &1)
    end
  end

  defp normalize_cells(row) when is_list(row) do
    Enum.map(row, &normalize_cell/1)
  end

  defp normalize_cell(nil), do: ""
  defp normalize_cell(value) when is_binary(value), do: value
  defp normalize_cell(value) when is_number(value), do: to_string(value)
  defp normalize_cell(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_cell(%Date{} = date), do: Date.to_iso8601(date)
  defp normalize_cell(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize_cell(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp normalize_cell(value), do: inspect(value)
end
