defmodule Manuable.DataSchema do
  @moduledoc """
  A declarative schema library for data parsing, validation, and transformation.

  Provides composable type builders, nested struct support, bidirectional
  transformations (decode/encode), and human-readable error messages.

  ## Usage

      defmodule MyApp.UserSchema do
        use DataSchema

        import DataSchema.Builders

        @schema tuple(
          name: string() |> min_value(1) |> max_value(100),
          email: string() |> format(~r/@/),
          age: integer() |> min_value(0) |> optional(),
          active: boolean() |> default(true)
        )
      end

      # Parse data
      {:ok, parsed} = MyApp.UserSchema.parse(%{name: "John", email: "john@example.com"})
      {:error, errors} = MyApp.UserSchema.parse(%{name: ""})

      # Encode data
      {:ok, encoded} = MyApp.UserSchema.encode(parsed)

  ## Inline Schemas

  You can also use schemas inline without defining a module:

      import DataSchema.Builders

      PersonSchema = tuple(
        name: string() |> min_value(1),
        age: integer() |> optional()
      )

      {:ok, parsed} = DataSchema.parse(%{"name" => "John"}, PersonSchema)

  ## Schema Types

  - `tuple(field: type, ...)` - Named tuple (from object/map input)
  - `tuple(type, type, ...)` - Positional tuple (from array input)
  - `record(key_type, value_type)` - Typed map with dynamic keys

  ## Generated Functions

  When you `use DataSchema` and define a `@schema`, these functions are generated:

  - `parse/1` - Parses input data, returns `{:ok, map}` or `{:error, [ParseError.t()]}`
  - `parse!/1` - Parses input data, raises on error
  - `encode/1` - Encodes parsed data to external representation
  - `encode!/1` - Encodes data, raises on error
  - `__schema__/0` - Returns the schema TypeDef
  """

  alias Manuable.DataSchema.Builders.TypeDef
  alias Manuable.DataSchema.ParseError
  alias Manuable.DataSchema.Parser
  alias Manuable.DataSchema.Transformer

  # ============================================================================
  # Module-level API (for inline usage without defining a module)
  # ============================================================================

  @doc """
  Parses input data against a schema.

  ## Parameters

  - `data` - Input data (map, list, etc.)
  - `schema` - A `%TypeDef{}` schema (from `tuple()`, `record()`, etc.)

  ## Returns

  - `{:ok, parsed_data}` - Data parsed successfully
  - `{:error, [ParseError.t()]}` - One or more fields failed parsing

  ## Example

      import DataSchema.Builders

      schema = tuple(
        name: string() |> min_value(1),
        age: integer() |> optional()
      )

      {:ok, parsed} = DataSchema.parse(%{"name" => "John"}, schema)
  """
  @spec parse(any(), TypeDef.t()) :: {:ok, any()} | {:error, [ParseError.t()]}
  def parse(data, %TypeDef{} = schema) do
    Parser.parse(data, schema)
  end

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
  @spec encode(any(), TypeDef.t(), keyword()) ::
          {:ok, any()} | {:error, [ParseError.t()]}
  def encode(data, %TypeDef{} = schema, opts \\ []) do
    Transformer.encode(data, schema, opts)
  end

  # ============================================================================
  # Record Builder
  # ============================================================================

  @doc """
  Builds a new record map from attributes based on schema definition.

  - Required fields: fetched with Map.fetch! (raises if missing)
  - Optional fields: fetched with Map.get (nil if missing)
  - Fields with defaults: default evaluated if field is nil/missing
    - 0-arity function: called with no args
    - 1-arity function: called with the accumulated attrs map
    - Static value: used as-is
  """
  @spec build_new(map(), TypeDef.t()) :: map()
  def build_new(attrs, %TypeDef{kind: :tuple, fields: fields}) when is_list(fields) do
    # First pass: collect all values (required fields and provided optional fields)
    # This allows 1-arity defaults to access other field values
    base_map =
      Enum.reduce(fields, %{}, fn {field_name, type_def}, acc ->
        value = get_field_value(attrs, field_name, type_def)
        Map.put(acc, field_name, value)
      end)

    # Second pass: evaluate defaults that need the full attrs map
    Enum.reduce(fields, base_map, fn {field_name, type_def}, acc ->
      maybe_apply_default(acc, field_name, type_def)
    end)
  end

  defp maybe_apply_default(acc, field_name, type_def) do
    value = Map.get(acc, field_name)

    if is_nil(value) and TypeDef.has_default?(type_def) do
      Map.put(acc, field_name, TypeDef.evaluate_default(type_def, acc))
    else
      acc
    end
  end

  defp get_field_value(attrs, field_name, type_def) do
    is_optional = TypeDef.optional?(type_def)
    has_default = TypeDef.has_default?(type_def)

    cond do
      # Required field without default - must be present
      not is_optional and not has_default ->
        Map.fetch!(attrs, field_name)

      # Has a value in attrs - use it
      Map.has_key?(attrs, field_name) ->
        Map.get(attrs, field_name)

      # Optional or has default - will be filled in second pass or left nil
      true ->
        nil
    end
  end

  # ============================================================================
  # Macro-based DSL
  # ============================================================================

  @doc """
  Use this module to define a data schema.

  ## Example

      defmodule MySchema do
        use DataSchema

        import DataSchema.Builders

        @schema tuple(
          name: string() |> min_value(1),
          age: integer() |> optional()
        )
      end
  """
  defmacro __using__(_opts) do
    quote do
      @before_compile DataSchema
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_schema_attr = Module.has_attribute?(env.module, :schema)
    has_schema_fn = Module.defines?(env.module, {:schema, 0})

    cond do
      has_schema_fn -> generate_function_based_schema()
      has_schema_attr -> generate_attribute_based_schema()
      true -> generate_empty_functions()
    end
  end

  # When schema is defined as a function - supports inline anonymous functions
  defp generate_function_based_schema do
    quote do
      alias Manuable.DataSchema.Builders.TypeDef
      alias Manuable.DataSchema.{ParseError, Parser, Transformer}

      @spec parse(any()) :: {:ok, any()} | {:error, [ParseError.t()]}
      def parse(data), do: Parser.parse(data, schema())

      @spec parse!(any()) :: any()
      def parse!(data), do: unwrap_or_raise(parse(data))

      @spec encode(any(), keyword()) :: {:ok, any()} | {:error, [ParseError.t()]}
      def encode(data, opts \\ []), do: Transformer.encode(data, schema(), opts)

      @spec encode!(any(), keyword()) :: any()
      def encode!(data, opts \\ []), do: unwrap_or_raise(encode(data, opts))

      @spec new(map()) :: map()
      def new(attrs) when is_map(attrs) do
        DataSchema.build_new(attrs, schema())
      end

      @spec __schema__() :: TypeDef.t()
      def __schema__, do: schema()

      defp unwrap_or_raise({:ok, result}), do: result
      defp unwrap_or_raise({:error, errors}), do: raise(ParseError.format_errors(errors))
    end
  end

  # When schema is defined as @schema attribute - no inline anonymous functions
  defp generate_attribute_based_schema do
    quote do
      alias Manuable.DataSchema.Builders.TypeDef
      alias Manuable.DataSchema.{ParseError, Parser, Transformer}

      @spec parse(any()) :: {:ok, any()} | {:error, [ParseError.t()]}
      def parse(data), do: Parser.parse(data, @schema)

      @spec parse!(any()) :: any()
      def parse!(data), do: unwrap_or_raise(parse(data))

      @spec encode(any(), keyword()) :: {:ok, any()} | {:error, [ParseError.t()]}
      def encode(data, opts \\ []), do: Transformer.encode(data, @schema, opts)

      @spec encode!(any(), keyword()) :: any()
      def encode!(data, opts \\ []), do: unwrap_or_raise(encode(data, opts))

      @spec new(map()) :: map()
      def new(attrs) when is_map(attrs) do
        DataSchema.build_new(attrs, @schema)
      end

      @spec __schema__() :: TypeDef.t()
      def __schema__, do: @schema

      defp unwrap_or_raise({:ok, result}), do: result
      defp unwrap_or_raise({:error, errors}), do: raise(ParseError.format_errors(errors))
    end
  end

  defp generate_empty_functions do
    quote do
      def parse(_data), do: {:error, [%{message: "No @schema or schema/0 defined"}]}
      def encode(_data, _opts \\ []), do: {:error, [%{message: "No @schema or schema/0 defined"}]}
      def new(_attrs), do: raise("No @schema or schema/0 defined")
      def __schema__, do: nil
    end
  end
end
