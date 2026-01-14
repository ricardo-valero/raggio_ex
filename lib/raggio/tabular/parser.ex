defmodule Raggio.Tabular.Parser do
  @moduledoc """
  Parser for converting raw row streams into typed results.

  Handles:
  - Header detection and column mapping
  - Row parsing with Raggio.Schema validation
  - Row-numbered error accumulation
  - Blank row skipping and ragged row handling
  """

  alias Raggio.Tabular.{ColumnDef, Error, Result, SheetSchema, Transform, Union}

  @type row_stream :: Enumerable.t()
  @type schema_or_union :: SheetSchema.t() | Union.t()

  @spec parse(row_stream(), schema_or_union(), keyword()) :: {:ok, Result.t()} | {:error, map()}
  def parse(stream, %Union{} = union, opts) do
    parse_with_union(stream, union, opts)
  end

  def parse(stream, %SheetSchema{} = schema, opts) do
    parse_with_schema(stream, schema, opts)
  end

  defp parse_with_union(stream, %Union{schemas: schemas, strategy: strategy}, opts) do
    rows_list = Enum.to_list(stream)

    case find_matching_schema(rows_list, schemas, strategy, opts) do
      {:ok, matched_schema, schema_name} ->
        stream = Stream.map(rows_list, & &1)
        {:ok, result} = parse_with_schema(stream, matched_schema, opts)
        {:ok, %{result | matched_schema: schema_name}}

      {:error, _} = error ->
        error
    end
  end

  defp find_matching_schema(rows_list, schemas, strategy, opts) do
    header_row = get_header_row(rows_list, opts)

    matches =
      schemas
      |> Enum.with_index()
      |> Enum.filter(fn {schema, _idx} -> schema_matches_headers?(schema, header_row) end)

    case {strategy, matches} do
      {_, []} ->
        {:error, %{type: :no_match, message: "No schema matched the headers"}}

      {:first_match, [{schema, idx} | _]} ->
        {:ok, schema, :"schema_#{idx}"}

      {:exact_one, [{schema, idx}]} ->
        {:ok, schema, :"schema_#{idx}"}

      {:exact_one, matches} when length(matches) > 1 ->
        {:error,
         %{type: :ambiguous_match, message: "Multiple schemas matched", count: length(matches)}}
    end
  end

  defp get_header_row(rows_list, opts) do
    header_mode = Keyword.get(opts, :header, :auto)

    case header_mode do
      :absent ->
        []

      _ ->
        case List.first(rows_list) do
          {_row_num, cells} -> cells
          nil -> []
        end
    end
  end

  defp schema_matches_headers?(%SheetSchema{header_variants: variants} = schema, header_row) do
    required = SheetSchema.required_headers(schema)

    header_set =
      header_row
      |> Enum.map(&String.downcase(to_string(&1)))
      |> MapSet.new()

    Enum.all?(required, fn h ->
      header_matches?(h, header_set, variants)
    end)
  end

  defp header_matches?(header, header_set, variants) do
    downcased = String.downcase(header)

    if MapSet.member?(header_set, downcased) do
      true
    else
      variant_headers =
        variants
        |> Enum.filter(fn {_vh, field} -> Atom.to_string(field) == downcased end)
        |> Enum.map(fn {vh, _field} -> String.downcase(vh) end)

      Enum.any?(variant_headers, &MapSet.member?(header_set, &1))
    end
  end

  defp parse_with_schema(stream, %SheetSchema{} = schema, opts) do
    header_mode = Keyword.get(opts, :header, schema.header_mode)
    skip_rows = get_in(schema.row_filters, [:skip_rows]) || 0
    row_range = get_in(schema.row_filters, [:row_range])

    stream
    |> apply_skip_rows(skip_rows)
    |> apply_row_range(row_range)
    |> parse_rows(schema, header_mode)
  end

  defp apply_skip_rows(stream, 0), do: stream

  defp apply_skip_rows(stream, n) when n > 0 do
    Stream.drop(stream, n)
  end

  defp apply_row_range(stream, nil), do: stream

  defp apply_row_range(stream, range) do
    Stream.filter(stream, fn {row_num, _cells} -> row_num in range end)
  end

  defp parse_rows(stream, schema, header_mode) do
    {header_row, data_stream} = extract_header(stream, header_mode)
    column_mapping = build_column_mapping(schema, header_row)

    case validate_required_columns(schema, column_mapping) do
      :ok ->
        result = process_data_rows(data_stream, schema, column_mapping)
        {:ok, result}

      {:error, _} = error ->
        error
    end
  end

  defp extract_header(stream, :absent) do
    {[], stream}
  end

  defp extract_header(stream, _mode) do
    rows_list = Enum.to_list(stream)

    case rows_list do
      [] ->
        {[], Stream.map([], & &1)}

      [{_row_num, header_cells} | rest] ->
        {header_cells, Stream.map(rest, & &1)}
    end
  end

  defp build_column_mapping(%SheetSchema{columns: columns, header_variants: variants}, header_row) do
    header_positions =
      header_row
      |> Enum.with_index()
      |> Enum.map(fn {h, i} -> {String.downcase(to_string(h)), i} end)
      |> Map.new()

    Enum.map(columns, fn col ->
      position = find_column_position(col, header_positions, variants)
      {col.field_name, position, col}
    end)
  end

  defp find_column_position(
         %ColumnDef{header: header, at: at, field_name: field_name},
         header_positions,
         variants
       ) do
    cond do
      at != nil ->
        at

      header != nil ->
        case Map.get(header_positions, String.downcase(header)) do
          nil -> find_variant_position(field_name, header_positions, variants)
          pos -> pos
        end

      true ->
        find_variant_position(field_name, header_positions, variants)
    end
  end

  defp find_variant_position(field_name, header_positions, variants)
       when map_size(variants) > 0 do
    variant_headers =
      variants
      |> Enum.filter(fn {_header, field} -> field == field_name end)
      |> Enum.map(fn {header, _field} -> String.downcase(header) end)

    Enum.find_value(variant_headers, fn variant_header ->
      Map.get(header_positions, variant_header)
    end)
  end

  defp find_variant_position(_field_name, _header_positions, _variants), do: nil

  defp validate_required_columns(%SheetSchema{} = schema, mapping) do
    missing =
      mapping
      |> Enum.filter(fn {_name, pos, col} -> col.required && pos == nil end)
      |> Enum.map(fn {name, _pos, col} -> col.header || Atom.to_string(name) end)

    if missing == [] do
      :ok
    else
      {:error,
       %{
         type: :missing_headers,
         message: "Required headers not found: #{Enum.join(missing, ", ")}",
         missing: missing,
         required: SheetSchema.required_headers(schema)
       }}
    end
  end

  defp process_data_rows(stream, schema, column_mapping) do
    stream
    |> Stream.filter(fn {_row_num, cells} -> not blank_row?(cells) end)
    |> Enum.reduce(Result.new(), fn {row_num, cells}, result ->
      cells = pad_row(cells, max_column_index(column_mapping))
      parse_row(row_num, cells, schema, column_mapping, result)
    end)
    |> Result.finalize()
  end

  defp blank_row?(cells) do
    Enum.all?(cells, fn cell ->
      cell == nil || cell == "" || (is_binary(cell) && String.trim(cell) == "")
    end)
  end

  defp pad_row(cells, max_index) when max_index == nil, do: cells

  defp pad_row(cells, max_index) do
    current_len = length(cells)
    needed = max_index + 1

    if current_len >= needed do
      cells
    else
      cells ++ List.duplicate("", needed - current_len)
    end
  end

  defp max_column_index(mapping) do
    mapping
    |> Enum.map(fn {_name, pos, _col} -> pos end)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  defp parse_row(row_num, cells, schema, column_mapping, result) do
    transforms = schema.transforms

    {row_data, errors} =
      Enum.reduce(column_mapping, {%{}, []}, fn {field_name, position, col}, {data, errs} ->
        if position == nil && !col.required do
          {data, errs}
        else
          raw_value = if position, do: Enum.at(cells, position, ""), else: ""
          transformed_value = apply_transforms(raw_value, transforms)
          parse_cell(row_num, field_name, transformed_value, col, data, errs)
        end
      end)

    if errors == [] do
      Result.add_valid_row(result, row_data)
    else
      Enum.reduce(errors, result, &Result.add_invalid_row(&2, &1))
    end
  end

  defp apply_transforms(value, nil), do: value
  defp apply_transforms(value, transforms), do: Transform.run(value, transforms)

  defp parse_cell(row_num, field_name, raw_value, col, data, errors) do
    case validate_value(raw_value, col.type_schema) do
      {:ok, parsed_value} ->
        {Map.put(data, field_name, parsed_value), errors}

      {:error, message} ->
        error = Error.new(row_num, field_name, message, value: raw_value)
        {data, [error | errors]}
    end
  end

  defp validate_value(value, type_schema) do
    case Raggio.Schema.validate(type_schema, value) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, schema_errors} -> {:error, format_validation_error(schema_errors)}
    end
  end

  defp format_validation_error(errors) when is_list(errors) do
    errors
    |> Enum.map(fn
      %{message: msg} -> msg
      msg when is_binary(msg) -> msg
      other -> inspect(other)
    end)
    |> Enum.join("; ")
  end

  defp format_validation_error(error), do: inspect(error)
end
