# Contract: Parser Behaviour Interface

**Feature**: `003-sheet-adapter`  
**Updated**: 2026-01-14 (Parser-agnostic architecture)

## Purpose

Define the parser behaviour that **users implement** to support their preferred tabular file formats. The library provides the contract; users supply implementations.

## `Raggio.Tabular.Parser` (behaviour)

### `stream_rows/2`

Stream data rows as `{row_number, row_cells}` tuples.

**Signature**:
```elixir
@callback stream_rows(source :: term(), opts :: keyword()) ::
  {:ok, Enumerable.t({pos_integer(), [term()]})} | {:error, map()}
```

**Parameters**:
- `source`: User-defined source (typically a file path string)
- `opts`: Keyword options including:
  - `sheet: String.t()` - Sheet name to read (for multi-sheet formats)
  - `encoding: atom()` - Character encoding hint
  - Additional parser-specific options

**Rules**:
- MUST stream lazily (must not require loading all rows into memory)
- MUST return `{row_number, cells}` where `row_number` is 1-based
- MUST align row numbering to the original file
- SHOULD apply deterministic blank/ragged row behavior

---

### `sheet_names/1`

List available sheet names for a source.

**Signature**:
```elixir
@callback sheet_names(source :: term()) ::
  {:ok, [String.t()]} | {:error, map()}
```

**Rules**:
- Single-sheet formats (CSV) MUST return `{:ok, ["default"]}`
- Multi-sheet formats (XLSX) MUST return actual sheet names in order
- MUST return `{:error, reason}` if source cannot be read

---

## Error Shape

`reason` MUST be a map with at least:
- `type`: Error type atom (`:file_not_found`, `:invalid_format`, `:sheet_not_found`, etc.)
- `message`: Human-readable string

It MAY include:
- `details`: Additional context map

**Example**:
```elixir
{:error, %{type: :file_not_found, message: "File does not exist: /path/to/file.csv"}}
```

---

## Example Implementation (CSV with NimbleCSV)

```elixir
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
  rescue
    e -> {:error, %{type: :read_error, message: Exception.message(e)}}
  end
end
```

## Example Implementation (XLSX with XlsxReader)

```elixir
defmodule MyApp.XLSXParser do
  @behaviour Raggio.Tabular.Parser

  @impl true
  def sheet_names(path) do
    case XlsxReader.open(path) do
      {:ok, package} -> {:ok, XlsxReader.sheet_names(package)}
      {:error, reason} -> {:error, %{type: :read_error, message: inspect(reason)}}
    end
  end

  @impl true
  def stream_rows(path, opts) do
    sheet = Keyword.get(opts, :sheet, nil)
    
    with {:ok, package} <- XlsxReader.open(path),
         sheet_name <- resolve_sheet(package, sheet),
         {:ok, rows} <- XlsxReader.sheet(package, sheet_name) do
      stream =
        rows
        |> Stream.with_index(1)
        |> Stream.map(fn {cells, row_num} -> {row_num, cells} end)
      
      {:ok, stream}
    end
  end
  
  defp resolve_sheet(package, nil), do: hd(XlsxReader.sheet_names(package))
  defp resolve_sheet(_package, name), do: name
end
```

---

## Migration from Bundled Adapters

Previous versions bundled CSV and XLSX adapters. Users must now:

1. Add their preferred parsing library to `mix.exs`:
   ```elixir
   {:nimble_csv, "~> 1.2"},  # for CSV
   {:xlsx_reader, "~> 0.8"}, # for XLSX
   ```

2. Implement the `Raggio.Tabular.Parser` behaviour (see examples above)

3. Pass the parser module explicitly:
   ```elixir
   Raggio.Tabular.parse(path, schema, parser: MyApp.CSVParser)
   ```
