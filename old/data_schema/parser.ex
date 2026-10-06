defmodule Manuable.DataSchema.Parser do
  @moduledoc """
  Core parsing engine for data schemas.

  Handles the parsing flow:
  1. Key normalization (string/atom keys)
  2. Required field validation
  3. Default value application
  4. Type decoding and constraint checking
  5. Error collection (non-fail-fast)

  ## Usage

      import DataSchema.Builders

      PersonSchema = tuple(
        name: string() |> min_value(1),
        age: integer() |> optional()
      )

      {:ok, %{name: "John"}} = Parser.parse(%{"name" => "John"}, PersonSchema)
  """

  alias Manuable.DataSchema.Builders.TypeDef
  alias Manuable.DataSchema.ParseError
  alias Manuable.DataSchema.Types

  @doc """
  Parses input data against a schema definition.

  ## Parameters

  - `data` - Input data (map, list, etc.)
  - `schema` - A `%TypeDef{}` schema (from `tuple()`, `record()`, etc.)

  ## Returns

  - `{:ok, parsed_data}` - Data parsed successfully
  - `{:error, [ParseError.t()]}` - One or more fields failed parsing

  ## Examples

      # Named tuple (object input)
      PersonSchema = tuple(name: string(), age: integer())
      {:ok, %{name: "John", age: 30}} = parse(%{"name" => "John", "age" => 30}, PersonSchema)

      # Positional tuple (array input)
      PointSchema = tuple(float(), float())
      {:ok, {1.0, 2.0}} = parse([1.0, 2.0], PointSchema)

      # Record (typed map)
      ScoresSchema = record(string(), integer())
      {:ok, %{"math" => 95}} = parse(%{"math" => 95}, ScoresSchema)
  """
  @spec parse(any(), TypeDef.t()) :: {:ok, any()} | {:error, [ParseError.t()]}
  def parse(data, %TypeDef{} = schema) do
    case decode_and_check_typedef(:root, schema, data) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, %ParseError{} = error} -> {:error, [error]}
      {:error, errors} when is_list(errors) -> {:error, errors}
    end
  end

  def parse(nil, _schema),
    do: {:error, [ParseError.decode_error(:root, "input cannot be nil", nil)]}

  # ===========================================================================
  # Key Normalization
  # ===========================================================================

  defp normalize_keys(data) when is_map(data) do
    Map.new(data, fn
      {key, value} when is_binary(key) ->
        {String.to_existing_atom(key), value}

      {key, value} when is_atom(key) ->
        {key, value}

      {key, value} ->
        {key, value}
    end)
  rescue
    ArgumentError ->
      # If string key doesn't exist as atom, try to create it
      Map.new(data, fn
        {key, value} when is_binary(key) ->
          {String.to_atom(key), value}

        {key, value} ->
          {key, value}
      end)
  end

  # ===========================================================================
  # TypeDef Decoding with Constraint Checking
  # ===========================================================================

  defp decode_and_check_typedef(name, %TypeDef{} = type_def, value) do
    # Check if transform is a preprocessing transform (runs BEFORE type validation)
    preprocess_transform = type_def.transform && Map.get(type_def.transform, :preprocess, false)

    # Apply preprocessing transform if present (converts raw input → typed value)
    preprocessed_value =
      if preprocess_transform do
        type_def.transform.decode.(value)
      else
        value
      end

    # Type decode and constraint check
    with {:ok, decoded} <- decode_typedef(type_def, preprocessed_value, name),
         :ok <- check_typedef_constraints(type_def, decoded, name) do
      # Apply post-processing transform if present (transforms validated value)
      if type_def.transform && not preprocess_transform do
        {:ok, type_def.transform.decode.(decoded)}
      else
        {:ok, decoded}
      end
    end
  end

  # ===========================================================================
  # Type Decoding
  # ===========================================================================

  defp decode_typedef(%TypeDef{kind: :string} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:string)

    case type_module.decode(value, constraints) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :integer} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:integer)

    case type_module.decode(value, constraints) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :float} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:float)

    case type_module.decode(value, constraints) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :boolean}, value, name) do
    type_module = Types.get_type_module(:boolean)

    case type_module.decode(value, []) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :decimal} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:decimal)

    case type_module.decode(value, constraints) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :datetime}, value, name) do
    type_module = Types.get_type_module(:datetime)

    case type_module.decode(value, []) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :date}, value, name) do
    type_module = Types.get_type_module(:date)

    case type_module.decode(value, []) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, msg} -> {:error, ParseError.decode_error(name, msg, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :literal, values: values}, value, name) do
    cond do
      # Direct match
      value in values ->
        {:ok, value}

      # String to atom coercion for atom literals
      is_binary(value) and is_atom(hd(values)) ->
        atom_value = String.to_atom(value)

        if atom_value in values do
          {:ok, atom_value}
        else
          {:error, ParseError.enum_error(name, values, value)}
        end

      true ->
        {:error, ParseError.enum_error(name, values, value)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :array, inner: inner_type} = type_def, value, name)
       when is_list(value) do
    constraints = type_def.constraints

    # Parse each element
    {parsed_elements, errors} =
      value
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {elem, idx}, {acc_parsed, acc_errors} ->
        case decode_and_check_typedef(idx, inner_type, elem) do
          {:ok, parsed} ->
            {[parsed | acc_parsed], acc_errors}

          {:error, %ParseError{} = error} ->
            error_with_path = ParseError.prepend_path(error, name)
            {acc_parsed, [error_with_path | acc_errors]}

          {:error, errors} when is_list(errors) ->
            errors_with_path = Enum.map(errors, &ParseError.prepend_path(&1, name))
            {acc_parsed, errors_with_path ++ acc_errors}
        end
      end)

    if errors == [] do
      parsed_list = Enum.reverse(parsed_elements)

      case check_array_constraints(constraints, parsed_list, name) do
        :ok -> {:ok, parsed_list}
        {:error, _} = error -> error
      end
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp decode_typedef(%TypeDef{kind: :array}, value, name) do
    {:error, ParseError.decode_error(name, "must be a list", value)}
  end

  defp decode_typedef(%TypeDef{kind: :struct, schema: schema_module}, value, name)
       when is_map(value) do
    # For struct references, get the schema and parse
    schema = schema_module.__schema__()

    case parse(value, schema) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, errors} ->
        nested_errors = Enum.map(errors, &ParseError.prepend_path(&1, name))
        {:error, nested_errors}
    end
  end

  defp decode_typedef(%TypeDef{kind: :struct}, value, name) do
    {:error, ParseError.decode_error(name, "must be a map", value)}
  end

  # Named tuple (from object/map input)
  defp decode_typedef(%TypeDef{kind: :tuple, fields: fields}, value, name)
       when is_list(fields) and is_map(value) do
    parse_named_tuple(fields, value, name)
  end

  defp decode_typedef(%TypeDef{kind: :tuple, fields: fields}, value, name)
       when is_list(fields) do
    {:error, ParseError.decode_error(name, "must be a map", value)}
  end

  # Positional tuple (from array input)
  defp decode_typedef(%TypeDef{kind: :tuple, elements: elements}, value, name)
       when is_list(elements) and is_list(value) do
    parse_positional_tuple(elements, value, name)
  end

  defp decode_typedef(%TypeDef{kind: :tuple, elements: elements}, value, name)
       when is_list(elements) do
    {:error, ParseError.decode_error(name, "must be a list", value)}
  end

  # Record (typed map with dynamic keys)
  defp decode_typedef(
         %TypeDef{kind: :record, key_type: key_type, value_type: value_type},
         value,
         name
       )
       when is_map(value) do
    parse_record(key_type, value_type, value, name)
  end

  defp decode_typedef(%TypeDef{kind: :record}, value, name) do
    {:error, ParseError.decode_error(name, "must be a map", value)}
  end

  defp decode_typedef(%TypeDef{kind: kind}, value, name) do
    {:error, ParseError.decode_error(name, "unsupported type: #{kind}", value)}
  end

  # ===========================================================================
  # Named Tuple Parsing (from object/map)
  # ===========================================================================

  defp parse_named_tuple(fields, data, parent_name) do
    normalized_data = normalize_keys(data)

    {parsed, errors} =
      Enum.reduce(fields, {%{}, []}, fn {field_name, type_def}, acc ->
        parse_named_field(field_name, type_def, normalized_data, parent_name, acc)
      end)

    if errors == [], do: {:ok, parsed}, else: {:error, Enum.reverse(errors)}
  end

  defp parse_named_field(field_name, type_def, data, parent_name, {acc_parsed, acc_errors}) do
    value = Map.get(data, field_name)
    result = resolve_field_value(field_name, type_def, value)
    accumulate_field_result(result, field_name, parent_name, {acc_parsed, acc_errors})
  end

  defp resolve_field_value(field_name, type_def, value) do
    cond do
      not is_nil(value) ->
        decode_and_check_typedef(field_name, type_def, value)

      TypeDef.has_default?(type_def) ->
        {:ok, TypeDef.default(type_def)}

      not TypeDef.optional?(type_def) ->
        {:error, ParseError.required(field_name)}

      true ->
        {:ok_skip}
    end
  end

  defp accumulate_field_result({:ok, parsed_value}, field_name, _parent, {acc_parsed, acc_errors}) do
    {Map.put(acc_parsed, field_name, parsed_value), acc_errors}
  end

  defp accumulate_field_result({:ok_skip}, _field_name, _parent, acc), do: acc

  defp accumulate_field_result(
         {:error, error_or_errors},
         _field_name,
         parent_name,
         {acc_parsed, acc_errors}
       ) do
    errors_with_path = add_parent_path(error_or_errors, parent_name)
    {acc_parsed, errors_with_path ++ acc_errors}
  end

  defp add_parent_path(%ParseError{} = error, :root), do: [error]

  defp add_parent_path(%ParseError{} = error, parent),
    do: [ParseError.prepend_path(error, parent)]

  defp add_parent_path(errors, :root) when is_list(errors), do: errors

  defp add_parent_path(errors, parent) when is_list(errors),
    do: Enum.map(errors, &ParseError.prepend_path(&1, parent))

  # ===========================================================================
  # Positional Tuple Parsing (from array)
  # ===========================================================================

  defp parse_positional_tuple(elements, values, name) do
    expected_len = length(elements)
    actual_len = length(values)

    if expected_len != actual_len do
      {:error,
       ParseError.decode_error(
         name,
         "expected #{expected_len} elements, got #{actual_len}",
         values
       )}
    else
      do_parse_positional_tuple(elements, values, name)
    end
  end

  defp do_parse_positional_tuple(elements, values, name) do
    {parsed_elements, errors} =
      elements
      |> Enum.zip(values)
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{type_def, value}, idx}, acc ->
        parse_positional_element(idx, type_def, value, name, acc)
      end)

    if errors == [] do
      {:ok, parsed_elements |> Enum.reverse() |> List.to_tuple()}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp parse_positional_element(idx, type_def, value, name, {acc_parsed, acc_errors}) do
    case decode_and_check_typedef(idx, type_def, value) do
      {:ok, parsed} ->
        {[parsed | acc_parsed], acc_errors}

      {:error, error_or_errors} ->
        errors_with_path = prepend_path_to_errors(error_or_errors, name)
        {acc_parsed, errors_with_path ++ acc_errors}
    end
  end

  defp prepend_path_to_errors(%ParseError{} = error, name),
    do: [ParseError.prepend_path(error, name)]

  defp prepend_path_to_errors(errors, name) when is_list(errors),
    do: Enum.map(errors, &ParseError.prepend_path(&1, name))

  # ===========================================================================
  # Record Parsing (typed map with dynamic keys)
  # ===========================================================================

  defp parse_record(key_type, value_type, data, name) do
    {parsed_map, errors} =
      Enum.reduce(data, {%{}, []}, fn {key, value}, acc ->
        parse_record_entry(key, value, key_type, value_type, name, acc)
      end)

    if errors == [], do: {:ok, parsed_map}, else: {:error, Enum.reverse(errors)}
  end

  defp parse_record_entry(key, value, key_type, value_type, name, {acc_parsed, acc_errors}) do
    result = parse_key_value_pair(key, value, key_type, value_type)

    case result do
      {:ok, {parsed_key, parsed_value}} ->
        {Map.put(acc_parsed, parsed_key, parsed_value), acc_errors}

      {:error, error_or_errors} ->
        errors_with_path = add_parent_path(error_or_errors, name)
        {acc_parsed, errors_with_path ++ acc_errors}
    end
  end

  defp parse_key_value_pair(key, value, key_type, value_type) do
    with {:ok, parsed_key} <- decode_and_check_typedef("key", key_type, key),
         {:ok, parsed_value} <- decode_and_check_typedef(parsed_key, value_type, value) do
      {:ok, {parsed_key, parsed_value}}
    end
  end

  # ===========================================================================
  # Constraint Checking
  # ===========================================================================

  defp check_typedef_constraints(%TypeDef{kind: :string} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:string)

    case type_module.check_constraints(value, constraints) do
      :ok -> :ok
      {:error, msg} -> {:error, ParseError.constraint_error(name, msg, value)}
    end
  end

  defp check_typedef_constraints(%TypeDef{kind: :integer} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:integer)

    case type_module.check_constraints(value, constraints) do
      :ok -> :ok
      {:error, msg} -> {:error, ParseError.constraint_error(name, msg, value)}
    end
  end

  defp check_typedef_constraints(%TypeDef{kind: :float} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:float)

    case type_module.check_constraints(value, constraints) do
      :ok -> :ok
      {:error, msg} -> {:error, ParseError.constraint_error(name, msg, value)}
    end
  end

  defp check_typedef_constraints(%TypeDef{kind: :decimal} = type_def, value, name) do
    constraints = type_def.constraints
    type_module = Types.get_type_module(:decimal)

    case type_module.check_constraints(value, constraints) do
      :ok -> :ok
      {:error, msg} -> {:error, ParseError.constraint_error(name, msg, value)}
    end
  end

  defp check_typedef_constraints(%TypeDef{kind: _kind}, _value, _name) do
    # Most types don't have additional constraints beyond decoding
    :ok
  end

  # Array constraint checking
  defp check_array_constraints(constraints, list, name) do
    cond do
      Keyword.get(constraints, :non_empty, false) and list == [] ->
        {:error, ParseError.non_empty_error(name)}

      (min_len = Keyword.get(constraints, :min_length)) && length(list) < min_len ->
        {:error, ParseError.min_length_error(name, min_len, list)}

      (max_len = Keyword.get(constraints, :max_length)) && length(list) > max_len ->
        {:error, ParseError.max_length_error(name, max_len, list)}

      true ->
        :ok
    end
  end
end
