defmodule Raggio.Schema do
  @moduledoc """
  Composable schema definition and validation library.

  Provides function-based API for defining data schemas and validating data
  without complex macro syntax.
  """

  defstruct [:type, :constraints, :validators, :fields, :metadata, :default, :optional]

  @type t :: %__MODULE__{
          type: atom(),
          constraints: list(),
          validators: list(),
          fields: list() | nil,
          metadata: map(),
          default: any(),
          optional: boolean()
        }

  # Primitive type constructors

  @doc """
  Create a string type schema.
  """
  def string do
    %__MODULE__{
      type: :string,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create an integer type schema.
  """
  def integer do
    %__MODULE__{
      type: :integer,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a float type schema.
  """
  def float do
    %__MODULE__{
      type: :float,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a boolean type schema.
  """
  def boolean do
    %__MODULE__{
      type: :boolean,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a date type schema.
  """
  def date do
    %__MODULE__{
      type: :date,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a datetime type schema.
  """
  def datetime do
    %__MODULE__{
      type: :datetime,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a decimal type schema.
  """
  def decimal do
    %__MODULE__{
      type: :decimal,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create an atom type schema.
  """
  def atom do
    %__MODULE__{
      type: :atom,
      constraints: [],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  # Composite type constructors

  @doc """
  Create an array type schema with specified element type.
  """
  def array(element_schema) when is_struct(element_schema, __MODULE__) do
    %__MODULE__{
      type: :array,
      constraints: [],
      validators: [],
      fields: [element: element_schema],
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a struct type schema with defined fields.
  """
  def struct(fields) when is_list(fields) do
    %__MODULE__{
      type: :struct,
      constraints: [],
      validators: [],
      fields: fields,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create an enum type schema with allowed values.
  """
  def enum(values) when is_list(values) do
    %__MODULE__{
      type: :enum,
      constraints: [values: values],
      validators: [],
      fields: nil,
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  @doc """
  Create a union type schema (value matches one of provided schemas).
  """
  def union(schemas) when is_list(schemas) do
    %__MODULE__{
      type: :union,
      constraints: [],
      validators: [],
      fields: [schemas: schemas],
      metadata: %{},
      default: nil,
      optional: false
    }
  end

  # String constraints

  @doc """
  Add minimum length constraint to string or array schema.
  """
  def min_length(schema = %__MODULE__{}, n) when is_integer(n) and n >= 0 do
    if schema.type in [:string, :array] do
      %{schema | constraints: [{:min_length, n} | schema.constraints]}
    else
      raise_composition_error(schema.type, "min_length requires string or array type")
    end
  end

  @doc """
  Add maximum length constraint to string or array schema.
  """
  def max_length(schema = %__MODULE__{}, n) when is_integer(n) and n >= 0 do
    if schema.type in [:string, :array] do
      %{schema | constraints: [{:max_length, n} | schema.constraints]}
    else
      raise_composition_error(schema.type, "max_length requires string or array type")
    end
  end

  @doc """
  Add pattern matching constraint to string schema.
  """
  def pattern(schema = %__MODULE__{type: :string}, regex) do
    %{schema | constraints: [{:pattern, regex} | schema.constraints]}
  end

  def pattern(schema = %__MODULE__{}, _regex) do
    raise_composition_error(schema.type, "pattern requires string type")
  end

  @doc """
  Add email format constraint to string schema.
  """
  def email(schema = %__MODULE__{type: :string}) do
    email_regex = ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
    %{schema | constraints: [{:email, email_regex} | schema.constraints]}
  end

  def email(schema = %__MODULE__{}) do
    raise_composition_error(schema.type, "email requires string type")
  end

  # Numeric constraints

  @doc """
  Add minimum value constraint to numeric schema.
  """
  def min(schema = %__MODULE__{}, value) when is_number(value) do
    if schema.type in [:integer, :float, :decimal] do
      %{schema | constraints: [{:min, value} | schema.constraints]}
    else
      raise_composition_error(schema.type, "min requires numeric type")
    end
  end

  @doc """
  Add maximum value constraint to numeric schema.
  """
  def max(schema = %__MODULE__{}, value) when is_number(value) do
    if schema.type in [:integer, :float, :decimal] do
      %{schema | constraints: [{:max, value} | schema.constraints]}
    else
      raise_composition_error(schema.type, "max requires numeric type")
    end
  end

  @doc """
  Add positive number constraint to numeric schema.
  """
  def positive(schema = %__MODULE__{}) do
    if schema.type in [:integer, :float, :decimal] do
      %{schema | constraints: [{:positive, true} | schema.constraints]}
    else
      raise_composition_error(schema.type, "positive requires numeric type")
    end
  end

  @doc """
  Add range constraint to numeric schema.
  """
  def range(schema = %__MODULE__{}, min_val, max_val)
      when is_number(min_val) and is_number(max_val) do
    if schema.type in [:integer, :float, :decimal] do
      %{schema | constraints: [{:range, {min_val, max_val}} | schema.constraints]}
    else
      raise_composition_error(schema.type, "range requires numeric type")
    end
  end

  # Composition functions

  @doc """
  Mark schema as optional (allow nil value).
  """
  def optional(schema = %__MODULE__{}) do
    %{schema | optional: true}
  end

  @doc """
  Add default value to schema.
  """
  def default(schema = %__MODULE__{}, value) do
    %{schema | default: value}
  end

  # Validation function

  @doc """
  Validate data against schema.

  Returns `{:ok, validated_data}` on success or `{:error, [errors]}` on failure.
  """
  def validate(schema = %__MODULE__{}, data) do
    Raggio.Schema.Validator.validate(schema, data)
  end

  @doc """
  Validate data against schema, raise on error.
  """
  def validate!(schema = %__MODULE__{}, data) do
    case validate(schema, data) do
      {:ok, validated} -> validated
      {:error, errors} -> raise Raggio.Schema.ValidationError, errors: errors
    end
  end

  # Helper functions

  defp raise_composition_error(type, message) do
    raise Raggio.Schema.CompositionError,
      message: message,
      left_type: type,
      right_type: nil
  end
end
