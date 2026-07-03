defmodule Raggio.Schema do
  @moduledoc """
  Composable schema definition and data validation.

  Define schemas using type constructors and validate data against them. For
  module-backed schemas (a named struct, enum, or union with `@type t` and
  `decode`/`encode` functions), `use Raggio.Schema` and declare one schema
  expression — see `Raggio.Schema.Definition`:

      defmodule Status do
        use Raggio.Schema

        schema do
          literal ["on", "off"]
        end
      end

      defmodule Device do
        use Raggio.Schema

        schema do
          struct name: Schema.string(min: 1),
                 status: Status
        end
      end
  """

  alias Raggio.Schema.{AST, Check, Context, Encoder, Error, Transformation, Validator}

  defmacro __using__(_opts) do
    quote do
      import Raggio.Schema.Definition, only: [schema: 1]
      alias Raggio.Schema
    end
  end

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

  @doc "Any number — accepts integers and floats, preserving each (effect's `Number`)."
  def number(), do: %AST{kind: :number}

  def number(opts) when is_list(opts),
    do: %AST{kind: :number, checks: number_checks(opts)}

  def number(default), do: %AST{kind: :number, context: %Context{default: default}}

  def number(default, opts),
    do: %AST{kind: :number, checks: number_checks(opts), context: %Context{default: default}}

  @doc "Accepts anything (effect's `Any`/`Unknown`). Useful as a transform base or escape hatch."
  def any(), do: %AST{kind: :any}

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

  @doc """
  A struct (map) schema over ordered `{field, schema}` pairs.

  Decoding **rebuilds** the value from the declared fields (effect's Type projection):
  decoded/transformed field values and applied defaults are in the output; undeclared
  keys are dropped; absent optional fields stay absent. Pass `module: Mod` to bind a
  target struct — decode then returns `%Mod{}` instead of a plain map.

  A field's schema may be a **module** exporting `__schema__/0` (a `Raggio.Schema.Struct`
  or `Raggio.Schema.Literal` module) — it is resolved on construction.
  """
  def struct(fields, opts \\ []) when is_list(fields) do
    resolved = Enum.map(fields, fn {name, schema} -> {name, resolve(schema)} end)
    %AST{kind: :struct, fields: resolved, module: Keyword.get(opts, :module)}
  end

  def list(inner_schema, opts \\ []) do
    %AST{
      kind: :list,
      inner: resolve(inner_schema),
      checks: list_checks(opts),
      context: %Context{default: Keyword.get(opts, :default, :none)}
    }
  end

  def tuple(schemas) when is_list(schemas) do
    %AST{kind: :tuple, elements: Enum.map(schemas, &resolve/1)}
  end

  def union(schemas) when is_list(schemas) and length(schemas) >= 2 do
    %AST{kind: :union, elements: Enum.map(schemas, &resolve/1)}
  end

  @doc """
  A **tagged** union over struct schemas, discriminated on `discriminator`
  (effect's `Union |> toTaggedUnion`). Each member MUST declare the discriminator
  as a literal field — an invalid member raises at construction. Decode reads the
  discriminator from the input and dispatches to the single matching member, so
  errors come from that member (not "tried them all").

      Schema.union(:name, [Fedex, Imile])
  """
  def union(discriminator, members)
      when is_atom(discriminator) and is_list(members) and length(members) >= 2 do
    resolved = Enum.map(members, &resolve/1)
    Enum.each(resolved, &validate_tagged_member!(&1, discriminator))
    %AST{kind: :union, elements: resolved, discriminator: discriminator}
  end

  defp validate_tagged_member!(%AST{kind: :struct, fields: fields} = member, disc) do
    case List.keyfind(fields || [], disc, 0) do
      {^disc, %AST{kind: :literal}} ->
        :ok

      _ ->
        raise ArgumentError,
              "tagged union member #{inspect(member.module || member)} must declare " <>
                "the discriminator #{inspect(disc)} as a literal field"
    end
  end

  defp validate_tagged_member!(member, disc) do
    raise ArgumentError,
          "tagged union members must be struct schemas with a literal #{inspect(disc)} " <>
            "field, got: #{inspect(member.kind)}"
  end

  @doc """
  An opaque custom type backed by a module implementing the
  `Raggio.Schema.Declaration` behaviour (`decode/1`, `encode/1`, `json_schema/0`).
  """
  def declare(module) when is_atom(module) do
    %AST{kind: :declaration, module: module}
  end

  @doc """
  A literal value or a closed set of them (effect's `Literal`/`Literals`, unified).

    * `literal(:active)` — exactly that value
    * `literal([:pdf, :zpl])` or `literal(:pdf, :zpl)` — one of the set
    * for a wire-lenient (normalizing) set, compose the general form:
      `any() |> decode_to(literal([:on, :off]), &{:ok, fold(&1)})` — the target
      literal validates membership (atoms match their string wire form).

  Note: a list argument always means a *set* — a literal whose value is itself a
  list is not representable (no known use).
  """
  def literal(values) when is_list(values) and values != [],
    do: %AST{kind: :literal, values: values}

  def literal(value), do: %AST{kind: :literal, values: [value]}

  def literal(value1, value2), do: %AST{kind: :literal, values: [value1, value2]}
  def literal(value1, value2, value3), do: %AST{kind: :literal, values: [value1, value2, value3]}

  def record(key_schema, value_schema) do
    %AST{kind: :record, key_type: resolve(key_schema), value_type: resolve(value_schema)}
  end

  # Any module exporting __schema__/0 is usable wherever a schema is expected.
  defp resolve(%AST{} = schema), do: schema
  defp resolve(module) when is_atom(module), do: module.__schema__()

  def optional(%AST{context: ctx} = schema) do
    %{schema | context: %{ctx | optional?: true}}
  end

  def nullable(%AST{context: ctx} = schema) do
    %{schema | context: %{ctx | nullable?: true}}
  end

  @doc """
  Set a default on any schema (pipe-friendly). Used when the value is absent or nil:

      Schema.boolean() |> Schema.default(false)
      Style |> Schema.default(:solid)          # works on module schemas too
  """
  def default(schema, value) do
    %AST{context: ctx} = resolved = resolve(schema)
    %{resolved | context: %{ctx | default: value}}
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

  @doc """
  Build a bidirectional transform: `encoded` is the wire-side schema (validated on the raw
  input), `decode` maps the encoded value to the typed value (`{:ok, typed} | {:error, msg}`),
  and `encode` reverses it. Nest transforms to compose them.

      Schema.transform(Schema.string(), &Integer.parse/1, &to_string/1)
  """
  def transform(encoded, decode, encode)
      when is_function(decode, 1) and is_function(encode, 1) do
    %AST{
      kind: :transform,
      inner: resolve(encoded),
      encoding: [%Transformation{decode: decode, encode: encode}]
    }
  end

  @doc """
  Pipe a decode step **between two schemas** (effect's `decodeTo`): validate the
  encoded side, apply `decode`, then validate the result against `target` — so the
  typed side is schema-checked too, and normalizations compose by nesting:

      # "  ON  " → trim → downcase → member of the set
      Schema.string()
      |> Schema.decode_to(Schema.literal(["on", "off"]), &{:ok, &1 |> String.trim() |> String.downcase()})

  `encode` defaults to identity; the target may be a module schema.
  """
  def decode_to(encoded, target, decode, encode \\ & &1)
      when is_function(decode, 1) and is_function(encode, 1) do
    %AST{
      kind: :transform,
      inner: resolve(encoded),
      value_type: resolve(target),
      encoding: [%Transformation{decode: decode, encode: encode}]
    }
  end

  @doc "Decode a numeric string to an integer (or float); encodes back to a string."
  def number_from_string do
    transform(
      string(),
      fn s ->
        case Integer.parse(s) do
          {int, ""} ->
            {:ok, int}

          _ ->
            case Float.parse(s) do
              {float, ""} -> {:ok, float}
              _ -> {:error, "is not a number"}
            end
        end
      end,
      &to_string/1
    )
  end

  @doc "Trim surrounding whitespace on decode (encode is identity)."
  def trim, do: transform(string(), &{:ok, String.trim(&1)}, & &1)

  @doc "Downcase on decode (encode is identity)."
  def downcase, do: transform(string(), &{:ok, String.downcase(&1)}, & &1)

  @doc "Upcase on decode (encode is identity)."
  def upcase, do: transform(string(), &{:ok, String.upcase(&1)}, & &1)

  @doc "Decode an ISO-8601 string to a `DateTime`; encode back to ISO-8601."
  def datetime_from_iso8601 do
    transform(
      string(),
      fn s ->
        case DateTime.from_iso8601(s) do
          {:ok, dt, _offset} -> {:ok, dt}
          {:error, _} -> {:error, "is not a valid ISO-8601 datetime"}
        end
      end,
      fn %DateTime{} = dt -> DateTime.to_iso8601(dt) end
    )
  end

  def validate(schema, data) do
    Validator.validate(schema, data)
  end

  @doc "Decode `data` against `schema` (alias for `validate/2` — the decode direction)."
  def decode(schema, data), do: Validator.validate(schema, data)

  @doc "Encode a typed value back to its wire representation (reverses transforms)."
  def encode(schema, value), do: Encoder.encode(schema, value)

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
