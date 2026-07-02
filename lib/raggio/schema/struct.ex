defmodule Raggio.Schema.Struct do
  @moduledoc """
  Opt-in macro for module-backed schemas — the effect `Schema.Class` analog.

  `Raggio.Schema`'s core is macro-less runtime values; this is the one place a macro is
  warranted, because `defstruct` and `@type t` only exist at compile time. The surface is
  **data-first**, mirroring effect's `Class` (fields as a record, not a DSL block): the
  argument to `defschema` is the same keyword list `Raggio.Schema.struct/1` accepts.

      defmodule User do
        use Raggio.Schema.Struct

        defschema name: Schema.string(min: 1),
                  age: Schema.integer(min: 0),
                  status: Schema.literal(:active, :inactive),
                  bio: Schema.string() |> Schema.optional()
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

  Field values are ordinary `Raggio.Schema` combinators — everything the runtime surface
  can express (checks, refinements, transforms, nesting) works here. A field may also be
  a **module** exporting `__schema__/0` (another `defschema` module, or a
  `Raggio.Schema.Literal` enum), so schemas compose across modules:

      defschema status: Status, owner: User
  """

  defmacro __using__(_opts) do
    quote do
      import Raggio.Schema.Struct, only: [defschema: 1]
      alias Raggio.Schema
    end
  end

  @doc "Declare the schema fields (a keyword list of `Raggio.Schema` expressions)."
  defmacro defschema(fields) when is_list(fields) do
    if fields == [] do
      raise ArgumentError, "defschema requires at least one field"
    end

    field_names = Enum.map(fields, &elem(&1, 0))
    type_pairs = Enum.map(fields, fn {name, expr} -> {name, type_for(expr)} end)

    quote do
      defstruct unquote(field_names)

      @type t :: %__MODULE__{unquote_splicing(type_pairs)}

      @doc "The runtime `Raggio.Schema` value for this module (bound to the struct)."
      def __schema__ do
        Raggio.Schema.struct(unquote(fields), module: __MODULE__)
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
  # add `| nil`; other pipes (refine/check) pass the inner type through. A bare module
  # (aliased) maps to its `t()`.

  @doc false
  def __type_for__(expr), do: type_for(expr)

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

  defp base_type(:union, [members | _]) when is_list(members) do
    members |> Enum.map(&type_for/1) |> union_type()
  end

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

  defp union_type([single]), do: single
  defp union_type([h | t]), do: quote(do: unquote(h) | unquote(union_type(t)))

  defp nilable(type), do: quote(do: unquote(type) | nil)
end
