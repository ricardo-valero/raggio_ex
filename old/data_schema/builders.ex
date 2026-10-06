defmodule Manuable.DataSchema.Builders do
  @moduledoc """
  Pipe-based builder functions for defining schema types.

  This module provides composable type builders and constraint functions
  that follow the pipe-based builder pattern. Import this module to use
  the DSL for defining schemas.

  ## Usage

      import DataSchema.Builders

      # Positional tuple (from array input)
      PointSchema = tuple(float(), float())
      # [1.0, 2.0] → {1.0, 2.0}

      # Named tuple / struct (from object input)
      PersonSchema = tuple(
        name: string() |> min(1) |> max(100),
        email: string() |> format(~r/@/),
        age: integer() |> min(0) |> optional(),
        active: boolean() |> default(true)
      )
      # {"name": "John", ...} → %{name: "John", ...}

      # Nested schemas
      OrderSchema = tuple(
        id: string(),
        customer: PersonSchema,
        items: array(tuple(sku: string(), qty: integer()))
      )

      # Record (typed map with dynamic keys)
      ScoresSchema = record(string(), integer())
      # {"math": 95, "english": 87} → %{"math" => 95, "english" => 87}

  ## Type Builders

  - `string/0` - String type
  - `integer/0` - Integer type
  - `float/0` - Float type
  - `boolean/0` - Boolean type
  - `decimal/0` - Decimal type
  - `datetime/0` - DateTime type
  - `date/0` - Date type (without time)
  - `array/1` - Array of typed elements
  - `tuple/1` - Positional tuple (from array) or named tuple (from object)
  - `record/2` - Typed map with dynamic keys
  - `literal/1` - Enumerated values

  ## Constraint Functions

  - `min/2`, `max/2` - Min/max length (string/array) or value (number)
  - `format/2` - Regex pattern for strings
  - `trim/1`, `trim/2` - Whitespace trimming

  ## Field Options

  - `optional/1` - Mark field as optional
  - `default/2` - Set default value
  - `description/2` - Add description for docs/export

  ## Excel Transforms

  For Excel/CSV parsing, use the transforms in `DataSchema.Transforms.Excel`:

      import DataSchema.Transforms.Excel

      string() |> excel_string()
      decimal() |> excel_decimal()
      integer() |> excel_integer()
  """

  defmodule TypeDef do
    @moduledoc """
    Represents a type definition with constraints and transformations.

    This struct is the core building block for the pipe-based builder pattern.
    """

    @type kind ::
            :any
            | :string
            | :integer
            | :float
            | :boolean
            | :decimal
            | :datetime
            | :date
            | :array
            | :tuple
            | :record
            | :struct
            | :literal
            | :coerce

    @type transform :: %{
            target: kind(),
            decode: (any() -> any()),
            encode: (any() -> any())
          }

    @type t :: %__MODULE__{
            kind: kind(),
            constraints: keyword(),
            inner: t() | nil,
            schema: module() | nil,
            values: [any()] | nil,
            transform: transform() | nil,
            metadata: keyword(),
            # For positional tuple: list of TypeDef
            elements: [t()] | nil,
            # For named tuple: keyword list of {atom, TypeDef}
            fields: keyword() | nil,
            # For record: key type
            key_type: t() | nil,
            # For record: value type
            value_type: t() | nil
          }

    defstruct kind: :any,
              constraints: [],
              inner: nil,
              schema: nil,
              values: nil,
              transform: nil,
              metadata: [],
              elements: nil,
              fields: nil,
              key_type: nil,
              value_type: nil

    @doc """
    Returns whether the type is optional.
    """
    @spec optional?(t()) :: boolean()
    def optional?(%__MODULE__{metadata: metadata}) do
      Keyword.get(metadata, :optional, false)
    end

    @doc """
    Returns the default value for the type, or nil if not set.
    For static defaults, returns the value directly.
    For dynamic defaults (0-arity functions), evaluates the function.
    """
    @spec default(t()) :: any()
    def default(%__MODULE__{metadata: metadata}) do
      case Keyword.get(metadata, :default) do
        fun when is_function(fun, 0) -> fun.()
        value -> value
      end
    end

    @doc """
    Evaluates the default value with the given attrs map.
    For 1-arity function defaults, passes attrs to the function.
    For 0-arity functions, evaluates without args.
    For static values, returns the value directly.
    """
    @spec evaluate_default(t(), map()) :: any()
    def evaluate_default(%__MODULE__{metadata: metadata}, attrs) do
      case Keyword.get(metadata, :default) do
        fun when is_function(fun, 1) -> fun.(attrs)
        fun when is_function(fun, 0) -> fun.()
        value -> value
      end
    end

    @doc """
    Returns whether the type has a default value.
    """
    @spec has_default?(t()) :: boolean()
    def has_default?(%__MODULE__{metadata: metadata}) do
      Keyword.has_key?(metadata, :default)
    end

    @doc """
    Returns whether this is a named tuple (has fields) vs positional tuple (has elements).
    """
    @spec named_tuple?(t()) :: boolean()
    def named_tuple?(%__MODULE__{kind: :tuple, fields: fields}) when is_list(fields), do: true
    def named_tuple?(_), do: false

    @doc """
    Returns whether this is a positional tuple.
    """
    @spec positional_tuple?(t()) :: boolean()
    def positional_tuple?(%__MODULE__{kind: :tuple, elements: elements}) when is_list(elements),
      do: true

    def positional_tuple?(_), do: false
  end

  alias __MODULE__.TypeDef

  # ===========================================================================
  # Primitive Type Builders
  # ===========================================================================

  @doc """
  Creates an any type that accepts any value.

  Primarily used with `coerce/1` to specify the source type for coercion.

  ## Examples

      coerce(any()) |> decimal()   # any value → Decimal
      coerce() |> decimal()        # same as above (any() is default)
  """
  @spec any() :: TypeDef.t()
  def any, do: %TypeDef{kind: :any}

  @doc """
  Creates a string type.

  ## Examples

      string()
      string() |> min(1) |> max(100)
  """
  @spec string() :: TypeDef.t()
  def string, do: %TypeDef{kind: :string}

  @doc """
  Creates an integer type.

  ## Examples

      integer()
      integer() |> min(0) |> max(100)
  """
  @spec integer() :: TypeDef.t()
  def integer, do: %TypeDef{kind: :integer}

  @doc """
  Creates a float type.

  ## Examples

      float()
      float() |> min(0.0) |> max(1.0)
  """
  @spec float() :: TypeDef.t()
  def float, do: %TypeDef{kind: :float}

  @doc """
  Creates a boolean type.

  Types operate in strict mode - only accepts `true`/`false`.
  Use explicit transforms for coercion from strings or integers.

  ## Examples

      boolean()
  """
  @spec boolean() :: TypeDef.t()
  def boolean, do: %TypeDef{kind: :boolean}

  @doc """
  Creates a decimal type for precise numeric values.

  Types operate in strict mode - only accepts `Decimal.t()`.
  Use explicit transforms for coercion from float/integer/string.

  ## Examples

      decimal()
      decimal() |> min(0) |> max(1000)
  """
  @spec decimal() :: TypeDef.t()
  def decimal, do: %TypeDef{kind: :decimal}

  @doc """
  Creates a datetime type.

  Decodes from DateTime structs or ISO8601 strings.

  ## Examples

      datetime()
  """
  @spec datetime() :: TypeDef.t()
  def datetime, do: %TypeDef{kind: :datetime}

  @doc """
  Creates a date type (without time component).

  Decodes from Date structs or ISO8601 date strings.

  ## Examples

      date()
  """
  @spec date() :: TypeDef.t()
  def date, do: %TypeDef{kind: :date}

  # ===========================================================================
  # Composite Type Builders
  # ===========================================================================

  @doc """
  Creates an array type with the specified element type.

  ## Examples

      array(string())
      array(integer() |> min(0))
      array(string()) |> min(1)  # non-empty array
  """
  @spec array(TypeDef.t()) :: TypeDef.t()
  def array(%TypeDef{} = inner) do
    %TypeDef{kind: :array, inner: inner}
  end

  @doc """
  Creates a tuple type.

  ## Positional tuple (from array input)

  When called with positional arguments, creates a fixed-size tuple
  where each position has a specific type. Input is an array.

      PointSchema = tuple(float(), float())
      # Input: [1.0, 2.0] → Output: {1.0, 2.0}

      RGBSchema = tuple(integer(), integer(), integer())
      # Input: [255, 128, 0] → Output: {255, 128, 0}

  ## Named tuple (from object input)

  When called with keyword arguments, creates a struct-like type
  where each field has a name and type. Input is an object/map.

      PersonSchema = tuple(
        name: string() |> min(1),
        email: string() |> format(~r/@/),
        age: integer() |> optional()
      )
      # Input: {"name": "John", "email": "j@x.com"} → Output: %{name: "John", email: "j@x.com"}

  ## Nested tuples

      OrderSchema = tuple(
        id: string(),
        customer: PersonSchema,
        items: array(tuple(sku: string(), qty: integer()))
      )
  """
  @spec tuple(keyword() | [TypeDef.t()]) :: TypeDef.t()
  def tuple(fields_or_elements)

  # Named tuple (keyword list) - for object input
  def tuple([{key, _} | _] = fields) when is_atom(key) do
    normalized_fields = normalize_fields(fields)
    %TypeDef{kind: :tuple, fields: normalized_fields}
  end

  # Positional tuple (list of types) - for array input
  def tuple(elements) when is_list(elements) do
    normalized_elements = Enum.map(elements, &normalize_type/1)
    %TypeDef{kind: :tuple, elements: normalized_elements}
  end

  # Single positional element
  def tuple(%TypeDef{} = element) do
    %TypeDef{kind: :tuple, elements: [element]}
  end

  @doc """
  Creates a tuple with multiple positional type arguments.

  ## Examples

      tuple(float(), float())           # 2-element tuple
      tuple(string(), integer(), boolean())  # 3-element tuple
  """
  @spec tuple(TypeDef.t(), TypeDef.t()) :: TypeDef.t()
  def tuple(t1, t2) do
    tuple([t1, t2])
  end

  @spec tuple(TypeDef.t(), TypeDef.t(), TypeDef.t()) :: TypeDef.t()
  def tuple(t1, t2, t3) do
    tuple([t1, t2, t3])
  end

  @spec tuple(TypeDef.t(), TypeDef.t(), TypeDef.t(), TypeDef.t()) :: TypeDef.t()
  def tuple(t1, t2, t3, t4) do
    tuple([t1, t2, t3, t4])
  end

  @spec tuple(TypeDef.t(), TypeDef.t(), TypeDef.t(), TypeDef.t(), TypeDef.t()) :: TypeDef.t()
  def tuple(t1, t2, t3, t4, t5) do
    tuple([t1, t2, t3, t4, t5])
  end

  @doc """
  Creates a record type (typed map with dynamic keys).

  A record is a map where all keys must match a key type and all values
  must match a value type. Useful for dictionaries or dynamic key-value stores.

  ## Examples

      # String keys, integer values
      ScoresSchema = record(string(), integer())
      # Input: {"math": 95, "english": 87} → Output: %{"math" => 95, "english" => 87}

      # String keys, nested tuple values
      ConfigSchema = record(string(), tuple(
        value: string(),
        enabled: boolean()
      ))
      # Input: {"feature_x": {"value": "foo", "enabled": true}}
      # Output: %{"feature_x" => %{value: "foo", enabled: true}}
  """
  @spec record(TypeDef.t(), TypeDef.t() | module()) :: TypeDef.t()
  def record(%TypeDef{} = key_type, value_type) do
    %TypeDef{
      kind: :record,
      key_type: key_type,
      value_type: normalize_type(value_type)
    }
  end

  @doc """
  Creates a literal type with allowed values.

  ## Examples

      literal(["on", "off"])
      literal([:pending, :active, :inactive])
      literal(["on", "off"]) |> transform(:boolean, decode: &(&1 == "on"), encode: ...)
  """
  @spec literal([any()]) :: TypeDef.t()
  def literal(values) when is_list(values) do
    %TypeDef{kind: :literal, values: values}
  end

  # ===========================================================================
  # Type Normalization Helpers
  # ===========================================================================

  # Normalize a type - handles TypeDef, module references, and inline tuples
  defp normalize_type(%TypeDef{} = type), do: type

  defp normalize_type(module) when is_atom(module) do
    %TypeDef{kind: :struct, schema: module}
  end

  defp normalize_type([{key, _} | _] = fields) when is_atom(key) do
    tuple(fields)
  end

  # Normalize fields for named tuple - each value can be TypeDef, module, or inline tuple
  defp normalize_fields(fields) do
    Enum.map(fields, fn {name, type} ->
      {name, normalize_type(type)}
    end)
  end

  # ===========================================================================
  # Constraint Functions
  # ===========================================================================

  @doc """
  Sets the minimum length (for strings/arrays) or minimum value (for numbers).

  Note: This shadows `Kernel.min/2`. If you need both, use:
      import Kernel, except: [min: 2, max: 2]
      import DataSchema.Builders

  ## Examples

      string() |> min(1)      # min length 1
      integer() |> min(0)     # min value 0
      array(string()) |> min(1)  # non-empty array
  """
  @spec min(TypeDef.t(), number()) :: TypeDef.t()
  def min(%TypeDef{} = type, value) do
    add_constraint(type, :min, value)
  end

  @doc """
  Sets the maximum length (for strings/arrays) or maximum value (for numbers).

  Note: This shadows `Kernel.max/2`. If you need both, use:
      import Kernel, except: [min: 2, max: 2]
      import DataSchema.Builders

  ## Examples

      string() |> max(100)    # max length 100
      integer() |> max(1000)  # max value 1000
      array(string()) |> max(10)  # max 10 elements
  """
  @spec max(TypeDef.t(), number()) :: TypeDef.t()
  def max(%TypeDef{} = type, value) do
    add_constraint(type, :max, value)
  end

  @doc """
  Sets a regex format constraint for strings.

  ## Examples

      string() |> format(~r/@/)
      string() |> format(~r/^[a-z]+$/)
  """
  @spec format(TypeDef.t(), Regex.t()) :: TypeDef.t()
  def format(%TypeDef{} = type, regex) do
    add_constraint(type, :format, regex)
  end

  @doc """
  Enables or disables whitespace trimming for strings.

  Trimming is enabled by default in the parser.

  ## Examples

      string() |> trim()        # Enable trimming
      string() |> trim(false)   # Disable trimming
  """
  @spec trim(TypeDef.t(), boolean()) :: TypeDef.t()
  def trim(%TypeDef{} = type, value \\ true) do
    add_constraint(type, :trim, value)
  end

  # ===========================================================================
  # Field Option Functions
  # ===========================================================================

  @doc """
  Marks the field as optional.

  ## Examples

      tuple(
        name: string(),
        age: integer() |> optional()
      )
  """
  @spec optional(TypeDef.t()) :: TypeDef.t()
  def optional(%TypeDef{} = type) do
    add_metadata(type, :optional, true)
  end

  @doc """
  Sets a default value for the field.

  ## Examples

      string() |> default("")
      array(string()) |> default([])
      integer() |> default(0)
  """
  @spec default(TypeDef.t(), any()) :: TypeDef.t()
  def default(%TypeDef{} = type, value) do
    add_metadata(type, :default, value)
  end

  @doc """
  Adds a description for documentation and export.

  ## Examples

      string() |> description("User's email address")
  """
  @spec description(TypeDef.t(), String.t()) :: TypeDef.t()
  def description(%TypeDef{} = type, desc) do
    add_metadata(type, :description, desc)
  end

  # ===========================================================================
  # Transform Function
  # ===========================================================================

  @doc """
  Adds a bidirectional transformation to the type.

  Transforms allow converting between input and internal representations.
  The transform runs AFTER type validation by default.

  ## Examples

      # String literal to boolean (runs AFTER literal validation)
      literal(["on", "off"]) |> transform(:boolean,
        decode: &(&1 == "on"),
        encode: &(if &1, do: "on", else: "off")
      )

      # String to Date
      string() |> transform(:date,
        decode: &Date.from_iso8601!/1,
        encode: &Date.to_iso8601/1
      )

  ## Options

  - `:decode` - Function to convert validated value to internal representation
  - `:encode` - Function to convert internal value to output representation
  - `:preprocess` - If true, decode runs BEFORE type validation (for input coercion)
  """
  @spec transform(TypeDef.t(), TypeDef.kind(), keyword()) :: TypeDef.t()
  def transform(%TypeDef{} = type, target, opts) when is_atom(target) do
    decode_fn = Keyword.fetch!(opts, :decode)
    encode_fn = Keyword.fetch!(opts, :encode)
    preprocess = Keyword.get(opts, :preprocess, false)

    %{
      type
      | transform: %{
          target: target,
          decode: decode_fn,
          encode: encode_fn,
          preprocess: preprocess
        }
    }
  end

  # ===========================================================================
  # Coercion
  # ===========================================================================

  @doc """
  Creates a coercion pipeline that converts from one type to another.

  Use `coerce/0` or `coerce/1` to start a coercion pipeline, then pipe
  to the target type. The coercion automatically handles type conversion.

  ## Examples

      # Coerce from any type (default)
      coerce() |> decimal()              # any → Decimal
      coerce() |> integer()              # any → integer
      coerce() |> string()               # any → string

      # Coerce from specific type
      coerce(string()) |> decimal()      # string → Decimal
      coerce(float()) |> integer()       # float → integer
      coerce(float()) |> string()        # float → string (for Excel IDs)

      # Chain with transforms
      coerce() |> decimal() |> abs()     # any → Decimal → absolute value
      coerce() |> decimal() |> negate()  # any → Decimal → negative

      # Full schema example
      sheet(%{
        tracking: [at: 0, type: coerce(float()) |> string()],
        amount:   [at: 1, type: coerce() |> decimal() |> abs()]
      })
  """
  @spec coerce(TypeDef.t()) :: TypeDef.t()
  def coerce(from_type \\ nil)
  def coerce(nil), do: %TypeDef{kind: :coerce, inner: any()}
  def coerce(%TypeDef{} = from_type), do: %TypeDef{kind: :coerce, inner: from_type}

  # Pipe target: coerce() |> decimal()
  @doc false
  @spec decimal(TypeDef.t()) :: TypeDef.t()
  def decimal(%TypeDef{kind: :coerce} = coerce_type) do
    build_coerced_type(coerce_type, :decimal, &coerce_to_decimal/1)
  end

  # Pipe target: coerce() |> string()
  @doc false
  @spec string(TypeDef.t()) :: TypeDef.t()
  def string(%TypeDef{kind: :coerce} = coerce_type) do
    build_coerced_type(coerce_type, :string, &coerce_to_string/1)
  end

  # Pipe target: coerce() |> integer()
  @doc false
  @spec integer(TypeDef.t()) :: TypeDef.t()
  def integer(%TypeDef{kind: :coerce} = coerce_type) do
    build_coerced_type(coerce_type, :integer, &coerce_to_integer/1)
  end

  # Pipe target: coerce() |> float()
  @doc false
  @spec float(TypeDef.t()) :: TypeDef.t()
  def float(%TypeDef{kind: :coerce} = coerce_type) do
    build_coerced_type(coerce_type, :float, &coerce_to_float/1)
  end

  defp build_coerced_type(%TypeDef{inner: from_type}, target_kind, coerce_fn) do
    %TypeDef{
      kind: target_kind,
      inner: from_type,
      transform: %{
        target: target_kind,
        decode: coerce_fn,
        encode: &identity/1,
        preprocess: true
      }
    }
  end

  defp identity(x), do: x

  # Coercion functions
  defp coerce_to_decimal(nil), do: nil

  defp coerce_to_decimal(%Decimal{} = value), do: value

  defp coerce_to_decimal(value) when is_float(value) do
    Decimal.from_float(value)
  end

  defp coerce_to_decimal(value) when is_integer(value) do
    Decimal.new(value)
  end

  defp coerce_to_decimal(value) when is_binary(value) do
    # Strip currency symbols, commas, and spaces
    cleaned =
      value
      |> String.trim()
      |> String.replace(~r/[$,\s]/, "")

    case Decimal.parse(cleaned) do
      {decimal, ""} -> decimal
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp coerce_to_decimal(_value), do: nil

  defp coerce_to_string(nil), do: nil

  defp coerce_to_string(value) when is_float(value) do
    # Check if it's a whole number (e.g., 6771806123.0)
    if value == Float.floor(value) do
      value |> trunc() |> Integer.to_string()
    else
      Float.to_string(value)
    end
  end

  defp coerce_to_string(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp coerce_to_string(value) when is_binary(value) do
    String.trim(value)
  end

  defp coerce_to_string(value), do: to_string(value)

  defp coerce_to_integer(nil), do: nil

  defp coerce_to_integer(value) when is_integer(value), do: value

  defp coerce_to_integer(value) when is_float(value) do
    trunc(value)
  end

  defp coerce_to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      {int, _} -> int
      :error -> nil
    end
  end

  defp coerce_to_integer(_value), do: nil

  defp coerce_to_float(nil), do: nil

  defp coerce_to_float(value) when is_float(value), do: value

  defp coerce_to_float(value) when is_integer(value) do
    value * 1.0
  end

  defp coerce_to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      {float, _} -> float
      :error -> nil
    end
  end

  defp coerce_to_float(_value), do: nil

  # ===========================================================================
  # Numeric Transforms
  # ===========================================================================

  @doc """
  Takes the absolute value of a Decimal.

  Must be used after `decimal()` in the pipeline.

  ## Examples

      coerce() |> decimal() |> abs()
      # -50.0 → Decimal.new("50")
  """
  @spec abs(TypeDef.t()) :: TypeDef.t()
  def abs(%TypeDef{transform: existing_transform} = type) do
    # Compose with existing transform if present
    abs_fn = fn
      nil -> nil
      %Decimal{} = d -> Decimal.abs(d)
      other -> other
    end

    new_decode =
      if existing_transform && existing_transform.decode do
        fn value ->
          value
          |> existing_transform.decode.()
          |> abs_fn.()
        end
      else
        abs_fn
      end

    %{
      type
      | transform: %{
          target: :decimal,
          decode: new_decode,
          encode: fn value -> value end,
          preprocess: existing_transform && existing_transform.preprocess
        }
    }
  end

  @doc """
  Negates a Decimal value (ensures it's negative).

  Takes the absolute value first, then negates. This ensures the result
  is always negative regardless of input sign.

  Must be used after `decimal()` in the pipeline.

  ## Examples

      coerce() |> decimal() |> negate()
      # 50.0 → Decimal.new("-50")
      # -50.0 → Decimal.new("-50")
  """
  @spec negate(TypeDef.t()) :: TypeDef.t()
  def negate(%TypeDef{transform: existing_transform} = type) do
    # Compose with existing transform if present
    negate_fn = fn
      nil -> nil
      %Decimal{} = d -> d |> Decimal.abs() |> Decimal.negate()
      other -> other
    end

    new_decode =
      if existing_transform && existing_transform.decode do
        fn value ->
          value
          |> existing_transform.decode.()
          |> negate_fn.()
        end
      else
        negate_fn
      end

    %{
      type
      | transform: %{
          target: :decimal,
          decode: new_decode,
          encode: fn value -> value end,
          preprocess: existing_transform && existing_transform.preprocess
        }
    }
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp add_constraint(%TypeDef{constraints: constraints} = type, key, value) do
    %{type | constraints: Keyword.put(constraints, key, value)}
  end

  defp add_metadata(%TypeDef{metadata: metadata} = type, key, value) do
    %{type | metadata: Keyword.put(metadata, key, value)}
  end
end
