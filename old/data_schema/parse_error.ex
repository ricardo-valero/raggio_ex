defmodule Manuable.DataSchema.ParseError do
  @moduledoc """
  Represents a parse error with full context.

  ## Fields

  - `path` - Path to the invalid field (e.g., `[:address, :zip]` or `[:items, 0, :name]`)
  - `code` - Machine-readable error code for programmatic handling
  - `message` - Human-readable error message
  - `value` - The invalid value that caused the error
  - `constraint` - The constraint that was violated (e.g., `min: 5`)
  - `row` - Optional row number for tabular data parsing

  ## Error Codes

  - `:required` - Required field is missing
  - `:type_mismatch` - Value is wrong type
  - `:min_length` - String too short
  - `:max_length` - String too long
  - `:min_value` - Number below minimum
  - `:max_value` - Number above maximum
  - `:format` - String doesn't match format
  - `:enum` - Value not in allowed list
  - `:not_a_number` - Cannot parse as number
  - `:invalid_datetime` - Cannot parse as datetime
  - `:non_empty` - Array is empty
  - `:transform_error` - Custom transform failed
  - `:decode_error` - Decoding/parsing failed
  """

  @type path_segment :: atom() | non_neg_integer()

  @type error_code ::
          :required
          | :type_mismatch
          | :min_length
          | :max_length
          | :min_value
          | :max_value
          | :greater_than
          | :less_than
          | :format
          | :enum
          | :not_a_number
          | :invalid_datetime
          | :invalid_array_element
          | :non_empty
          | :transform_error
          | :decode_error
          | :blank
          | :constraint_error

  @type t :: %__MODULE__{
          path: [path_segment()],
          code: error_code(),
          message: String.t(),
          value: any(),
          constraint: any() | nil,
          row: pos_integer() | nil
        }

  @enforce_keys [:path, :code, :message]
  defstruct [
    :path,
    :code,
    :message,
    :value,
    :constraint,
    :row
  ]

  @doc """
  Creates a new ParseError.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      path: Keyword.fetch!(opts, :path),
      code: Keyword.fetch!(opts, :code),
      message: Keyword.fetch!(opts, :message),
      value: Keyword.get(opts, :value),
      constraint: Keyword.get(opts, :constraint),
      row: Keyword.get(opts, :row)
    }
  end

  @doc """
  Formats the path as a human-readable string.

  ## Examples

      iex> ParseError.format_path([:address, :zip])
      "address.zip"

      iex> ParseError.format_path([:items, 0, :name])
      "items[0].name"

      iex> ParseError.format_path([:name])
      "name"
  """
  @spec format_path([path_segment()]) :: String.t()
  def format_path([]), do: ""

  def format_path(path) do
    path
    |> Enum.map_join(".", fn
      segment when is_atom(segment) -> Atom.to_string(segment)
      index when is_integer(index) -> "[#{index}]"
    end)
    |> String.replace(".[", "[")
  end

  @doc """
  Formats a list of errors as a human-readable string.
  Useful for raising exceptions with `parse!/1`.
  """
  @spec format_errors([t()]) :: String.t()
  def format_errors([]), do: "No errors"

  def format_errors(errors) when is_list(errors) do
    Enum.map_join(errors, "; ", fn error ->
      path_str = format_path(error.path)
      "#{path_str}: #{error.message}"
    end)
  end

  @doc """
  Prepends a path segment to an error's path.
  Used when building nested error paths.
  """
  @spec prepend_path(t(), path_segment()) :: t()
  def prepend_path(%__MODULE__{path: path} = error, segment) do
    %{error | path: [segment | path]}
  end

  @doc """
  Prepends multiple path segments to an error's path.
  """
  @spec prepend_path_segments(t(), [path_segment()]) :: t()
  def prepend_path_segments(%__MODULE__{path: path} = error, segments) do
    %{error | path: segments ++ path}
  end

  # ============================================================================
  # Error Construction Helpers
  # ============================================================================

  @doc """
  Creates a "required" error for a missing field.
  """
  @spec required(atom()) :: t()
  def required(field_name) do
    new(
      path: [field_name],
      code: :required,
      message: "must be present"
    )
  end

  @doc """
  Creates a "type_mismatch" error.
  """
  @spec type_mismatch(atom(), String.t(), any()) :: t()
  def type_mismatch(field_name, expected_type, value) do
    new(
      path: [field_name],
      code: :type_mismatch,
      message: "must be a #{expected_type}",
      value: value
    )
  end

  @doc """
  Creates a "min_length" error for strings.
  """
  @spec min_length(atom(), non_neg_integer(), any()) :: t()
  def min_length(field_name, min, value) do
    new(
      path: [field_name],
      code: :min_length,
      message: "is too short (minimum is #{min} characters)",
      value: value,
      constraint: min
    )
  end

  @doc """
  Creates a "max_length" error for strings.
  """
  @spec max_length(atom(), non_neg_integer(), any()) :: t()
  def max_length(field_name, max, value) do
    new(
      path: [field_name],
      code: :max_length,
      message: "is too long (maximum is #{max} characters)",
      value: value,
      constraint: max
    )
  end

  @doc """
  Creates a "min_value" error for numbers.
  """
  @spec min_value(atom(), number(), any()) :: t()
  def min_value(field_name, min, value) do
    new(
      path: [field_name],
      code: :min_value,
      message: "must be greater than or equal to #{min}",
      value: value,
      constraint: min
    )
  end

  @doc """
  Creates a "max_value" error for numbers.
  """
  @spec max_value(atom(), number(), any()) :: t()
  def max_value(field_name, max, value) do
    new(
      path: [field_name],
      code: :max_value,
      message: "must be less than or equal to #{max}",
      value: value,
      constraint: max
    )
  end

  @doc """
  Creates a "format" error for strings that don't match a pattern.
  """
  @spec format(atom(), any()) :: t()
  def format(field_name, value) do
    new(
      path: [field_name],
      code: :format,
      message: "is invalid",
      value: value
    )
  end

  @doc """
  Creates an "enum" error for values not in the allowed list.
  """
  @spec enum(atom(), [atom()] | [String.t()], any()) :: t()
  def enum(field_name, allowed_values, value) do
    values_str = Enum.join(allowed_values, ", ")

    new(
      path: [field_name],
      code: :enum,
      message: "must be one of: #{values_str}",
      value: value,
      constraint: allowed_values
    )
  end

  @doc """
  Creates a "not_a_number" error.
  """
  @spec not_a_number(atom(), any()) :: t()
  def not_a_number(field_name, value) do
    new(
      path: [field_name],
      code: :not_a_number,
      message: "is not a valid number",
      value: value
    )
  end

  @doc """
  Creates an "invalid_datetime" error.
  """
  @spec invalid_datetime(atom(), any()) :: t()
  def invalid_datetime(field_name, value) do
    new(
      path: [field_name],
      code: :invalid_datetime,
      message: "is not a valid datetime",
      value: value
    )
  end

  @doc """
  Creates a "non_empty" error for empty arrays.
  """
  @spec non_empty(atom()) :: t()
  def non_empty(field_name) do
    new(
      path: [field_name],
      code: :non_empty,
      message: "must not be empty"
    )
  end

  @doc """
  Creates a generic decode error with a custom message.
  """
  @spec decode_error(atom(), String.t(), any()) :: t()
  def decode_error(field_name, message, value) do
    new(
      path: [field_name],
      code: :decode_error,
      message: message,
      value: value
    )
  end

  @doc """
  Creates an "enum" error - alias for enum/3.
  """
  @spec enum_error(atom(), [any()], any()) :: t()
  def enum_error(field_name, allowed_values, value) do
    __MODULE__.enum(field_name, allowed_values, value)
  end

  @doc """
  Creates a "greater_than" error for exclusive minimum.
  """
  @spec greater_than_error(atom(), number(), any()) :: t()
  def greater_than_error(field_name, limit, value) do
    new(
      path: [field_name],
      code: :greater_than,
      message: "must be greater than #{limit}",
      value: value,
      constraint: limit
    )
  end

  @doc """
  Creates a "less_than" error for exclusive maximum.
  """
  @spec less_than_error(atom(), number(), any()) :: t()
  def less_than_error(field_name, limit, value) do
    new(
      path: [field_name],
      code: :less_than,
      message: "must be less than #{limit}",
      value: value,
      constraint: limit
    )
  end

  @doc """
  Creates a "non_empty" error - alias for non_empty/1.
  """
  @spec non_empty_error(atom()) :: t()
  def non_empty_error(field_name) do
    non_empty(field_name)
  end

  @doc """
  Creates a "min_length" error for arrays.
  """
  @spec min_length_error(atom(), non_neg_integer(), any()) :: t()
  def min_length_error(field_name, min, value) do
    new(
      path: [field_name],
      code: :min_length,
      message: "must have at least #{min} items",
      value: value,
      constraint: min
    )
  end

  @doc """
  Creates a "max_length" error for arrays.
  """
  @spec max_length_error(atom(), non_neg_integer(), any()) :: t()
  def max_length_error(field_name, max, value) do
    new(
      path: [field_name],
      code: :max_length,
      message: "must have at most #{max} items",
      value: value,
      constraint: max
    )
  end

  @doc """
  Creates a generic constraint error.
  """
  @spec constraint_error(atom(), String.t(), any()) :: t()
  def constraint_error(field_name, message, value) do
    new(
      path: [field_name],
      code: infer_error_code(message),
      message: message,
      value: value
    )
  end

  @error_code_patterns [
    {"too short", :min_length},
    {"too long", :max_length},
    {"greater than or equal", :min_value},
    {"less than or equal", :max_value},
    {"greater than", :greater_than},
    {"less than", :less_than},
    {"format", :format},
    {"invalid", :format},
    {"blank", :blank}
  ]

  defp infer_error_code(message) do
    Enum.find_value(@error_code_patterns, :constraint_error, fn {pattern, code} ->
      if String.contains?(message, pattern), do: code
    end)
  end

  @doc """
  Creates a "blank" error for empty strings.
  """
  @spec blank(atom(), any()) :: t()
  def blank(field_name, value \\ "") do
    new(
      path: [field_name],
      code: :blank,
      message: "cannot be blank",
      value: value
    )
  end
end
