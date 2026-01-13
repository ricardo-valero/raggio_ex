defmodule Raggio.Schema do
  @moduledoc """
  Composable schema definition and validation library.

  Raggio.Schema provides a function-based API for defining data schemas and validating data.
  Type constructors accept keyword options for constraints:

      Schema.string(min: 3, max: 20)
      Schema.integer(min: 0, max: 100)
      Schema.list(Schema.string(), min: 1, unique: true)

      Schema.struct([
        {:name, Schema.string(min: 1)},
        {:age, Schema.integer(min: 0)},
        {:email, Schema.optional(Schema.string(pattern: Schema.email()))}
      ])

  Core Constraints: min, max, pattern, unique
  Field Descriptors: optional/1, nullable/1, default: keyword option
  """

  defstruct [
    :type,
    :encoded,
    :inner_type,
    :types,
    :values,
    constraints: [],
    fields: nil,
    optional: false,
    nullable: false,
    default: nil,
    annotations: %{}
  ]

  @type t :: %__MODULE__{
          type: atom(),
          encoded: atom() | nil,
          constraints: keyword(),
          fields: [{atom(), t()}] | nil,
          inner_type: t() | nil,
          types: [t()] | nil,
          values: [any()] | nil,
          optional: boolean(),
          nullable: boolean(),
          default: any(),
          annotations: map()
        }

  @type validation_result :: {:ok, any()} | {:error, [validation_error()]}

  @type validation_error :: %{
          path: [atom() | integer()],
          message: String.t(),
          value: any(),
          constraint: atom() | nil
        }

  def string(opts \\ []) do
    {constraints, other_opts} = extract_constraints(opts, [:min, :max, :pattern])

    %__MODULE__{
      type: :string,
      encoded: :string,
      constraints: constraints,
      default: Keyword.get(other_opts, :default)
    }
  end

  def integer(opts \\ []) do
    {constraints, other_opts} = extract_constraints(opts, [:min, :max])

    %__MODULE__{
      type: :integer,
      encoded: :integer,
      constraints: constraints,
      default: Keyword.get(other_opts, :default)
    }
  end

  def float(opts \\ []) do
    {constraints, other_opts} = extract_constraints(opts, [:min, :max])

    %__MODULE__{
      type: :float,
      encoded: :float,
      constraints: constraints,
      default: Keyword.get(other_opts, :default)
    }
  end

  def boolean(opts \\ []) do
    %__MODULE__{
      type: :boolean,
      encoded: :boolean,
      default: Keyword.get(opts, :default)
    }
  end

  def date(opts \\ []) do
    %__MODULE__{
      type: :date,
      encoded: :date,
      default: Keyword.get(opts, :default)
    }
  end

  def datetime(opts \\ []) do
    %__MODULE__{
      type: :datetime,
      encoded: :datetime,
      default: Keyword.get(opts, :default)
    }
  end

  def decimal(opts \\ []) do
    {constraints, other_opts} = extract_constraints(opts, [:min, :max])

    %__MODULE__{
      type: :decimal,
      encoded: :decimal,
      constraints: constraints,
      default: Keyword.get(other_opts, :default)
    }
  end

  def atom(opts \\ []) do
    %__MODULE__{
      type: :atom,
      encoded: :atom,
      default: Keyword.get(opts, :default)
    }
  end

  def struct(fields) when is_list(fields) do
    %__MODULE__{
      type: :struct,
      encoded: :map,
      fields: fields
    }
  end

  def list(inner_schema, opts \\ [])

  def list(inner_schema, opts) when is_struct(inner_schema, __MODULE__) do
    {constraints, other_opts} = extract_constraints(opts, [:min, :max, :unique])

    %__MODULE__{
      type: :list,
      encoded: :list,
      inner_type: inner_schema,
      constraints: constraints,
      default: Keyword.get(other_opts, :default)
    }
  end

  def tuple(schemas) when is_list(schemas) do
    %__MODULE__{
      type: :tuple,
      encoded: :tuple,
      types: schemas
    }
  end

  def union(schemas) when is_list(schemas) and length(schemas) >= 2 do
    %__MODULE__{
      type: :union,
      encoded: :any,
      types: schemas
    }
  end

  def literal(value) do
    %__MODULE__{
      type: :literal,
      encoded: :any,
      values: [value]
    }
  end

  def literal(value1, value2) do
    %__MODULE__{
      type: :literal,
      encoded: :any,
      values: [value1, value2]
    }
  end

  def literal(value1, value2, value3) do
    %__MODULE__{
      type: :literal,
      encoded: :any,
      values: [value1, value2, value3]
    }
  end

  def literal(value1, value2, value3, value4) do
    %__MODULE__{
      type: :literal,
      encoded: :any,
      values: [value1, value2, value3, value4]
    }
  end

  def literal(value1, value2, value3, value4, value5) do
    %__MODULE__{
      type: :literal,
      encoded: :any,
      values: [value1, value2, value3, value4, value5]
    }
  end

  def record(key_schema, value_schema)
      when is_struct(key_schema, __MODULE__) and is_struct(value_schema, __MODULE__) do
    %__MODULE__{
      type: :record,
      encoded: :map,
      fields: [key: key_schema, value: value_schema]
    }
  end

  def optional(schema) when is_struct(schema, __MODULE__) do
    %{schema | optional: true}
  end

  def nullable(schema) when is_struct(schema, __MODULE__) do
    %{schema | nullable: true}
  end

  def email do
    ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
  end

  def url do
    ~r/^https?:\/\/.+/
  end

  def uuid do
    ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  end

  def annotate(schema, annotations) when is_struct(schema, __MODULE__) and is_map(annotations) do
    %{schema | annotations: Map.merge(schema.annotations, annotations)}
  end

  def validate(schema, data) when is_struct(schema, __MODULE__) do
    Raggio.Schema.Validator.validate(schema, data)
  end

  def validate(schema, data, opts) when is_struct(schema, __MODULE__) and is_list(opts) do
    Raggio.Schema.Validator.validate(schema, data, opts)
  end

  def validate!(schema, data) when is_struct(schema, __MODULE__) do
    case validate(schema, data) do
      {:ok, validated} -> validated
      {:error, errors} -> raise Raggio.Schema.ValidationError, errors: errors
    end
  end

  defp extract_constraints(opts, constraint_keys) do
    constraints =
      opts
      |> Keyword.take(constraint_keys)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    other_opts = Keyword.drop(opts, constraint_keys)

    {constraints, other_opts}
  end
end
