defmodule Raggio.Schema.Encoder do
  @moduledoc """
  The encode direction of the codec: walk a `Raggio.Schema.AST` and turn a decoded (typed)
  value back into its encoded (wire) representation, reversing every transform in the tree.

  Non-transform nodes encode as identity; `:struct` and `:list` recurse so nested transforms
  are reversed. (Struct-field *decode* propagation is gated on struct-building decode, §7.1;
  encode already reverses field transforms here.)
  """

  alias Raggio.Schema.{AST, Transformation}

  @spec encode(AST.t(), any()) :: {:ok, any()}
  def encode(%AST{} = schema, value), do: {:ok, do_encode(schema, value)}

  defp do_encode(
         %AST{kind: :transform, inner: inner, encoding: [%Transformation{encode: encode}]},
         value
       ) do
    do_encode(inner, encode.(value))
  end

  defp do_encode(%AST{kind: :struct, fields: fields}, value) when is_map(value) do
    Enum.reduce(fields, %{}, fn {name, field_schema}, acc ->
      case fetch_field(value, name) do
        {:ok, field_value} -> Map.put(acc, name, do_encode(field_schema, field_value))
        :error -> acc
      end
    end)
  end

  defp do_encode(%AST{kind: :list, inner: inner}, value) when is_list(value) do
    Enum.map(value, &do_encode(inner, &1))
  end

  defp do_encode(%AST{}, value), do: value

  defp fetch_field(map, name) do
    cond do
      Map.has_key?(map, name) -> {:ok, Map.get(map, name)}
      Map.has_key?(map, to_string(name)) -> {:ok, Map.get(map, to_string(name))}
      true -> :error
    end
  end
end
