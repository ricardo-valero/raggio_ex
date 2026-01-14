defmodule Raggio.Tabular.Adapter do
  @moduledoc """
  Behaviour for tabular file format adapters.

  Adapters isolate format-specific reading (CSV, XLSX) from
  schema-based row parsing. Each adapter must implement:

  - `sniff/1` - Determine if this adapter handles the source
  - `list_sheets/2` - List available worksheets
  - `stream_rows/2` - Stream rows as `{row_number, cells}` tuples
  """

  alias Raggio.Tabular.SheetInfo

  @type source :: String.t()
  @type opts :: keyword()
  @type row_stream :: Enumerable.t()
  @type reason :: map()

  @callback sniff(source()) :: :ok | :no

  @callback list_sheets(source(), opts()) :: {:ok, [SheetInfo.t()]} | {:error, reason()}

  @callback stream_rows(source(), opts()) :: {:ok, row_stream()} | {:error, reason()}

  @spec format_error(atom(), String.t(), map()) :: map()
  def format_error(type, message, details \\ %{}) do
    %{type: type, message: message, details: details}
  end
end
