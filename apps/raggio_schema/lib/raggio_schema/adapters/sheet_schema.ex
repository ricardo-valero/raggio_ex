defmodule Raggio.Schema.Importer.SheetSchema do
  @moduledoc """
  SheetSchema spreadsheet importer for Raggio.Schema.

  Imports schema definitions from CSV/TSV format with columns:
  - field_name (required): Field identifier
  - type (required): Type expression (string, integer, list(string), etc.)
  - required (optional): Boolean (true/false/yes/no/1/0)
  - constraints (optional): Pipe-separated constraint functions
  - description (optional): Human-readable documentation
  - example (optional): Example value
  - default (optional): Default value
  - parent_path (optional): Dot-notation nesting path

  ## Example

      {:ok, code} = SheetSchema.from_csv("schema.csv")
      IO.puts(code)
  """

  @required_columns ["field_name", "type"]

  @type validation_error :: {row :: non_neg_integer(), message :: String.t()}
  @type import_option ::
          {:format, boolean()}
          | {:module_name, String.t()}

  # Public API

  @doc """
  Import schema from CSV file.

  Returns generated Elixir code as string.
  """
  @spec from_csv(Path.t()) :: {:ok, String.t()} | {:error, term()}
  def from_csv(path) when is_binary(path) do
    from_csv(path, [])
  end

  @doc """
  Import schema from CSV file with options.

  Options:
  - `format: boolean()` - Format generated code (default: true)
  - `module_name: string()` - Wrap in module definition
  """
  @spec from_csv(Path.t(), [import_option()]) :: {:ok, String.t()} | {:error, term()}
  def from_csv(path, opts) when is_binary(path) and is_list(opts) do
    with {:ok, content} <- File.read(path),
         {:ok, rows} <- parse_csv(content),
         :ok <- validate_format(rows),
         {:ok, schema_tree} <- build_schema_tree(rows),
         {:ok, code} <- generate_code(schema_tree, opts) do
      {:ok, code}
    end
  end

  @doc """
  Validate SheetSchema format without generating code.

  Returns `:ok` or list of validation errors with row numbers.
  """
  @spec validate(Path.t()) :: :ok | {:error, [validation_error()]}
  def validate(path) when is_binary(path) do
    with {:ok, content} <- File.read(path),
         {:ok, rows} <- parse_csv(content),
         :ok <- validate_format(rows) do
      :ok
    end
  end

  # CSV Parsing

  defp parse_csv(content) do
    lines = String.split(content, "\n", trim: true)

    case lines do
      [] ->
        {:error, {:format_error, "Empty CSV file"}}

      [header_line | data_lines] ->
        headers = parse_csv_line(header_line)

        rows =
          data_lines
          |> Enum.with_index(2)
          |> Enum.map(fn {line, row_num} ->
            values = parse_csv_line(line)

            row_map =
              headers
              |> Enum.zip(values)
              |> Map.new()
              |> Map.put(:row_number, row_num)

            row_map
          end)

        {:ok, {headers, rows}}
    end
  end

  defp parse_csv_line(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  # Format Validation

  defp validate_format({headers, rows}) do
    with :ok <- validate_required_columns(headers),
         :ok <- validate_row_data(rows) do
      :ok
    end
  end

  defp validate_required_columns(headers) do
    missing = @required_columns -- headers

    case missing do
      [] ->
        :ok

      missing_cols ->
        {:error,
         {:format_error, "Missing required columns: #{Enum.join(missing_cols, ", ")}", headers}}
    end
  end

  defp validate_row_data(rows) do
    errors =
      rows
      |> Enum.flat_map(fn row ->
        validate_row(row)
      end)

    case errors do
      [] -> :ok
      errors -> {:error, {:validation_errors, errors}}
    end
  end

  defp validate_row(row) do
    errors = []

    # Validate field_name
    errors =
      if is_nil(row["field_name"]) or row["field_name"] == "" do
        [{row.row_number, "field_name cannot be empty"} | errors]
      else
        errors
      end

    # Validate type
    errors =
      if is_nil(row["type"]) or row["type"] == "" do
        [{row.row_number, "type cannot be empty"} | errors]
      else
        case parse_type(row["type"]) do
          {:ok, _} -> errors
          {:error, msg} -> [{row.row_number, "Invalid type: #{msg}"} | errors]
        end
      end

    errors
  end

  # Schema Tree Building

  defp build_schema_tree({_headers, rows}) do
    # Group rows by parent_path
    grouped = group_by_parent(rows)

    # Get all unique parent paths to create synthetic container fields
    all_parent_paths =
      rows
      |> Enum.map(fn row -> row["parent_path"] end)
      |> Enum.reject(&(&1 == "" || is_nil(&1)))
      |> Enum.uniq()

    # Build nested structure starting from root
    tree = build_nested_structure_with_containers(grouped, :root, all_parent_paths)

    {:ok, tree}
  end

  defp group_by_parent(rows) do
    Enum.group_by(rows, fn row ->
      parent = row["parent_path"]

      cond do
        is_nil(parent) -> :root
        parent == "" -> :root
        true -> parent
      end
    end)
  end

  defp build_nested_structure_with_containers(grouped, parent_key, all_parent_paths) do
    # Get direct fields at this level
    direct_fields = Map.get(grouped, parent_key, [])

    # Get child containers at this level
    # For parent_key = :root, find all parent_paths like "address" (no dots)
    # For parent_key = "address", find all parent_paths like "address.geo"
    parent_prefix = if parent_key == :root, do: "", else: "#{parent_key}."

    child_containers =
      all_parent_paths
      |> Enum.filter(fn path ->
        if parent_key == :root do
          # Top level: paths with no dots
          !String.contains?(path, ".")
        else
          # Nested: paths that start with parent_prefix and have no further dots
          String.starts_with?(path, parent_prefix) &&
            !String.contains?(String.replace_prefix(path, parent_prefix, ""), ".")
        end
      end)
      |> Enum.uniq()

    # Generate fields for direct fields
    direct_field_specs =
      Enum.map(direct_fields, fn row ->
        field_name = row["field_name"]
        field_atom = String.to_atom(field_name)

        %{
          name: field_atom,
          type: row["type"],
          required: parse_boolean(row["required"]),
          constraints: row["constraints"],
          default: row["default"],
          children: []
        }
      end)

    # Generate fields for container fields
    container_field_specs =
      Enum.map(child_containers, fn container_path ->
        # Extract just the container name (last segment)
        container_name =
          if parent_key == :root do
            container_path
          else
            String.replace_prefix(container_path, parent_prefix, "")
          end

        field_atom = String.to_atom(container_name)

        # Recursively build children for this container
        children =
          build_nested_structure_with_containers(grouped, container_path, all_parent_paths)

        %{
          name: field_atom,
          # Will be struct type
          type: nil,
          required: false,
          constraints: nil,
          default: nil,
          children: children
        }
      end)

    direct_field_specs ++ container_field_specs
  end

  # Code Generation

  defp generate_code(tree, opts) do
    should_format = Keyword.get(opts, :format, true)
    module_name = Keyword.get(opts, :module_name)

    fields_code = generate_struct_fields(tree, 0)

    schema_code = """
    Raggio.Schema.struct([
    #{fields_code}
    ])
    """

    final_code =
      if module_name do
        """
        defmodule #{module_name} do
          def schema do
            #{indent(schema_code, 2)}
          end
        end
        """
      else
        schema_code
      end

    formatted_code =
      if should_format do
        format_code(final_code)
      else
        final_code
      end

    {:ok, formatted_code}
  end

  defp generate_struct_fields(fields, indent_level) do
    fields
    |> Enum.map(fn field ->
      generate_field_code(field, indent_level + 1)
    end)
    |> Enum.join(",\n")
  end

  defp generate_field_code(field, indent_level) do
    indent_str = String.duplicate("  ", indent_level)

    # Generate type code
    type_code =
      if Enum.empty?(field.children) do
        generate_type_code(field.type)
      else
        # Nested struct
        nested_fields = generate_struct_fields(field.children, indent_level)

        """
        Raggio.Schema.struct([
        #{nested_fields}
        #{indent_str}  ])
        """
        |> String.trim()
      end

    # Apply constraints
    constrained_code =
      if field.constraints && field.constraints != "" do
        constraints = parse_constraints(field.constraints)
        apply_constraints(type_code, constraints)
      else
        type_code
      end

    # Apply modifiers
    modified_code = constrained_code

    modified_code =
      if !field.required do
        "#{modified_code} |> Raggio.Schema.optional()"
      else
        modified_code
      end

    modified_code =
      if field.default && field.default != "" do
        default_value = parse_default_value(field.default, field.type)
        "#{modified_code} |> Raggio.Schema.default(#{default_value})"
      else
        modified_code
      end

    "#{indent_str}{:#{field.name}, #{modified_code}}"
  end

  defp generate_type_code(type_expr) do
    case parse_type(type_expr) do
      {:ok, type_ast} -> type_ast_to_code(type_ast)
      # fallback
      {:error, _} -> "Raggio.Schema.string()"
    end
  end

  defp type_ast_to_code({:primitive, type_name}) do
    "Raggio.Schema.#{type_name}()"
  end

  defp type_ast_to_code({:list, inner_type}) do
    inner_code = type_ast_to_code(inner_type)
    "Raggio.Schema.array(#{inner_code})"
  end

  defp type_ast_to_code({:union, types}) do
    type_codes = Enum.map(types, &type_ast_to_code/1)
    "Raggio.Schema.union([#{Enum.join(type_codes, ", ")}])"
  end

  defp parse_constraints(constraints_str) do
    constraints_str
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp apply_constraints(base_code, constraints) do
    Enum.reduce(constraints, base_code, fn constraint, acc ->
      "#{acc} |> #{parse_single_constraint(constraint)}"
    end)
  end

  defp parse_single_constraint(constraint) do
    cond do
      String.contains?(constraint, "(") ->
        # Function call with arguments like "min_length(3)"
        [func_name, args] = String.split(constraint, "(", parts: 2)
        args = String.trim_trailing(args, ")")
        "Raggio.Schema.#{String.trim(func_name)}(#{args})"

      true ->
        # Simple function call like "email"
        "Raggio.Schema.#{constraint}()"
    end
  end

  # Type Parsing

  defp parse_type(type_str) do
    type_str = String.trim(type_str)

    cond do
      type_str in ["string", "integer", "float", "boolean", "date", "datetime", "decimal", "atom"] ->
        {:ok, {:primitive, type_str}}

      String.starts_with?(type_str, "list(") ->
        inner = String.slice(type_str, 5..-2//1)

        case parse_type(inner) do
          {:ok, inner_type} -> {:ok, {:list, inner_type}}
          error -> error
        end

      String.starts_with?(type_str, "array(") ->
        inner = String.slice(type_str, 6..-2//1)

        case parse_type(inner) do
          {:ok, inner_type} -> {:ok, {:list, inner_type}}
          error -> error
        end

      String.starts_with?(type_str, "union(") ->
        inner = String.slice(type_str, 6..-2//1)

        case parse_type(inner) do
          {:ok, inner_type} -> {:ok, {:list, inner_type}}
          error -> error
        end

      String.starts_with?(type_str, "union(") ->
        inner = String.slice(type_str, 6..-2//1)

        types =
          inner
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_type/1)

        if Enum.all?(types, &match?({:ok, _}, &1)) do
          {:ok, {:union, Enum.map(types, fn {:ok, t} -> t end)}}
        else
          {:error, "Invalid union type"}
        end

      true ->
        {:error, "Unknown type: #{type_str}"}
    end
  end

  defp parse_boolean(nil), do: false
  defp parse_boolean(""), do: false
  defp parse_boolean(val) when is_boolean(val), do: val

  defp parse_boolean(val) when is_binary(val) do
    downcased = String.downcase(val)
    downcased in ["true", "yes", "1", "t", "y"]
  end

  defp parse_default_value(default_str, _type) do
    # Simple implementation - can be enhanced
    case Integer.parse(default_str) do
      {int, ""} ->
        Integer.to_string(int)

      _ ->
        if String.starts_with?(default_str, "\"") do
          default_str
        else
          "\"#{default_str}\""
        end
    end
  end

  # Formatting Helpers

  defp format_code(code) do
    # Basic formatting - in production would use Code.format_string!
    code
    |> String.trim()
  end

  defp indent(text, levels) do
    indent_str = String.duplicate("  ", levels)

    text
    |> String.split("\n")
    |> Enum.map(fn line -> indent_str <> line end)
    |> Enum.join("\n")
  end
end
