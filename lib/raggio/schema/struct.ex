defmodule Raggio.Schema.Struct do
  @moduledoc """
  Opt-in macro sugar for module-backed schemas — the effect `Schema.Class` analog.

  `Raggio.Schema`'s core is macro-less runtime values; this is the one place a macro is
  warranted, because `defstruct` and `@type t` only exist at compile time. Declare the
  fields once and get the struct, its typespec, the bound runtime schema, and
  `decode`/`encode` wrappers:

      defmodule User do
        use Raggio.Schema.Struct

        schema do
          field :name, Schema.string(min: 1)
          field :age, Schema.integer(min: 0)
          field :status, Schema.literal(:active, :inactive)
          field :bio, Schema.string() |> Schema.optional()
        end
      end

      User.decode(%{name: "A", age: 1, status: :active})
      #=> {:ok, %User{name: "A", age: 1, status: :active}}

  Generated for the module:

    * `defstruct` over the declared field names
    * `@type t` derived from the field schemas (`Schema.string()` → `String.t()`,
      `optional`/`nullable` add `| nil`, literals become a union of their values;
      anything unrecognized falls back to `term()`)
    * `__schema__/0` — the runtime `Raggio.Schema.struct/2` value bound to the module
      (field expressions are evaluated when called, so checks/transforms work)
    * `decode/1`, `decode!/1`, `encode/1` wrappers

  The field expressions are ordinary `Raggio.Schema` combinators — everything the
  runtime surface can express (checks, refinements, transforms, nesting) works here.
  """

  defmacro __using__(_opts) do
    quote do
      import Raggio.Schema.Struct, only: [schema: 1]
      alias Raggio.Schema
      Module.register_attribute(__MODULE__, :raggio_schema_fields, accumulate: true)
      @before_compile Raggio.Schema.Struct
    end
  end

  @doc "Declare the schema fields for this module."
  defmacro schema(do: block) do
    quote do
      import Raggio.Schema.Struct, only: [field: 2]
      unquote(block)
    end
  end

  @doc "Declare one field: a name and a `Raggio.Schema` combinator expression."
  defmacro field(name, schema_expr) when is_atom(name) do
    quote do
      @raggio_schema_fields {unquote(name), unquote(Macro.escape(schema_expr))}
    end
  end

  defmacro __before_compile__(env) do
    fields = env.module |> Module.get_attribute(:raggio_schema_fields) |> Enum.reverse()

    if fields == [] do
      raise ArgumentError,
            "#{inspect(env.module)} uses Raggio.Schema.Struct but declares no fields — " <>
              "add a `schema do field ... end` block"
    end

    field_names = Enum.map(fields, &elem(&1, 0))

    quoted_pairs =
      Enum.map(fields, fn {name, expr} -> {name, expr} end)

    type_pairs =
      Enum.map(fields, fn {name, expr} -> {name, type_for(expr)} end)

    quote do
      defstruct unquote(field_names)

      @type t :: %__MODULE__{unquote_splicing(type_pairs)}

      @doc "The runtime `Raggio.Schema` value for this module (bound to the struct)."
      def __schema__ do
        Raggio.Schema.struct(unquote(quoted_pairs), module: __MODULE__)
      end

      @doc "Decode (validate + build) data into `%#{inspect(__MODULE__)}{}`."
      def decode(data), do: Raggio.Schema.decode(__schema__(), data)

      @doc "Like `decode/1` but raises `Raggio.Schema.ValidationError` on failure."
      def decode!(data), do: Raggio.Schema.validate!(__schema__(), data)

      @doc "Encode a `%#{inspect(__MODULE__)}{}` back to its wire representation."
      def encode(value), do: Raggio.Schema.encode(__schema__(), value)
    end
  end

  # --- @type t derivation from the quoted field expressions -----------------
  #
  # Best-effort: recognize the Raggio.Schema constructor the expression bottoms out
  # in and map it to a typespec; anything else is term(). Pipes into optional/nullable
  # add `| nil`; other pipes (refine/check) pass the inner type through.

  defp type_for({:|>, _, [inner, call]}) do
    case call_name(call) do
      name when name in [:optional, :nullable] -> nilable(type_for(inner))
      _ -> type_for(inner)
    end
  end

  defp type_for({{:., _, [_mod, fun]}, _, args}), do: base_type(fun, args)
  defp type_for({fun, _, args}) when is_atom(fun) and is_list(args), do: base_type(fun, args)
  defp type_for(_expr), do: quote(do: term())

  defp call_name({{:., _, [_mod, fun]}, _, _args}), do: fun
  defp call_name({fun, _, _args}) when is_atom(fun), do: fun
  defp call_name(_), do: nil

  defp base_type(:string, _), do: quote(do: String.t())
  defp base_type(:integer, _), do: quote(do: integer())
  defp base_type(:float, _), do: quote(do: float())
  defp base_type(:boolean, _), do: quote(do: boolean())
  defp base_type(:atom, _), do: quote(do: atom())
  defp base_type(:date, _), do: quote(do: Date.t())
  defp base_type(:datetime, _), do: quote(do: DateTime.t() | NaiveDateTime.t())
  defp base_type(:decimal, _), do: quote(do: Decimal.t())
  defp base_type(:trim, _), do: quote(do: String.t())
  defp base_type(:downcase, _), do: quote(do: String.t())
  defp base_type(:upcase, _), do: quote(do: String.t())
  defp base_type(:number_from_string, _), do: quote(do: number())
  defp base_type(:datetime_from_iso8601, _), do: quote(do: DateTime.t())
  defp base_type(:record, _), do: quote(do: map())
  defp base_type(:struct, _), do: quote(do: map())
  defp base_type(:tuple, _), do: quote(do: tuple())

  defp base_type(:list, [inner | _]), do: quote(do: [unquote(type_for(inner))])
  defp base_type(:list, _), do: quote(do: list())

  defp base_type(:literal, args) do
    if Enum.all?(args, &literal_value?/1) do
      union_type(args)
    else
      quote(do: term())
    end
  end

  defp base_type(:union, [members | _]) when is_list(members) do
    members |> Enum.map(&type_for/1) |> union_type_specs()
  end

  defp base_type(:refine, [inner | _]), do: type_for(inner)
  defp base_type(:check, [inner | _]), do: type_for(inner)
  defp base_type(:transform, _), do: quote(do: term())
  defp base_type(_fun, _args), do: quote(do: term())

  defp literal_value?(v) when is_atom(v) or is_number(v) or is_binary(v), do: true
  defp literal_value?(_), do: false

  defp union_type([single]), do: single
  defp union_type([h | t]), do: quote(do: unquote(h) | unquote(union_type(t)))

  defp union_type_specs([single]), do: single
  defp union_type_specs([h | t]), do: quote(do: unquote(h) | unquote(union_type_specs(t)))

  defp nilable(type), do: quote(do: unquote(type) | nil)
end
