defmodule Raggio.Schema.Context do
  @moduledoc """
  Per-field metadata carried on a schema node (mirrors effect-smol's per-property
  `context`). Optionality, nullability, and the default value describe the *slot* a
  type occupies in a struct — not the type itself — so they live here rather than as
  fields on the type node.

  `default: :none` is the "no default" sentinel (distinct from `nil`, which is a
  legitimate default value).
  """

  defstruct optional?: false, nullable?: false, default: :none

  @type t :: %__MODULE__{
          optional?: boolean(),
          nullable?: boolean(),
          default: any() | :none
        }
end
