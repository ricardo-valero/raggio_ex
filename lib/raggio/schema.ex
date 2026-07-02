defmodule Raggio.Schema do
  @moduledoc """
  Composable schema definition and data validation.

  Define schemas using type constructors and validate data against them.
  """

  alias Raggio.Schema.{AST, Check, Context, Error, Validator}

  @type t :: AST.t()
  @type validation_result :: {:ok, any()} | {:error, [Error.t()]}

  def string(), do: %AST{kind: :string}

  def string(opts) when is_list(opts),
    do: %AST{kind: :string, checks: string_checks(opts)}

  def string(default), do: %AST{kind: :string, context: %Context{default: default}}

  def string(default, opts),
    do: %AST{kind: :string, checks: string_checks(opts), context: %Context{default: default}}

  def integer(), do: %AST{kind: :integer}

  def integer(opts) when is_list(opts),
    do: %AST{kind: :integer, checks: number_checks(opts)}

  def integer(default), do: %AST{kind: :integer, context: %Context{default: default}}

  def integer(default, opts),
    do: %AST{kind: :integer, checks: number_checks(opts), context: %Context{default: default}}

  def float(), do: %AST{kind: :float}

  def float(opts) when is_list(opts),
    do: %AST{kind: :float, checks: number_checks(opts)}

  def float(default), do: %AST{kind: :float, context: %Context{default: default}}

  def float(default, opts),
    do: %AST{kind: :float, checks: number_checks(opts), context: %Context{default: default}}

  def boolean(), do: %AST{kind: :boolean}
  def boolean(opts) when is_list(opts), do: %AST{kind: :boolean}
  def boolean(default), do: %AST{kind: :boolean, context: %Context{default: default}}

  def date(), do: %AST{kind: :date}
  def date(opts) when is_list(opts), do: %AST{kind: :date}
  def date(default), do: %AST{kind: :date, context: %Context{default: default}}

  def datetime(), do: %AST{kind: :datetime}
  def datetime(opts) when is_list(opts), do: %AST{kind: :datetime}
  def datetime(default), do: %AST{kind: :datetime, context: %Context{default: default}}

  def decimal(), do: %AST{kind: :decimal}
  def decimal(opts) when is_list(opts), do: %AST{kind: :decimal}
  def decimal(default), do: %AST{kind: :decimal, context: %Context{default: default}}
  def decimal(default, _opts), do: %AST{kind: :decimal, context: %Context{default: default}}

  def atom(), do: %AST{kind: :atom}
  def atom(opts) when is_list(opts), do: %AST{kind: :atom}
  def atom(default), do: %AST{kind: :atom, context: %Context{default: default}}

  def struct(fields) when is_list(fields) do
    %AST{kind: :struct, fields: fields}
  end

  def list(inner_schema, opts \\ []) do
    %AST{
      kind: :list,
      inner: inner_schema,
      checks: list_checks(opts),
      context: %Context{default: Keyword.get(opts, :default, :none)}
    }
  end

  def tuple(schemas) when is_list(schemas) do
    %AST{kind: :tuple, elements: schemas}
  end

  def union(schemas) when is_list(schemas) and length(schemas) >= 2 do
    %AST{kind: :union, elements: schemas}
  end

  def literal(value), do: %AST{kind: :literal, values: [value]}
  def literal(value1, value2), do: %AST{kind: :literal, values: [value1, value2]}

  def literal(value1, value2, value3),
    do: %AST{kind: :literal, values: [value1, value2, value3]}

  def record(key_schema, value_schema) do
    %AST{kind: :record, key_type: key_schema, value_type: value_schema}
  end

  def optional(%AST{context: ctx} = schema) do
    %{schema | context: %{ctx | optional?: true}}
  end

  def nullable(%AST{context: ctx} = schema) do
    %{schema | context: %{ctx | nullable?: true}}
  end

  @doc """
  Attach a custom refinement: `predicate` runs after the type matches; on `false` the
  validation fails with `message` (constraint tag `:refine`). Pipe-friendly:

      Schema.integer() |> Schema.refine(&(rem(&1, 2) == 0), "must be even")
  """
  def refine(%AST{checks: checks} = schema, predicate, message)
      when is_function(predicate, 1) and is_binary(message) do
    check = %Check{
      constraint: :refine,
      meta: %{},
      run: fn value -> if predicate.(value), do: :ok, else: {:error, message} end
    }

    %{schema | checks: checks ++ [check]}
  end

  @doc "Attach a prebuilt `Raggio.Schema.Check` to a schema."
  def check(%AST{checks: checks} = schema, %Check{} = check) do
    %{schema | checks: checks ++ [check]}
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

  # --- lowering: surface options → checks ----------------------------------

  defp string_checks(opts) do
    []
    |> append_if(opts[:min], &Check.min_length/1)
    |> append_if(opts[:max], &Check.max_length/1)
    |> append_if(opts[:pattern], &Check.pattern/1)
    |> append_if(opts[:length], &Check.exact_length/1)
    |> append_if(opts[:starts_with], &Check.starts_with/1)
    |> append_if(opts[:ends_with], &Check.ends_with/1)
    |> append_if(opts[:includes], &Check.includes/1)
    |> append_if(opts[:format], &Check.format/1)
    |> append_flag(opts[:non_empty], &Check.non_empty_string/0)
    |> append_flag(opts[:uppercase], &Check.uppercase/0)
    |> append_flag(opts[:lowercase], &Check.lowercase/0)
  end

  defp number_checks(opts) do
    []
    |> append_if(opts[:min], &Check.min_value/1)
    |> append_if(opts[:max], &Check.max_value/1)
    |> append_if(opts[:greater_than] || opts[:gt], &Check.greater_than/1)
    |> append_if(opts[:less_than] || opts[:lt], &Check.less_than/1)
    |> append_if(opts[:multiple_of], &Check.multiple_of/1)
    |> append_flag(opts[:int], &Check.int/0)
  end

  defp list_checks(opts) do
    []
    |> append_if(opts[:min], &Check.min_items/1)
    |> append_if(opts[:max], &Check.max_items/1)
    |> append_flag(opts[:unique], &Check.unique_items/0)
    |> append_flag(opts[:non_empty], &Check.non_empty_list/0)
  end

  defp append_if(checks, nil, _builder), do: checks
  defp append_if(checks, value, builder), do: checks ++ [builder.(value)]

  defp append_flag(checks, true, builder), do: checks ++ [builder.()]
  defp append_flag(checks, _falsy, _builder), do: checks
end
