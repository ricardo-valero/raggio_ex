defmodule Raggio.Schema.Adapters.JsonSchema do
  @moduledoc """
  Generate a [JSON Schema](https://json-schema.org) (draft 2020-12) document from a
  `Raggio.Schema` definition.

  Like `Raggio.Schema.Adapters.BigQuery`, this walks the `Raggio.Schema.Type` AST and
  maps each node to its JSON Schema representation:

    * primitives map to `type` (with `format` for date/datetime/decimal),
    * constraints map to keywords (`minLength`/`maxLength`/`pattern`,
      `minimum`/`maximum`, `minItems`/`maxItems`/`uniqueItems`),
    * `struct` maps to an `object` with `properties` and `required` (optional and
      defaulted fields are excluded from `required`),
    * `list` -> `array`/`items`, `tuple` -> `prefixItems`, `record` ->
      `additionalProperties`, `union` -> `anyOf`, `literal` -> `const`/`enum`,
    * `nullable` widens `type` to include `"null"`, `default` emits `default`,
    * annotations on the `:metadata` channel (`title`, `description`, `examples`)
      flow into the emitted schema object.

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

  alias Raggio.Schema.Type

  @draft "https://json-schema.org/draft/2020-12/schema"

  @formats %{
    date: "date",
    datetime: "date-time",
    decimal: "decimal"
  }

  @doc """
  Convert a schema into a JSON Schema document (a plain map).

  The top-level document includes the `$schema` draft identifier. Pass
  `root: false` to omit it (used internally for nested schemas).
  """
  @spec to_json_schema(Type.t(), keyword()) :: map()
  def to_json_schema(schema, opts \\ [])

  def to_json_schema(%Type{} = schema, opts) do
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
  @spec to_json_string(Type.t(), keyword()) :: String.t()
  def to_json_string(%Type{} = schema, opts \\ []) do
    schema |> to_json_schema(opts) |> Jason.encode!(pretty: Keyword.get(opts, :pretty, true))
  end

  # --- node dispatch -------------------------------------------------------

  defp build(%Type{} = schema) do
    schema
    |> base_for_kind()
    |> with_annotations(schema)
    |> with_nullable(schema)
    |> with_default(schema)
  end

  defp base_for_kind(%Type{kind: :string, constraints: c}) do
    %{"type" => "string"}
    |> put_some("minLength", c[:min])
    |> put_some("maxLength", c[:max])
    |> put_some("pattern", pattern_source(c[:pattern]))
  end

  defp base_for_kind(%Type{kind: :integer, constraints: c}) do
    %{"type" => "integer"}
    |> put_some("minimum", c[:min])
    |> put_some("maximum", c[:max])
  end

  defp base_for_kind(%Type{kind: :float, constraints: c}) do
    %{"type" => "number"}
    |> put_some("minimum", c[:min])
    |> put_some("maximum", c[:max])
  end

  defp base_for_kind(%Type{kind: :boolean}), do: %{"type" => "boolean"}

  # atoms serialize as strings in JSON
  defp base_for_kind(%Type{kind: :atom}), do: %{"type" => "string"}

  defp base_for_kind(%Type{kind: kind}) when kind in [:date, :datetime] do
    %{"type" => "string", "format" => @formats[kind]}
  end

  defp base_for_kind(%Type{kind: :decimal}) do
    %{"type" => "string", "format" => @formats[:decimal]}
  end

  defp base_for_kind(%Type{kind: :struct, fields: fields}) do
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

  defp base_for_kind(%Type{kind: :list, inner: inner, constraints: c}) do
    %{"type" => "array", "items" => build(inner)}
    |> put_some("minItems", c[:min])
    |> put_some("maxItems", c[:max])
    |> put_some("uniqueItems", if(c[:unique], do: true))
  end

  defp base_for_kind(%Type{kind: :tuple, elements: elements}) do
    n = length(elements)

    %{
      "type" => "array",
      "prefixItems" => Enum.map(elements, &build/1),
      "items" => false,
      "minItems" => n,
      "maxItems" => n
    }
  end

  defp base_for_kind(%Type{kind: :union, elements: elements}) do
    %{"anyOf" => Enum.map(elements, &build/1)}
  end

  defp base_for_kind(%Type{kind: :literal, values: values}) do
    case Enum.map(values, &encode_value/1) do
      [single] -> %{"const" => single}
      many -> %{"enum" => many}
    end
  end

  defp base_for_kind(%Type{kind: :record, value_type: value_type}) do
    %{"type" => "object", "additionalProperties" => build(value_type)}
  end

  # --- modifiers -----------------------------------------------------------

  defp with_annotations(json, %Type{metadata: metadata}) when is_map(metadata) do
    json
    |> put_some("title", get_meta(metadata, :title))
    |> put_some("description", get_meta(metadata, :description))
    |> put_some("examples", get_meta(metadata, :examples))
  end

  defp with_annotations(json, _schema), do: json

  # `nullable` widens the type to include "null" (or uses anyOf when there is no
  # single concrete `type` to widen, e.g. unions/literals).
  defp with_nullable(json, %Type{nullable: true}) do
    case json do
      %{"type" => type} when is_binary(type) ->
        Map.put(json, "type", [type, "null"])

      _ ->
        %{"anyOf" => [json, %{"type" => "null"}]}
    end
  end

  defp with_nullable(json, _schema), do: json

  defp with_default(json, %Type{default: nil}), do: json

  defp with_default(json, %Type{default: default}),
    do: Map.put(json, "default", encode_value(default))

  # --- helpers -------------------------------------------------------------

  # A struct field is required unless it is optional or carries a default.
  defp required_field?(%Type{optional: true}), do: false
  defp required_field?(%Type{default: default}) when not is_nil(default), do: false
  defp required_field?(%Type{}), do: true

  defp pattern_source(nil), do: nil
  defp pattern_source(%Regex{} = regex), do: Regex.source(regex)

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
