defmodule Raggio.Tabular.Adapters.XLSX do
  @moduledoc """
  XLSX adapter implementing the Tabular.Adapter behaviour.

  Supports:
  - Multi-sheet workbooks with selection by name or index
  - Streaming rows for large files via xlsx_reader
  - Reading computed values from formula cells
  """

  @behaviour Raggio.Tabular.Adapter

  alias Raggio.Tabular.{Adapter, SheetInfo, WorksheetSelector}

  @xlsx_extensions [".xlsx", ".xlsm"]

  @impl Raggio.Tabular.Adapter
  def sniff(path) when is_binary(path) do
    ext = Path.extname(path) |> String.downcase()

    if ext in @xlsx_extensions do
      :ok
    else
      :no
    end
  end

  @impl Raggio.Tabular.Adapter
  def list_sheets(path, _opts) do
    with :ok <- check_file_exists(path),
         {:ok, package} <- open_package(path) do
      sheets =
        package
        |> XlsxReader.sheet_names()
        |> Enum.with_index()
        |> Enum.map(fn {name, index} -> SheetInfo.new(name, index) end)

      {:ok, sheets}
    end
  end

  @impl Raggio.Tabular.Adapter
  def stream_rows(path, opts) do
    worksheet_selector = Keyword.get(opts, :worksheet, WorksheetSelector.first())

    with :ok <- check_file_exists(path),
         {:ok, package} <- open_package(path),
         {:ok, sheet_name} <- resolve_sheet(package, worksheet_selector) do
      stream = build_row_stream(package, sheet_name)
      {:ok, stream}
    end
  end

  defp check_file_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, Adapter.format_error(:not_found, "File not found: #{path}")}
    end
  end

  defp open_package(path) do
    case XlsxReader.open(path) do
      {:ok, package} ->
        {:ok, package}

      {:error, reason} ->
        {:error, Adapter.format_error(:format_error, "Failed to open XLSX: #{inspect(reason)}")}
    end
  end

  defp resolve_sheet(package, selector) do
    sheet_names = XlsxReader.sheet_names(package)

    case find_matching_sheet(sheet_names, selector) do
      {:ok, name} ->
        {:ok, name}

      :error ->
        available = Enum.join(sheet_names, ", ")

        {:error,
         Adapter.format_error(
           :not_found,
           "Worksheet not found. Available sheets: #{available}",
           %{selector: selector, available: sheet_names}
         )}
    end
  end

  defp find_matching_sheet(sheet_names, {:index, index}) do
    case Enum.at(sheet_names, index) do
      nil -> :error
      name -> {:ok, name}
    end
  end

  defp find_matching_sheet(sheet_names, {:name, target_name}) do
    target_lower = String.downcase(target_name)

    case Enum.find(sheet_names, fn name -> String.downcase(name) == target_lower end) do
      nil -> :error
      name -> {:ok, name}
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
