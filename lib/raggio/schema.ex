defmodule Raggio.Schema do
  @moduledoc """
  Composable schema definition and data validation.

  Define schemas using type constructors and validate data against them.
  """

  alias Raggio.Schema.{Type, Error, Validator}

  @type t :: Type.t()
  @type validation_result :: {:ok, any()} | {:error, [Error.t()]}

  def string(opts \\ []) do
    %Type{
      kind: :string,
      constraints: Keyword.take(opts, [:min, :max, :pattern]),
      default: Keyword.get(opts, :default)
    }
  end

  def integer(opts \\ []) do
    %Type{
      kind: :integer,
      constraints: Keyword.take(opts, [:min, :max]),
      default: Keyword.get(opts, :default)
    }
  end

  def float(opts \\ []) do
    %Type{
      kind: :float,
      constraints: Keyword.take(opts, [:min, :max]),
      default: Keyword.get(opts, :default)
    }
  end

  def boolean(opts \\ []) do
    %Type{
      kind: :boolean,
      default: Keyword.get(opts, :default)
    }
  end

  def date(opts \\ []) do
    %Type{
      kind: :date,
      default: Keyword.get(opts, :default)
    }
  end

  def datetime(opts \\ []) do
    %Type{
      kind: :datetime,
      default: Keyword.get(opts, :default)
    }
  end

  def decimal(opts \\ []) do
    %Type{
      kind: :decimal,
      constraints: Keyword.take(opts, [:min, :max]),
      default: Keyword.get(opts, :default)
    }
  end

  def atom(opts \\ []) do
    %Type{
      kind: :atom,
      default: Keyword.get(opts, :default)
    }
  end

  def struct(fields) when is_list(fields) do
    %Type{
      kind: :struct,
      fields: fields
    }
  end

  def list(inner_schema, opts \\ []) do
    %Type{
      kind: :list,
      inner: inner_schema,
      constraints: Keyword.take(opts, [:min, :max, :unique]),
      default: Keyword.get(opts, :default)
    }
  end

  def tuple(schemas) when is_list(schemas) do
    %Type{
      kind: :tuple,
      elements: schemas
    }
  end

  def union(schemas) when is_list(schemas) and length(schemas) >= 2 do
    %Type{
      kind: :union,
      elements: schemas
    }
  end

  def literal(value) do
    %Type{
      kind: :literal,
      values: [value]
    }
  end

  def literal(value1, value2) do
    %Type{
      kind: :literal,
      values: [value1, value2]
    }
  end

  def literal(value1, value2, value3) do
    %Type{
      kind: :literal,
      values: [value1, value2, value3]
    }
  end

  def record(key_schema, value_schema) do
    %Type{
      kind: :record,
      key_type: key_schema,
      value_type: value_schema
    }
  end

  def optional(%Type{} = schema) do
    %{schema | optional: true}
  end

  def nullable(%Type{} = schema) do
    %{schema | nullable: true}
  end

  def email do
    ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  end

  def url do
    ~r/^https?:\/\/[^\s\/$.?#].[^\s]*$/i
  end

  def uuid do
    ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  end

  def validate(schema, data) do
    Validator.validate(schema, data)
  end

  def validate(schema, data, opts) do
    Validator.validate(schema, data, opts)
  end

  def validate!(schema, data) do
    case validate(schema, data) do
      {:ok, result} -> result
      {:error, errors} -> raise Raggio.Schema.ValidationError, errors: errors
    end
  end
end
