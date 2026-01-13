defmodule RaggioTabular.Adapter do
  @moduledoc """
  Batch processing adapter for tabular data.
  """

  alias RaggioTabular.SheetSchema
  alias Raggio.Schema

  @default_batch_size 1000

  @type batch_result :: %{
          valid_rows: [map()],
          invalid_rows: [map()],
          error_details: [error_detail()],
          processed_count: non_neg_integer()
        }

  @type error_detail :: %{
          row_index: non_neg_integer(),
          column: atom(),
          message: String.t(),
          value: any()
        }

  @type process_option ::
          {:batch_size, pos_integer()}
          | {:on_progress, (non_neg_integer(), non_neg_integer() -> any())}
          | {:mode, :fail_fast | :collect_all}

  @doc """
  Process rows in batches with configurable batch size.
  """
  def process_batch(rows, %SheetSchema{} = schema, opts \\ []) when is_list(rows) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    on_progress = Keyword.get(opts, :on_progress)
    mode = Keyword.get(opts, :mode, :collect_all)

    total_rows = length(rows)

    result =
      rows
      |> Enum.with_index()
      |> Enum.chunk_every(batch_size)
      |> Enum.reduce(
        %{valid_rows: [], invalid_rows: [], error_details: [], processed_count: 0},
        fn batch, acc ->
          batch_result = process_single_batch(batch, schema, mode)

          new_acc = %{
            valid_rows: acc.valid_rows ++ batch_result.valid_rows,
            invalid_rows: acc.invalid_rows ++ batch_result.invalid_rows,
            error_details: acc.error_details ++ batch_result.error_details,
            processed_count: acc.processed_count + length(batch)
          }

          if on_progress do
            on_progress.(new_acc.processed_count, total_rows)
          end

          if mode == :fail_fast and length(batch_result.error_details) > 0 do
            throw({:halt, new_acc})
          end

          new_acc
        end
      )

    {:ok, result}
  catch
    {:halt, result} -> {:ok, result}
  end

  defp process_single_batch(indexed_rows, %SheetSchema{columns: columns}, mode) do
    Enum.reduce(indexed_rows, %{valid_rows: [], invalid_rows: [], error_details: []}, fn {row,
                                                                                          index},
                                                                                         acc ->
      errors = validate_row_against_schema(row, columns, index)

      if Enum.empty?(errors) do
        %{acc | valid_rows: acc.valid_rows ++ [row]}
      else
        if mode == :fail_fast do
          %{acc | invalid_rows: acc.invalid_rows ++ [row], error_details: errors}
        else
          %{
            acc
            | invalid_rows: acc.invalid_rows ++ [row],
              error_details: acc.error_details ++ errors
          }
        end
      end
    end)
  end

  defp validate_row_against_schema(row, columns, row_index) do
    Enum.flat_map(columns, fn {column_name, column_schema} ->
      value = Map.get(row, column_name)

      case Schema.validate(column_schema, value) do
        {:ok, _} ->
          []

        {:error, validation_errors} ->
          Enum.map(validation_errors, fn err ->
            %{
              row_index: row_index,
              column: column_name,
              message: err.message,
              value: value
            }
          end)
      end
    end)
  end

  @doc """
  Stream rows from a file, processing in batches.
  """
  def stream_process(path, %SheetSchema{} = schema, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    on_batch = Keyword.get(opts, :on_batch, fn _batch_result -> :ok end)

    File.stream!(path)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.drop(1)
    |> Stream.chunk_every(batch_size)
    |> Stream.each(fn batch ->
      rows = Enum.map(batch, &parse_csv_line/1)
      {:ok, result} = process_batch(rows, schema, opts)
      on_batch.(result)
    end)
    |> Stream.run()
  end

  defp parse_csv_line(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.with_index()
    |> Map.new(fn {value, index} -> {:"col_#{index}", value} end)
  end
end
