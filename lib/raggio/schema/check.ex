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

  @doc "Non-empty list."
  def non_empty_list do
    %__MODULE__{
      constraint: :non_empty,
      meta: %{"minItems" => 1},
      run: fn v -> if v != [], do: :ok, else: {:error, "must not be empty"} end
    }
  end

  # --- numbers (exclusive bounds + arithmetic) -----------------------------

  @doc "Number strictly greater than n."
  def greater_than(n) do
    %__MODULE__{
      constraint: :greater_than,
      meta: %{"exclusiveMinimum" => n},
      run: fn v -> if v > n, do: :ok, else: {:error, "must be greater than #{n}"} end
    }
  end

  @doc "Number strictly less than n."
  def less_than(n) do
    %__MODULE__{
      constraint: :less_than,
      meta: %{"exclusiveMaximum" => n},
      run: fn v -> if v < n, do: :ok, else: {:error, "must be less than #{n}"} end
    }
  end

  @doc "Number is an exact multiple of n."
  def multiple_of(n) do
    %__MODULE__{
      constraint: :multiple_of,
      meta: %{"multipleOf" => n},
      run: fn v -> if multiple?(v, n), do: :ok, else: {:error, "must be a multiple of #{n}"} end
    }
  end

  @doc "Number is integral (no fractional part)."
  def int do
    %__MODULE__{
      constraint: :int,
      meta: %{"type" => "integer"},
      run: fn v -> if integral?(v), do: :ok, else: {:error, "must be an integer"} end
    }
  end

  # --- strings (content) ---------------------------------------------------

  @doc "Non-empty string."
  def non_empty_string do
    %__MODULE__{
      constraint: :non_empty,
      meta: %{"minLength" => 1},
      run: fn v -> if v != "", do: :ok, else: {:error, "must not be empty"} end
    }
  end

  @doc "String starts with `prefix`."
  def starts_with(prefix) do
    %__MODULE__{
      constraint: :starts_with,
      meta: %{"pattern" => "^" <> Regex.escape(prefix)},
      run: fn v ->
        if String.starts_with?(v, prefix),
          do: :ok,
          else: {:error, "must start with #{inspect(prefix)}"}
      end
    }
  end

  @doc "String ends with `suffix`."
  def ends_with(suffix) do
    %__MODULE__{
      constraint: :ends_with,
      meta: %{"pattern" => Regex.escape(suffix) <> "$"},
      run: fn v ->
        if String.ends_with?(v, suffix),
          do: :ok,
          else: {:error, "must end with #{inspect(suffix)}"}
      end
    }
  end

  @doc "String includes `substring`."
  def includes(substring) do
    %__MODULE__{
      constraint: :includes,
      meta: %{"pattern" => Regex.escape(substring)},
      run: fn v ->
        if String.contains?(v, substring),
          do: :ok,
          else: {:error, "must include #{inspect(substring)}"}
      end
    }
  end

  @doc "String has exactly `n` graphemes."
  def exact_length(n) do
    %__MODULE__{
      constraint: :length,
      meta: %{"minLength" => n, "maxLength" => n},
      run: fn v ->
        if String.length(v) == n, do: :ok, else: {:error, "must be exactly #{n} character(s)"}
      end
    }
  end

  @doc "String is uppercase."
  def uppercase do
    %__MODULE__{
      constraint: :uppercase,
      meta: %{"pattern" => "^[^a-z]*$"},
      run: fn v -> if v == String.upcase(v), do: :ok, else: {:error, "must be uppercase"} end
    }
  end

  @doc "String is lowercase."
  def lowercase do
    %__MODULE__{
      constraint: :lowercase,
      meta: %{"pattern" => "^[^A-Z]*$"},
      run: fn v -> if v == String.downcase(v), do: :ok, else: {:error, "must be lowercase"} end
    }
  end

  @doc "String matches a named format (`:email` / `:url` / `:uuid`)."
  def format(name) when name in [:email, :url, :uuid] do
    regex = format_regex(name)

    %__MODULE__{
      constraint: :format,
      meta: %{"format" => to_string(name)},
      run: fn v ->
        if Regex.match?(regex, v), do: :ok, else: {:error, "is not a valid #{name}"}
      end
    }
  end

  # --- helpers -------------------------------------------------------------

  defp multiple?(v, n) when is_integer(v) and is_integer(n), do: rem(v, n) == 0
  defp multiple?(v, n), do: abs(:math.fmod(v * 1.0, n * 1.0)) < 1.0e-9

  defp integral?(v) when is_integer(v), do: true
  defp integral?(v) when is_float(v), do: Float.floor(v) == v
  defp integral?(_), do: false

  defp format_regex(:email), do: Raggio.Schema.email()
  defp format_regex(:url), do: Raggio.Schema.url()
  defp format_regex(:uuid), do: Raggio.Schema.uuid()
end
