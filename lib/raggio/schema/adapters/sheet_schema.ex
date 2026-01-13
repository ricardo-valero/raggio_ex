defmodule Raggio.Schema.Adapters.SheetSchema do
  @moduledoc """
  Import schema definitions from SheetSchema CSV format.
  """

  @required_columns ["field_name", "type"]

  def from_csv(path), do: from_csv(path, [])

  def from_csv(path, opts) do
    with {:ok, content} <- File.read(path),
         {:ok, rows} <- parse_csv(content),
         {:ok, schema_code} <- generate_code(rows, opts) do
      {:ok, schema_code}
    end
  end

  def from_url(_url), do: from_url_not_implemented()
  def from_url(_url, _opts), do: from_url_not_implemented()

  defp from_url_not_implemented do
    {:error,
     %{
       type: :not_implemented,
       message: "HTTP client not implemented - use from_csv/1 with local file"
     }}
  end

  def validate_format(path) do
    with {:ok, content} <- File.read(path),
         {:ok, rows} <- parse_csv(content) do
      validate_rows(rows)
    end
  end

  defp parse_csv(content) do
    lines = String.split(content, ~r/\r?\n/, trim: true)

    case lines do
      [] ->
        {:error, %{type: :format_error, message: "Empty CSV file"}}

      [header | data_lines] ->
        headers = parse_csv_line(header)

        case validate_headers(headers) do
          :ok ->
            rows =
              data_lines
              |> Enum.with_index(2)
              |> Enum.map(fn {line, row_num} ->
                values = parse_csv_line(line)
                {row_num, Enum.zip(headers, values) |> Map.new()}
              end)

            {:ok, rows}

          error ->
            error
        end
    end
  end

  defp parse_csv_line(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp validate_headers(headers) do
    missing = @required_columns -- headers

    if missing == [] do
      :ok
    else
      {:error,
       %{
         type: :format_error,
         message: "Missing required columns: #{Enum.join(missing, ", ")}",
         found_columns: headers
       }}
    end
  end

  defp validate_rows(rows) do
    errors =
      rows
      |> Enum.flat_map(fn {row_num, row} ->
        validate_row(row_num, row)
      end)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  defp validate_row(row_num, row) do
    errors = []

    errors =
      if row["field_name"] == "" or is_nil(row["field_name"]) do
        [{row_num, "field_name is required"} | errors]
      else
        errors
      end

    errors =
      if row["type"] == "" or is_nil(row["type"]) do
        [{row_num, "type is required"} | errors]
      else
        errors
      end

    errors
  end

  defp generate_code(rows, opts) do
    grouped = group_by_parent(rows)
    code = build_schema_code(grouped, "")
    module_name = Keyword.get(opts, :module_name)

    code =
      if module_name do
        """
        defmodule #{module_name} do
          alias Raggio.Schema

          def schema do
        #{indent(code, "    ")}
          end
        end
        """
      else
        code
      end

    {:ok, code}
  end

  defp group_by_parent(rows) do
    rows
    |> Enum.reduce(%{}, fn {_row_num, row}, acc ->
      parent = row["parent_path"] || ""
      field = build_field_def(row)
      Map.update(acc, parent, [field], &(&1 ++ [field]))
    end)
  end

  defp build_field_def(row) do
    name = row["field_name"]
    type = row["type"]
    required = parse_required(row["required"])
    constraints = parse_constraints(row["constraints"])
    default = row["default"]

    type_code = build_type_code(type, constraints)

    type_code =
      if default && default != "" do
        "#{type_code}, default: #{inspect_value(default)}"
      else
        type_code
      end

    type_code =
      if required do
        type_code
      else
        "Schema.optional(#{type_code})"
      end

    {name, type_code}
  end

  defp build_type_code(type, constraints) do
    base =
      case type do
        "string" ->
          "Schema.string()"

        "integer" ->
          "Schema.integer()"

        "float" ->
          "Schema.float()"

        "boolean" ->
          "Schema.boolean()"

        "date" ->
          "Schema.date()"

        "datetime" ->
          "Schema.datetime()"

        "decimal" ->
          "Schema.decimal()"

        "list(" <> rest ->
          inner = String.trim_trailing(rest, ")")
          "Schema.list(#{build_type_code(inner, [])})"

        _ ->
          "Schema.string()"
      end

    apply_constraints(base, constraints)
  end

  defp apply_constraints(base, []), do: base

  defp apply_constraints(base, constraints) do
    constraint_opts =
      constraints
      |> Enum.map(fn
        {"min", val} -> "min: #{val}"
        {"max", val} -> "max: #{val}"
        {"pattern", val} -> "pattern: ~r/#{val}/"
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if constraint_opts == "" do
      base
    else
      String.replace(base, "()", "(#{constraint_opts})")
    end
  end

  defp parse_required(nil), do: true
  defp parse_required(""), do: true
  defp parse_required("true"), do: true
  defp parse_required("yes"), do: true
  defp parse_required("1"), do: true
  defp parse_required(_), do: false

  defp parse_constraints(nil), do: []
  defp parse_constraints(""), do: []

  defp parse_constraints(str) do
    str
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_constraint/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_constraint(str) do
    case Regex.run(~r/^(\w+)\((.+)\)$/, str) do
      [_, "min", val] -> {"min", val}
      [_, "max", val] -> {"max", val}
      [_, "pattern", val] -> {"pattern", val}
      _ -> nil
    end
  end

  defp build_schema_code(grouped, parent_path) do
    fields = Map.get(grouped, parent_path, [])

    parent_depth = if parent_path == "", do: 0, else: length(String.split(parent_path, "."))

    nested_paths =
      grouped
      |> Map.keys()
      |> Enum.filter(fn path ->
        path != parent_path and
          ((parent_path == "" and not String.contains?(path, ".")) or
             (String.starts_with?(path, parent_path <> ".") and
                length(String.split(path, ".")) == parent_depth + 1))
      end)

    all_fields =
      fields ++
        Enum.map(nested_paths, fn path ->
          nested_name = path |> String.split(".") |> List.last()
          nested_code = build_schema_code(grouped, path)
          {nested_name, nested_code}
        end)

    if all_fields == [] do
      "Schema.struct([])"
    else
      field_lines =
        all_fields
        |> Enum.map(fn {name, code} ->
          "{:#{name}, #{code}}"
        end)
        |> Enum.join(",\n  ")

      "Schema.struct([\n  #{field_lines}\n])"
    end
  end

  defp inspect_value(val) do
    cond do
      String.match?(val, ~r/^\d+$/) -> val
      String.match?(val, ~r/^\d+\.\d+$/) -> val
      val == "true" -> "true"
      val == "false" -> "false"
      true -> inspect(val)
    end
  end

  defp indent(str, prefix) do
    str
    |> String.split("\n")
    |> Enum.map(&(prefix <> &1))
    |> Enum.join("\n")
  end
end
