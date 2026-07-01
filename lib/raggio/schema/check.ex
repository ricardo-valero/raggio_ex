defmodule Raggio.Schema.Check do
  @moduledoc """
  A refinement that runs *after* a node's type matches (mirrors effect-smol's `Filter`).

  Every constraint on a schema is a `Check`, not a field on the type node — this is the
  uniform-node + checks model. A check carries:

    * `constraint` — the tag surfaced on `Raggio.Schema.Error` (e.g. `:min`, `:pattern`)
    * `run` — `(value -> :ok | {:error, message})`
    * `meta` — a machine-readable JSON-Schema descriptor (e.g. `%{"minLength" => 3}`)
      that projections like the JSON Schema adapter fold in without knowing the check's
      internals
    * `aborted` — stop the check chain on failure (effect's `aborted`); default `false`

  The builders below cover the constraints raggio's constructors currently emit. `min`/`max`
  are polymorphic at the *surface* (string length vs number value vs list length); the
  constructor picks the right builder per kind, so each check here is unambiguous.
  """

  defstruct [:constraint, :run, meta: %{}, aborted: false]

  @type t :: %__MODULE__{
          constraint: atom(),
          run: (any() -> :ok | {:error, String.t()}),
          meta: map(),
          aborted: boolean()
        }

  # --- strings -------------------------------------------------------------

  @doc "String length ≥ n (byte length, matching the prior engine)."
  def min_length(n) do
    %__MODULE__{
      constraint: :min,
      meta: %{"minLength" => n},
      run: fn v ->
        if byte_size(v) >= n, do: :ok, else: {:error, "must be at least #{n} character(s)"}
      end
    }
  end

  @doc "String length ≤ n."
  def max_length(n) do
    %__MODULE__{
      constraint: :max,
      meta: %{"maxLength" => n},
      run: fn v ->
        if byte_size(v) <= n, do: :ok, else: {:error, "must be at most #{n} character(s)"}
      end
    }
  end

  @doc "String matches `regex`."
  def pattern(%Regex{} = regex) do
    %__MODULE__{
      constraint: :pattern,
      meta: %{"pattern" => Regex.source(regex)},
      run: fn v ->
        if Regex.match?(regex, v), do: :ok, else: {:error, "does not match pattern"}
      end
    }
  end

  # --- numbers -------------------------------------------------------------

  @doc "Number ≥ n."
  def min_value(n) do
    %__MODULE__{
      constraint: :min,
      meta: %{"minimum" => n},
      run: fn v -> if v >= n, do: :ok, else: {:error, "must be at least #{n}"} end
    }
  end

  @doc "Number ≤ n."
  def max_value(n) do
    %__MODULE__{
      constraint: :max,
      meta: %{"maximum" => n},
      run: fn v -> if v <= n, do: :ok, else: {:error, "must be at most #{n}"} end
    }
  end

  # --- lists ---------------------------------------------------------------

  @doc "List length ≥ n."
  def min_items(n) do
    %__MODULE__{
      constraint: :min,
      meta: %{"minItems" => n},
      run: fn v ->
        if length(v) >= n, do: :ok, else: {:error, "must have at least #{n} element(s)"}
      end
    }
  end

  @doc "List length ≤ n."
  def max_items(n) do
    %__MODULE__{
      constraint: :max,
      meta: %{"maxItems" => n},
      run: fn v ->
        if length(v) <= n, do: :ok, else: {:error, "must have at most #{n} element(s)"}
      end
    }
  end

  @doc "List elements are unique."
  def unique_items do
    %__MODULE__{
      constraint: :unique,
      meta: %{"uniqueItems" => true},
      run: fn v ->
        if length(v) == length(Enum.uniq(v)), do: :ok, else: {:error, "must have unique elements"}
      end
    }
  end
end
