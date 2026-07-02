defmodule Raggio.Schema.Issue do
  @moduledoc """
  Structured decode errors as a **tree** — the analog of effect-smol's `SchemaIssue`.

  Leaves describe a single failure; structural nodes locate and group them:

    * `InvalidType`  — the value has the wrong shape (`expected` names the type)
    * `InvalidValue` — right shape, failed a check/refinement/literal (carries the
      `constraint` tag)
    * `MissingKey`   — a required struct field was absent
    * `Encoding`     — a transform's decode getter failed (effect's `Encoding`)
    * `Pointer`      — wraps an inner issue with one path segment (field name, list
      index, or record key); these nest to record *where* the failure is
    * `Composite`    — sibling issues under one node (e.g. several bad fields)
    * `AnyOf`        — a union matched no member; keeps **every branch's issue**,
      which the flat error list cannot express

  The interpreter builds this tree natively. The classic flat list —
  `{:error, [%Raggio.Schema.Error{path, message, value, constraint}]}` returned by
  `Raggio.Schema.validate/2,3` — is `to_errors/1`, a fold of the tree (an `AnyOf`
  folds to the single legacy "does not match any union variant" error). Ask for the
  tree itself with `Raggio.Schema.validate(schema, data, errors: :tree)`.

  `format/1` renders a human-readable indented view (a minimal `Formatter` analog).
  """

  alias Raggio.Schema.Error

  defmodule InvalidType do
    @moduledoc false
    @enforce_keys [:expected]
    defstruct [:expected, :value]
    @type t :: %__MODULE__{expected: String.t(), value: term()}
  end

  defmodule InvalidValue do
    @moduledoc false
    @enforce_keys [:message]
    defstruct [:message, :value, :constraint]
    @type t :: %__MODULE__{message: String.t(), value: term(), constraint: atom() | nil}
  end

  defmodule MissingKey do
    @moduledoc false
    defstruct message: "is required"
    @type t :: %__MODULE__{message: String.t()}
  end

  defmodule Encoding do
    @moduledoc false
    @enforce_keys [:message]
    defstruct [:message, :value]
    @type t :: %__MODULE__{message: String.t(), value: term()}
  end

  defmodule Pointer do
    @moduledoc false
    @enforce_keys [:key, :issue]
    defstruct [:key, :issue]
    @type t :: %__MODULE__{key: atom() | non_neg_integer(), issue: Raggio.Schema.Issue.t()}
  end

  defmodule Composite do
    @moduledoc false
    @enforce_keys [:issues]
    defstruct [:issues]
    @type t :: %__MODULE__{issues: [Raggio.Schema.Issue.t()]}
  end

  defmodule AnyOf do
    @moduledoc false
    @enforce_keys [:issues]
    defstruct [:issues, :value]
    @type t :: %__MODULE__{issues: [Raggio.Schema.Issue.t()], value: term()}
  end

  @type t ::
          InvalidType.t()
          | InvalidValue.t()
          | MissingKey.t()
          | Encoding.t()
          | Pointer.t()
          | Composite.t()
          | AnyOf.t()

  ## Constructors (used by the interpreter)

  @doc false
  def invalid_type(expected, value), do: %InvalidType{expected: expected, value: value}

  @doc false
  def invalid_value(message, value, constraint),
    do: %InvalidValue{message: message, value: value, constraint: constraint}

  @doc false
  def missing_key, do: %MissingKey{}

  @doc false
  def encoding(message, value), do: %Encoding{message: message, value: value}

  @doc false
  def pointer(key, issue), do: %Pointer{key: key, issue: issue}

  @doc false
  def any_of(issues, value), do: %AnyOf{issues: issues, value: value}

  @doc "Group issues; a single issue stays itself (no needless Composite)."
  def composite([issue]), do: issue
  def composite(issues) when is_list(issues), do: %Composite{issues: issues}

  ## Projections

  @doc """
  Fold the tree into the classic flat error list (the `Raggio.Schema.validate/2,3`
  shape). `Pointer` chains become the `:path`; an `AnyOf` folds to the single legacy
  union error (branch detail is only available on the tree).
  """
  @spec to_errors(t()) :: [Error.t()]
  def to_errors(issue), do: issue |> collect([]) |> Enum.reverse()

  defp collect(%Pointer{key: key, issue: inner}, path), do: collect_into(inner, [key | path])
  defp collect(issue, path), do: collect_into(issue, path)

  defp collect_into(%Pointer{} = p, path), do: collect(p, path)

  defp collect_into(%Composite{issues: issues}, path) do
    Enum.flat_map(issues, &collect(&1, path))
  end

  defp collect_into(%AnyOf{value: value}, path) do
    [
      %Error{
        path: Enum.reverse(path),
        message: "does not match any union variant",
        value: value,
        constraint: :union
      }
    ]
  end

  defp collect_into(%InvalidType{expected: expected, value: value}, path) do
    [
      %Error{
        path: Enum.reverse(path),
        message: "expected #{expected}",
        value: value,
        constraint: :type
      }
    ]
  end

  defp collect_into(%InvalidValue{message: message, value: value, constraint: constraint}, path) do
    [%Error{path: Enum.reverse(path), message: message, value: value, constraint: constraint}]
  end

  defp collect_into(%MissingKey{message: message}, path) do
    [%Error{path: Enum.reverse(path), message: message, value: nil, constraint: :required}]
  end

  defp collect_into(%Encoding{message: message, value: value}, path) do
    [%Error{path: Enum.reverse(path), message: message, value: value, constraint: :transform}]
  end

  @doc """
  Render the tree as an indented, human-readable string (a minimal `Formatter`).

      ├─ items
      │  └─ [1]
      │     └─ n: is required
  """
  @spec format(t()) :: String.t()
  def format(issue), do: issue |> lines() |> Enum.join("\n")

  defp lines(%Pointer{key: key, issue: inner}) do
    [segment(key) | Enum.map(lines(inner), &("  " <> &1))]
  end

  defp lines(%Composite{issues: issues}), do: Enum.flat_map(issues, &lines/1)

  defp lines(%AnyOf{issues: issues}) do
    [
      "does not match any union variant:"
      | issues
        |> Enum.with_index()
        |> Enum.flat_map(fn {issue, i} ->
          ["  variant #{i}:" | Enum.map(lines(issue), &("    " <> &1))]
        end)
    ]
  end

  defp lines(%InvalidType{expected: expected, value: value}),
    do: ["expected #{expected}, got #{inspect(value)}"]

  defp lines(%InvalidValue{message: message, value: value}),
    do: ["#{message} (got #{inspect(value)})"]

  defp lines(%MissingKey{message: message}), do: [message]

  defp lines(%Encoding{message: message, value: value}),
    do: ["#{message} (got #{inspect(value)})"]

  defp segment(key) when is_integer(key), do: "[#{key}]"
  defp segment(key), do: "#{key}:"
end
