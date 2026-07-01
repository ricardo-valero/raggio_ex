defmodule Raggio.Schema.Adapters.JsonSchema do
  @moduledoc """
  Generate a [JSON Schema](https://json-schema.org) (draft 2020-12) document from a
  `Raggio.Schema` definition.

  A projection of the uniform `Raggio.Schema.AST`: map the node `kind` to a JSON type,
  then **fold each check's `meta`** into the object (so the adapter needs no knowledge of
  individual constraints), then layer on composite structure, per-field `context`
  (`required`/`nullable`/`default`), and annotations (`title`/`description`/`examples`).

  ## Example

      iex> schema = Raggio.Schema.struct([
      ...>   {:name, Raggio.Schema.string(min: 1)},
      ...>   {:age, Raggio.Schema.optional(Raggio.Schema.integer(min: 0))}
      ...> ])
      iex> doc = Raggio.Schema.Adapters.JsonSchema.to_json_schema(schema)
      iex> doc["type"]
      "object"
      iex> doc["required"]
      ["name"]
  """

  alias Raggio.Schema.{AST, Context}

  @draft "https://json-schema.org/draft/2020-12/schema"

  @formats %{date: "date", datetime: "date-time", decimal: "decimal"}

  @doc """
  Convert a schema into a JSON Schema document (a plain map).

  The top-level document includes the `$schema` draft identifier. Pass `root: false` to
  omit it (used internally for nested schemas).
  """
  @spec to_json_schema(AST.t(), keyword()) :: map()
  def to_json_schema(schema, opts \\ [])

  def to_json_schema(%AST{} = schema, opts) do
    base = build(schema)

    if Keyword.get(opts, :root, true) do
      Map.put(base, "$schema", @draft)
    else
      base
    end
  end

  @doc """
  Convert a schema into a JSON-encoded string. Requires `Jason`.
  """
  @spec to_json_string(AST.t(), keyword()) :: String.t()
  def to_json_string(%AST{} = schema, opts \\ []) do
    schema |> to_json_schema(opts) |> Jason.encode!(pretty: Keyword.get(opts, :pretty, true))
  end

  # --- node dispatch -------------------------------------------------------

  defp build(%AST{} = schema) do
    schema
    |> base_for_kind()
    |> fold_checks(schema)
    |> with_annotations(schema)
    |> with_nullable(schema)
    |> with_default(schema)
  end

  defp base_for_kind(%AST{kind: :string}), do: %{"type" => "string"}
  defp base_for_kind(%AST{kind: :integer}), do: %{"type" => "integer"}
  defp base_for_kind(%AST{kind: :float}), do: %{"type" => "number"}
  defp base_for_kind(%AST{kind: :boolean}), do: %{"type" => "boolean"}
  # atoms serialize as strings in JSON
  defp base_for_kind(%AST{kind: :atom}), do: %{"type" => "string"}

  defp base_for_kind(%AST{kind: kind}) when kind in [:date, :datetime, :decimal] do
    %{"type" => "string", "format" => @formats[kind]}
  end

  defp base_for_kind(%AST{kind: :struct, fields: fields}) do
    properties =
      for {name, field_schema} <- fields, into: %{} do
        {to_string(name), build(field_schema)}
      end

    required =
      for {name, field_schema} <- fields,
          required_field?(field_schema),
          do: to_string(name)

    %{"type" => "object", "properties" => properties}
    |> put_unless_empty("required", required)
  end

  defp base_for_kind(%AST{kind: :list, inner: inner}) do
    %{"type" => "array", "items" => build(inner)}
  end

  defp base_for_kind(%AST{kind: :tuple, elements: elements}) do
    n = length(elements)

    %{
      "type" => "array",
      "prefixItems" => Enum.map(elements, &build/1),
      "items" => false,
      "minItems" => n,
      "maxItems" => n
    }
  end

  defp base_for_kind(%AST{kind: :union, elements: elements}) do
    %{"anyOf" => Enum.map(elements, &build/1)}
  end

  defp base_for_kind(%AST{kind: :literal, values: values}) do
    case Enum.map(values, &encode_value/1) do
      [single] -> %{"const" => single}
      many -> %{"enum" => many}
    end
  end

  defp base_for_kind(%AST{kind: :record, value_type: value_type}) do
    %{"type" => "object", "additionalProperties" => build(value_type)}
  end

  # --- slots ---------------------------------------------------------------

  # Fold each check's machine-readable descriptor into the schema object — the adapter
  # stays agnostic of what any individual check does.
  defp fold_checks(json, %AST{checks: checks}) do
    Enum.reduce(checks, json, fn check, acc -> Map.merge(acc, check.meta) end)
  end

  defp with_annotations(json, %AST{metadata: metadata}) when is_map(metadata) do
    json
    |> put_some("title", get_meta(metadata, :title))
    |> put_some("description", get_meta(metadata, :description))
    |> put_some("examples", get_meta(metadata, :examples))
  end

  defp with_annotations(json, _schema), do: json

  # `nullable` widens the type to include "null" (or uses anyOf when there is no single
  # concrete `type` to widen, e.g. unions/literals).
  defp with_nullable(json, %AST{context: %Context{nullable?: true}}) do
    case json do
      %{"type" => type} when is_binary(type) -> Map.put(json, "type", [type, "null"])
      _ -> %{"anyOf" => [json, %{"type" => "null"}]}
    end
  end

  defp with_nullable(json, _schema), do: json

  defp with_default(json, %AST{context: %Context{default: :none}}), do: json

  defp with_default(json, %AST{context: %Context{default: default}}),
    do: Map.put(json, "default", encode_value(default))

  # --- helpers -------------------------------------------------------------

  # A struct field is required unless it is optional or carries a default.
  defp required_field?(%AST{context: %Context{optional?: true}}), do: false
  defp required_field?(%AST{context: %Context{default: default}}) when default != :none, do: false
  defp required_field?(%AST{}), do: true

  defp get_meta(metadata, key) do
    Map.get(metadata, key) || Map.get(metadata, to_string(key))
  end

  defp encode_value(value) when value in [true, false, nil], do: value
  defp encode_value(value) when is_atom(value), do: Atom.to_string(value)
  defp encode_value(value), do: value

  defp put_some(map, _key, nil), do: map
  defp put_some(map, key, value), do: Map.put(map, key, value)

  defp put_unless_empty(map, _key, []), do: map
  defp put_unless_empty(map, key, value), do: Map.put(map, key, value)
end
