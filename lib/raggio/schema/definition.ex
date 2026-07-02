defmodule Raggio.Schema.Definition do
  @moduledoc """
  The `schema do … end` macro behind `use Raggio.Schema` — module-backed schemas
  (the effect `Schema.Class` analog).

  The block holds **one schema expression** in raggio's own combinator vocabulary;
  the macro dispatches on its head:

      defmodule Status do
        use Raggio.Schema

        schema do
          literal ["on", "off"]                # Schema.literals/1,2 — decode: :downcase works
        end
      end

      defmodule Device do
        use Raggio.Schema

        schema do
          struct name: Schema.string(min: 1),  # Schema.struct/1 — fields as data
                 status: Status,               # any module exporting __schema__/0 is a schema
                 owner: User                   # embedded schema modules decode to their structs
        end
      end

  Every module gets `__schema__/0` (the runtime AST), `decode/1`, `decode!/1`, `encode/1`.
  Per head:

    * `struct fields` — also emits `defstruct` and `@type t` derived from the field
      schemas (literals become value unions, `optional`/`nullable` add `| nil`,
      unrecognized falls back to `term()`); decode returns `%__MODULE__{}`.
    * `literal values[, decode: :downcase | :upcase]` — also emits `values/0` and a
      `@type t` value union (atoms/integers) or the widened type (strings).
    * any other expression (`union [A, B]`, `Schema.list(…)`, a pipe) — generic: the
      module *is* that schema; `@type t :: term()`. Qualify combinators with `Schema.`
      in this position.

  Field/argument values are ordinary `Raggio.Schema` combinators — checks, refinements,
  transforms, and nesting all work.
  """

  defmacro schema(do: block) do
    case block do
      {:struct, _, [fields]} when is_list(fields) ->
        struct_codegen(fields)

      {:literal, _, [values]} when is_list(values) ->
        literal_codegen(values, [])

      {:literal, _, [values, opts]} when is_list(values) and is_list(opts) ->
        literal_codegen(values, opts)

      {:union, _, [members]} when is_list(members) ->
        generic_codegen(quote(do: Raggio.Schema.union(unquote(members))), union_type_of(members))

      other ->
        generic_codegen(other, quote(do: term()))
    end
  end

  # --- struct modules --------------------------------------------------------

  defp struct_codegen([]) do
    raise ArgumentError, "schema do struct ... end requires at least one field"
  end

  defp struct_codegen(fields) do
    field_names = Enum.map(fields, &elem(&1, 0))
    type_pairs = Enum.map(fields, fn {name, expr} -> {name, type_for(expr)} end)

    quote do
      defstruct unquote(field_names)

      @type t :: %__MODULE__{unquote_splicing(type_pairs)}

      @doc "The runtime `Raggio.Schema` value for this module (bound to the struct)."
      def __schema__ do
        Raggio.Schema.struct(unquote(fields), module: __MODULE__)
      end

      unquote(codec_wrappers())
    end
  end

  # --- literal-set modules ----------------------------------------------------

  defp literal_codegen(values, opts) do
    type = literal_union(values)

    quote do
      @type t :: unquote(type)

      @doc "The allowed values of this literal set."
      def values, do: unquote(values)

      @doc "The runtime `Raggio.Schema` value for this literal set."
      def __schema__, do: Raggio.Schema.literals(unquote(values), unquote(opts))

      unquote(codec_wrappers())
    end
  end

  # --- generic: the module IS the given schema expression ----------------------

  defp generic_codegen(expr, type) do
    quote do
      @type t :: unquote(type)

      @doc "The runtime `Raggio.Schema` value for this module."
      def __schema__, do: unquote(expr)

      unquote(codec_wrappers())
    end
  end

  defp codec_wrappers do
    quote do
      @doc "Decode (validate + build) a wire value into `t()`."
      def decode(data), do: Raggio.Schema.decode(__schema__(), data)

      @doc "Like `decode/1` but raises `Raggio.Schema.ValidationError` on failure."
      def decode!(data), do: Raggio.Schema.validate!(__schema__(), data)

      @doc "Encode a `t()` back to its wire representation."
      def encode(value), do: Raggio.Schema.encode(__schema__(), value)
    end
  end

  # --- @type t derivation from the quoted field expressions -----------------
  #
  # Best-effort: recognize the Raggio.Schema constructor the expression bottoms out
  # in and map it to a typespec; anything else is term(). Pipes into optional/nullable
  # add `| nil`; other pipes (refine/check) pass the inner type through. A bare module
  # (aliased) maps to its `t()`.

  defp type_for({:|>, _, [inner, call]}) do
    case call_name(call) do
      name when name in [:optional, :nullable] -> nilable(type_for(inner))
      _ -> type_for(inner)
    end
  end

  defp type_for({:__aliases__, _, _} = mod) do
    quote(do: unquote(mod).t())
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

  defp base_type(:literal, args), do: literal_union(args)
  defp base_type(:literals, [values | _]) when is_list(values), do: literal_union(values)

  defp base_type(:union, [members | _]) when is_list(members), do: union_type_of(members)

  defp base_type(:refine, [inner | _]), do: type_for(inner)
  defp base_type(:check, [inner | _]), do: type_for(inner)
  defp base_type(:transform, _), do: quote(do: term())
  defp base_type(_fun, _args), do: quote(do: term())

  # Typespecs only support atom/integer literal types; strings/floats widen.
  defp literal_union(values) do
    cond do
      Enum.all?(values, &(is_atom(&1) or is_integer(&1))) -> union_type(values)
      Enum.all?(values, &is_binary/1) -> quote(do: String.t())
      Enum.all?(values, &is_number/1) -> quote(do: number())
      true -> quote(do: term())
    end
  end

  defp union_type_of(members), do: members |> Enum.map(&type_for/1) |> union_type()

  defp union_type([single]), do: single
  defp union_type([h | t]), do: quote(do: unquote(h) | unquote(union_type(t)))

  defp nilable(type), do: quote(do: unquote(type) | nil)
end
