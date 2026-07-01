defmodule Raggio.Schema.AST do
  @moduledoc """
  The uniform schema node — every kind is the same struct (effect-smol's `Base`).

  The type identity is generic (`:string` is just `:string`); everything layered on top
  lives in four uniform slots rather than as bespoke fields:

    * `checks`   — refinements (`Raggio.Schema.Check`); `min`/`max`/`pattern`/`unique`
      are checks here, not constraint fields
    * `encoding` — the decoded↔encoded transform chain (the codec; empty until P2)
    * `context`  — per-field metadata (`optional?`/`nullable?`/`default`), meaningful when
      the node sits in a struct field
    * `metadata` — annotations (`title`/`description`/`examples`) read by projections

  Kind-specific payload lives in the dedicated slot for that kind (only one is meaningful):

    * `:literal` → `values`
    * `:list`    → `inner`
    * `:tuple` / `:union` → `elements`
    * `:record`  → `key_type`, `value_type`
    * `:struct`  → `fields` (`[{name, node}]`, order preserved) and optionally `module`
      (a bound target struct, used by the struct-building decode in a later step)

  This replaces the prior bespoke `Raggio.Schema.Type` (constraints/optional/nullable/default
  as node fields). The public `Raggio.Schema` constructor surface is unchanged.
  """

  alias Raggio.Schema.Context

  @type t :: %__MODULE__{
          kind: atom(),
          inner: t() | nil,
          fields: [{atom(), t()}] | nil,
          elements: [t()] | nil,
          key_type: t() | nil,
          value_type: t() | nil,
          values: [any()] | nil,
          module: module() | nil,
          checks: [Raggio.Schema.Check.t()],
          encoding: [any()],
          context: Context.t(),
          metadata: map()
        }

  defstruct kind: nil,
            inner: nil,
            fields: nil,
            elements: nil,
            key_type: nil,
            value_type: nil,
            values: nil,
            module: nil,
            checks: [],
            encoding: [],
            context: %Context{},
            metadata: %{}
end
