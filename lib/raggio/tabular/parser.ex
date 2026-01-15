defmodule Raggio.Tabular.Parser do
  @moduledoc """
  Behaviour for tabular file parsers.

  Implement this behaviour to add support for new file formats.
  The library ships with no bundled implementations - users must
  provide their own or use the examples in `examples/tabular/`.

  ## Callbacks

  - `stream_rows/2` - Stream rows as `{row_number, cells}` tuples
  - `sheet_names/1` - List available sheet names

  ## Example Implementation

      defmodule MyApp.CSVParser do
        @behaviour Raggio.Tabular.Parser

        @impl true
        def sheet_names(_source), do: {:ok, ["default"]}

        @impl true
        def stream_rows(path, opts) do
          delimiter = Keyword.get(opts, :delimiter, ",")

          stream =
            path
            |> File.stream!()
            |> NimbleCSV.RFC4180.parse_stream()
            |> Stream.with_index(1)
            |> Stream.map(fn {cells, row_num} -> {row_num, cells} end)

          {:ok, stream}
        end
      end

  ## Usage

      Raggio.Tabular.parse("data.csv", schema, parser: MyApp.CSVParser)

  See `examples/tabular/` for complete reference implementations.
  """

  @type source :: term()
  @type opts :: keyword()
  @type row_stream :: Enumerable.t({pos_integer(), [term()]})
  @type error_reason :: map()

  @doc """
  Stream rows from a tabular source.

  Returns a stream of `{row_number, cells}` tuples where:
  - `row_number` is 1-based and corresponds to the original file position
  - `cells` is a list of cell values (typically strings)

  ## Options

  Common options passed by the library:
  - `:sheet` - Sheet name for multi-sheet formats (default: first sheet)

  Parser implementations may accept additional format-specific options.

  ## Streaming Requirements

  The returned stream MUST:
  - Be lazy (not load entire file into memory)
  - Return tuples of `{pos_integer(), [term()]}`
  - Use 1-based row numbering matching the original file

  ## Error Handling

  Return `{:error, reason}` with a map containing at least:
  - `:type` - Error type atom (e.g., `:file_not_found`, `:invalid_format`)
  - `:message` - Human-readable error message
  """
  @callback stream_rows(source(), opts()) ::
              {:ok, row_stream()} | {:error, error_reason()}

  @doc """
  List available sheet names for a source.

  For single-sheet formats (like CSV), return `{:ok, ["default"]}`.
  For multi-sheet formats (like XLSX), return actual sheet names in order.

  ## Error Handling

  Return `{:error, reason}` if the source cannot be read.
  """
  @callback sheet_names(source()) ::
              {:ok, [String.t()]} | {:error, error_reason()}
end
