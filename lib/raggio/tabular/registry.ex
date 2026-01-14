defmodule Raggio.Tabular.Registry do
  @moduledoc """
  Adapter registry for format detection and adapter lookup.

  Automatically detects file format by extension and delegates
  to the appropriate adapter (CSV or XLSX).
  """

  alias Raggio.Tabular.Adapter
  alias Raggio.Tabular.Adapters.{CSV, XLSX}

  @adapters [CSV, XLSX]

  @spec adapter_for(String.t(), keyword()) :: {:ok, module()} | {:error, map()}
  def adapter_for(path, opts \\ []) do
    case Keyword.get(opts, :format) do
      nil -> detect_adapter(path)
      :csv -> {:ok, CSV}
      :xlsx -> {:ok, XLSX}
      format -> {:error, Adapter.format_error(:unsupported_format, "Unknown format: #{format}")}
    end
  end

  defp detect_adapter(path) do
    case Enum.find(@adapters, fn adapter -> adapter.sniff(path) == :ok end) do
      nil ->
        ext = Path.extname(path)

        {:error,
         Adapter.format_error(
           :unsupported_format,
           "Cannot detect format for file: #{path}",
           %{extension: ext, supported: [".csv", ".tsv", ".xlsx", ".xlsm"]}
         )}

      adapter ->
        {:ok, adapter}
    end
  end

  @spec adapters() :: [module()]
  def adapters, do: @adapters
end
