defmodule Manuable.DataSchema.Transformer do
  @moduledoc """
  Handles encoding (internal -> external) transformations.

  The transformer converts internal representations back to external formats:
  - Applies custom transform.encode functions
  - Converts tuples back to arrays/maps
  - Handles nested structures

  ## Usage

      import DataSchema.Builders

      PersonSchema = tuple(
        name: string(),
        active: boolean()
      )

      {:ok, encoded} = Transformer.encode(%{name: "John", active: true}, PersonSchema)
  """

  alias Manuable.DataSchema.Builders.TypeDef
  alias Manuable.DataSchema.ParseError
  alias Manuable.DataSchema.Types

  @doc """
  Encodes parsed data to external representation.

  ## Parameters

  - `data` - Parsed data
  - `schema` - A `%TypeDef{}` schema
  - `opts` - Options:
    - `:string_keys` - If true, output string keys instead of atoms (default: false)

  ## Returns

  - `{:ok, encoded_data}` - Data encoded successfully
  - `{:error, [ParseError.t()]}` - One or more fields failed encoding
  """
  @spec encode(any(), TypeDef.t(), keyword()) :: {:ok, any()} | {:error, [ParseError.t()]}
  def encode(data, %TypeDef{} = schema, opts \\ []) do
    case encode_typedef_value(:root, schema, data) do
      {:ok, encoded} ->
        result =
          if Keyword.get(opts, :string_keys, false), do: stringify_keys(encoded), else: encoded

        {:ok, result}

      {:error, %ParseError{} = error} ->
        {:error, [error]}

      {:error, errors} when is_list(errors) ->
        {:error, errors}
    end
  end

  defp stringify_keys(%_{} = struct), do: struct

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), stringify_keys(v)} end)
  end

  defp stringify_keys(list) when is_list(list) do
    Enum.map(list, &stringify_keys/1)
  end

  defp stringify_keys(value), do: value

  # ===========================================================================
  # TypeDef Encoding
  # ===========================================================================

  # Apply transform.encode if present - the transform result IS the final encoded value
  # Using explicit try because we're catching exceptions from user-provided encode functions
  defp encode_typedef_value(name, %TypeDef{transform: %{encode: encode_fn}}, value) do
    {:ok, encode_fn.(value)}
  rescue
    e ->
      {:error, ParseError.decode_error(name, "transform encode failed: #{inspect(e)}", value)}
  end

  defp encode_typedef_value(name, %TypeDef{kind: :string}, value) do
    type_module = Types.get_type_module(:string)

    case type_module.encode(value, []) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, message} -> {:error, ParseError.decode_error(name, message, value)}
    end
  end

  defp encode_typedef_value(name, %TypeDef{kind: :integer}, value) do
    type_module = Types.get_type_module(:integer)

    case type_module.encode(value, []) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, message} -> {:error, ParseError.decode_error(name, message, value)}
    end
  end

  defp encode_typedef_value(name, %TypeDef{kind: :float}, value) do
    type_module = Types.get_type_module(:float)

    case type_module.encode(value, []) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, message} -> {:error, ParseError.decode_error(name, message, value)}
    end
  end

  defp encode_typedef_value(_name, %TypeDef{kind: :boolean}, value) do
    {:ok, value}
  end

  defp encode_typedef_value(name, %TypeDef{kind: :decimal}, value) do
    type_module = Types.get_type_module(:decimal)

    case type_module.encode(value, []) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, message} -> {:error, ParseError.decode_error(name, message, value)}
    end
  end

  defp encode_typedef_value(name, %TypeDef{kind: :datetime}, value) do
    type_module = Types.get_type_module(:datetime)

    case type_module.encode(value, []) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, message} -> {:error, ParseError.decode_error(name, message, value)}
    end
  end

  defp encode_typedef_value(_name, %TypeDef{kind: :literal}, value) do
    {:ok, value}
  end

  defp encode_typedef_value(name, %TypeDef{kind: :array, inner: inner_type}, value)
       when is_list(value) do
    {encoded_elements, errors} =
      value
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {elem, idx}, {acc_encoded, acc_errors} ->
        case encode_typedef_value(idx, inner_type, elem) do
          {:ok, encoded} ->
            {[encoded | acc_encoded], acc_errors}

          {:error, error} ->
            error_with_path = ParseError.prepend_path(error, name)
            {acc_encoded, [error_with_path | acc_errors]}
        end
      end)

    if errors == [] do
      {:ok, Enum.reverse(encoded_elements)}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp encode_typedef_value(name, %TypeDef{kind: :struct, schema: schema_module}, value)
       when is_map(value) do
    schema = schema_module.__schema__()

    case encode(value, schema) do
      {:ok, encoded} ->
        {:ok, encoded}

      {:error, errors} ->
        nested_errors = Enum.map(errors, &ParseError.prepend_path(&1, name))
        {:error, nested_errors}
    end
  end

  # Named tuple (from map)
  defp encode_typedef_value(name, %TypeDef{kind: :tuple, fields: fields}, value)
       when is_list(fields) and is_map(value) do
    encode_named_tuple(fields, value, name)
  end

  # Positional tuple (from tuple)
  defp encode_typedef_value(name, %TypeDef{kind: :tuple, elements: elements}, value)
       when is_list(elements) and is_tuple(value) do
    encode_positional_tuple(elements, value, name)
  end

  # Record (typed map)
  defp encode_typedef_value(
         name,
         %TypeDef{kind: :record, key_type: key_type, value_type: value_type},
         value
       )
       when is_map(value) do
    encode_record(key_type, value_type, value, name)
  end

  defp encode_typedef_value(_name, %TypeDef{kind: _kind}, value) do
    {:ok, value}
  end

  # ===========================================================================
  # Named Tuple Encoding
  # ===========================================================================

  defp encode_named_tuple(fields, data, parent_name) do
    {encoded, errors} =
      Enum.reduce(fields, {%{}, []}, fn {field_name, type_def}, acc ->
        encode_named_field(field_name, type_def, data, parent_name, acc)
      end)

    if errors == [], do: {:ok, encoded}, else: {:error, Enum.reverse(errors)}
  end

  defp encode_named_field(field_name, type_def, data, parent_name, {acc_encoded, acc_errors}) do
    case Map.fetch(data, field_name) do
      {:ok, value} when not is_nil(value) ->
        encode_field_value(field_name, type_def, value, parent_name, {acc_encoded, acc_errors})

      {:ok, nil} ->
        {Map.put(acc_encoded, field_name, nil), acc_errors}

      :error ->
        {acc_encoded, acc_errors}
    end
  end

  defp encode_field_value(field_name, type_def, value, parent_name, {acc_encoded, acc_errors}) do
    case encode_typedef_value(field_name, type_def, value) do
      {:ok, encoded_value} ->
        {Map.put(acc_encoded, field_name, encoded_value), acc_errors}

      {:error, error_or_errors} ->
        errors_with_path = add_encode_parent_path(error_or_errors, parent_name)
        {acc_encoded, errors_with_path ++ acc_errors}
    end
  end

  defp add_encode_parent_path(%ParseError{} = error, :root), do: [error]

  defp add_encode_parent_path(%ParseError{} = error, parent),
    do: [ParseError.prepend_path(error, parent)]

  defp add_encode_parent_path(errors, :root) when is_list(errors), do: errors

  defp add_encode_parent_path(errors, parent) when is_list(errors),
    do: Enum.map(errors, &ParseError.prepend_path(&1, parent))

  # ===========================================================================
  # Positional Tuple Encoding
  # ===========================================================================

  defp encode_positional_tuple(elements, value_tuple, name) do
    values = Tuple.to_list(value_tuple)

    if length(elements) != length(values) do
      {:error,
       ParseError.decode_error(
         name,
         "expected #{length(elements)} elements, got #{length(values)}",
         value_tuple
       )}
    else
      do_encode_positional_tuple(elements, values, name)
    end
  end

  defp do_encode_positional_tuple(elements, values, name) do
    {encoded_elements, errors} =
      elements
      |> Enum.zip(values)
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{type_def, value}, idx}, acc ->
        encode_positional_element(idx, type_def, value, name, acc)
      end)

    if errors == [],
      do: {:ok, Enum.reverse(encoded_elements)},
      else: {:error, Enum.reverse(errors)}
  end

  defp encode_positional_element(idx, type_def, value, name, {acc_encoded, acc_errors}) do
    case encode_typedef_value(idx, type_def, value) do
      {:ok, encoded} ->
        {[encoded | acc_encoded], acc_errors}

      {:error, error_or_errors} ->
        errors_with_path = prepend_encode_path(error_or_errors, name)
        {acc_encoded, errors_with_path ++ acc_errors}
    end
  end

  defp prepend_encode_path(%ParseError{} = error, name),
    do: [ParseError.prepend_path(error, name)]

  defp prepend_encode_path(errors, name) when is_list(errors),
    do: Enum.map(errors, &ParseError.prepend_path(&1, name))

  # ===========================================================================
  # Record Encoding
  # ===========================================================================
  defp encode_record(key_type, value_type, data, name) do
    {encoded_map, errors} =
      Enum.reduce(data, {%{}, []}, fn {key, value}, acc ->
        encode_record_entry(key, value, key_type, value_type, name, acc)
      end)

    if errors == [], do: {:ok, encoded_map}, else: {:error, Enum.reverse(errors)}
  end

  defp encode_record_entry(key, value, key_type, value_type, name, {acc_encoded, acc_errors}) do
    result = encode_key_value_pair(key, value, key_type, value_type)

    case result do
      {:ok, {encoded_key, encoded_value}} ->
        {Map.put(acc_encoded, encoded_key, encoded_value), acc_errors}

      {:error, error_or_errors} ->
        errors_with_path = add_encode_parent_path(error_or_errors, name)
        {acc_encoded, errors_with_path ++ acc_errors}
    end
  end

  defp encode_key_value_pair(key, value, key_type, value_type) do
    with {:ok, encoded_key} <- encode_typedef_value("key", key_type, key),
         {:ok, encoded_value} <- encode_typedef_value(encoded_key, value_type, value) do
      {:ok, {encoded_key, encoded_value}}
    end
  end
end
