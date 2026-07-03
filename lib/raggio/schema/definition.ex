defmodule Raggio.Schema.Definition do
  @moduledoc """
  The `schema do … end` macro behind `use Raggio.Schema` — module-backed schemas
  (the effect `Schema.Class` analog).

  Inside the block, **raggio's combinator vocabulary is unqualified and nestable**:
  the macro rewrites known combinator names (`string`, `struct`, `union`, `literal`,
  `list`, `optional`, …) to `Raggio.Schema.*` calls *within the block only* — no
  imports, so `Kernel.struct/2` etc. remain untouched outside the block.

      defmodule Status do
        use Raggio.Schema

        schema do
          literal("on", "off")                     # variadic; decode: :downcase works
        end
      end

      defmodule Device do
        use Raggio.Schema

        schema do
          struct(
            name: string(min: 1),                  # unqualified combinators
            status: Status,                        # modules exporting __schema__/0 compose
            owner: User,                           # embedded modules decode to their structs
            extra: struct(foo: string(min: 1))     # …and combinators nest
          )
        end
      end

      defmodule Actor do
        use Raggio.Schema

        schema do
          union(User, Device)                      # variadic; the module IS this schema
        end
      end

  Every module gets `__schema__/0` (the runtime AST), `decode/1`, `decode!/1`, `encode/1`.
  The top-level head decides the extra codegen:

    * `struct fields` — also emits `defstruct` and `@type t` derived from the field
      schemas (literals become value unions, `optional`/`nullable` add `| nil`,
      unrecognized falls back to `term()`); decode returns `%__MODULE__{}`.
    * `literal v1, v2, …` (or a single list) — also emits `values/0` and a `@type t`
      value union (atoms/integers) or the widened type (strings). For a wire-lenient
      set, `any() |> decode_to(literal([...]), &fold/1)` gets the same `values/0` +
      `@type t` (derived from the target) plus the codec.
    * anything else (`union A, B`, `list(string())`, a pipe) — generic: the module
      *is* that schema; `@type t` is derived where possible.

  Inside the block the combinator names below belong to raggio; qualify anything
  else you need to call. Outside the block, nothing changes.
  """

  # Names rewritten to Raggio.Schema.* inside the block (when they appear as calls).
  @combinators ~w(
    string integer float number boolean atom date datetime decimal any
    struct list tuple union literal record declare
    optional nullable default refine check transform decode_to
    trim downcase upcase number_from_string datetime_from_iso8601
    email url uuid
  )a

  defmacro schema(do: block) do
    case block do
      {:struct, _, [fields]} when is_list(fields) ->
        struct_codegen(fields)

      {:literal, _, args} when is_list(args) ->
        {values, _opts} = literal_args(args)
        literal_codegen(values)

      {:union, _, [disc, members]} when is_atom(disc) and is_list(members) ->
        generic_codegen(
          quote(do: Raggio.Schema.union(unquote(disc), unquote(rewrite(members)))),
          union_type_of(members)
        )

      {:union, _, args} when is_list(args) and args != [] ->
        members = union_args(args)

        generic_codegen(
          quote(do: Raggio.Schema.union(unquote(rewrite(members)))),
          union_type_of(members)
        )

      {:|>, _, [_enc, {:decode_to, _, [{:literal, _, [values]} | _]}]} = expr
      when is_list(values) ->
        normalizing_codegen(expr, values)

      {:decode_to, _, [_enc, {:literal, _, [values]} | _]} = expr when is_list(values) ->
        normalizing_codegen(expr, values)

      other ->
        generic_codegen(rewrite(other), type_for(other))
    end
  end

  # A decode_to whose target is a literal set: the module is the codec, but the
  # closed set is compile-time known — emit values/0 and the value-union @type.
  defp normalizing_codegen(expr, values) do
    type = literal_union(values)

    quote do
      @type t :: unquote(type)

      @doc "The canonical values of this set."
      def values, do: unquote(values)

      @doc "The runtime `Raggio.Schema` value for this module."
      def __schema__, do: unquote(rewrite(expr))

      unquote(codec_wrappers())
    end
  end

  # --- head argument normalization -------------------------------------------

  # literal(["a","b"]) | literal(["a","b"], opts) | literal("a","b") | literal("a","b", decode: :downcase)
  defp literal_args([values]) when is_list(values), do: {values, []}
  defp literal_args([values, opts]) when is_list(values) and is_list(opts), do: {values, opts}

  defp literal_args(args) do
    case List.last(args) do
      opts when is_list(opts) and args != [opts] ->
        if Keyword.keyword?(opts) do
          {Enum.drop(args, -1), opts}
        else
          {args, []}
        end

      _ ->
        {args, []}
    end
  end

  # union([A, B]) | union(A, B, ...)
  defp union_args([members]) when is_list(members), do: members
  defp union_args(args), do: args

  # --- struct modules --------------------------------------------------------

  defp struct_codegen([]) do
    raise ArgumentError, "schema do struct ... end requires at least one field"
  end

  defp struct_codegen(fields) do
    field_names = Enum.map(fields, &elem(&1, 0))
    type_pairs = Enum.map(fields, fn {name, expr} -> {name, type_for(expr)} end)
    rewritten = Enum.map(fields, fn {name, expr} -> {name, rewrite(expr)} end)

    quote do
      defstruct unquote(field_names)

      @type t :: %__MODULE__{unquote_splicing(type_pairs)}

      @doc "The runtime `Raggio.Schema` value for this module (bound to the struct)."
      def __schema__ do
        Raggio.Schema.struct(unquote(rewritten), module: __MODULE__)
      end

      unquote(codec_wrappers())
    end
  end

  # --- literal-set modules ----------------------------------------------------

  defp literal_codegen(values) do
    type = literal_union(values)

    quote do
      @type t :: unquote(type)

      @doc "The allowed values of this literal set."
      def values, do: unquote(values)

      @doc "The runtime `Raggio.Schema` value for this literal set."
      def __schema__, do: Raggio.Schema.literal(unquote(values))

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
      @doc """
      Decode (validate + build) a wire value into `t()`.

      Accepts the `Raggio.Schema.validate/3` options — e.g. `mode: :all_errors`
      to collect every failure, or `errors: :tree` for the issue tree.
      """
      def decode(data, opts \\ []), do: Raggio.Schema.validate(__schema__(), data, opts)

      @doc "Like `decode/1` but raises `Raggio.Schema.ValidationError` on failure."
      def decode!(data), do: Raggio.Schema.validate!(__schema__(), data)

      @doc "Encode a `t()` back to its wire representation."
      def encode(value), do: Raggio.Schema.encode(__schema__(), value)
    end
  end

  # --- block rewriting ---------------------------------------------------------
  #
  # Rewrite unqualified calls to known combinator names into Raggio.Schema.* calls,
  # recursively, within the block only. `literal` (variadic) maps to `literals/2`.

  defp rewrite(ast) do
    Macro.prewalk(ast, fn
      {:literal, meta, args} when is_list(args) and args != [] ->
        case literal_args(args) do
          {values, []} ->
            qualified(:literal, meta, [values])

          {_values, opts} ->
            raise ArgumentError,
                  "literal no longer takes options (got #{inspect(opts)}) — compose the " <>
                    "general form instead: any() |> decode_to(literal(values), &fold/1)"
        end

      {:union, meta, [disc, members]} when is_atom(disc) and is_list(members) ->
        qualified(:union, meta, [disc, members])

      {:union, meta, args} when is_list(args) and args != [] ->
        qualified(:union, meta, [union_args(args)])

      {name, meta, args} when name in @combinators and is_list(args) ->
        qualified(name, meta, args)

      other ->
        other
    end)
  end

  defp qualified(fun, meta, args) do
    {{:., meta, [{:__aliases__, meta, [:Raggio, :Schema]}, fun]}, meta, args}
  end

  # --- @type t derivation from the quoted expressions -----------------------
  #
  # Best-effort: recognize the Raggio.Schema constructor the expression bottoms out
  # in and map it to a typespec; anything else is term(). Pipes into optional/nullable
  # add `| nil`; other pipes (refine/check) pass the inner type through. A bare module
  # (aliased) maps to its `t()`.

  defp type_for({:|>, _, [inner, call]}) do
    case {call_name(call), call} do
      {name, _} when name in [:optional, :nullable] -> nilable(type_for(inner))
      {:decode_to, {_, _, [target | _]}} -> type_for(target)
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
  defp base_type(:number, _), do: quote(do: number())
  defp base_type(:any, _), do: quote(do: term())
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
    {values, _opts} = literal_args(args)
    literal_union(values)
  end

  defp base_type(:union, [disc, members]) when is_atom(disc) and is_list(members) do
    union_type_of(members)
  end

  defp base_type(:union, args) when args != [] do
    args |> union_args() |> union_type_of()
  end

  defp base_type(:refine, [inner | _]), do: type_for(inner)
  defp base_type(:check, [inner | _]), do: type_for(inner)
  defp base_type(:transform, _), do: quote(do: term())
  defp base_type(:decode_to, [_enc, target | _]), do: type_for(target)
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
