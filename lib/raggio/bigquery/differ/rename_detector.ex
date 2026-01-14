defmodule Raggio.BigQuery.Differ.RenameDetector do
  @moduledoc """
  Detects potential column renames by comparing removed and added columns.

  Uses heuristics based on type similarity, name similarity (Levenshtein distance),
  and mode matching.
  """

  @type field :: %{String.t() => any()}
  @type rename_candidate :: %{from: String.t(), to: String.t(), confidence: float()}

  @spec detect([field()], [field()], keyword()) :: [rename_candidate()]
  def detect(removed, added, opts \\ []) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)

    candidates =
      for removed_field <- removed,
          added_field <- added,
          score = calculate_score(removed_field, added_field),
          score >= min_confidence do
        %{
          from: get_name(removed_field),
          to: get_name(added_field),
          confidence: score
        }
      end

    candidates
    |> Enum.group_by(& &1.from)
    |> Enum.map(fn {_from, matches} -> Enum.max_by(matches, & &1.confidence) end)
    |> Enum.sort_by(& &1.confidence, :desc)
  end

  @spec calculate_score(field(), field()) :: float()
  def calculate_score(removed, added) do
    type_score = if same_type?(removed, added), do: 0.4, else: 0.0
    mode_score = if same_mode?(removed, added), do: 0.1, else: 0.0
    name_score = name_similarity(get_name(removed), get_name(added)) * 0.5

    type_score + mode_score + name_score
  end

  @spec name_similarity(String.t(), String.t()) :: float()
  def name_similarity(name1, name2) when is_binary(name1) and is_binary(name2) do
    n1 = normalize_name(name1)
    n2 = normalize_name(name2)

    if n1 == n2 do
      1.0
    else
      distance = levenshtein_distance(n1, n2)
      max_len = max(String.length(n1), String.length(n2))

      if max_len == 0, do: 1.0, else: 1.0 - distance / max_len
    end
  end

  def name_similarity(_, _), do: 0.0

  defp normalize_name(name) do
    name |> String.downcase() |> String.replace("_", "")
  end

  defp get_name(%{"name" => name}), do: name
  defp get_name(%{name: name}), do: to_string(name)
  defp get_name(_), do: ""

  defp get_type(%{"type" => type}), do: type
  defp get_type(%{type: type}), do: to_string(type)
  defp get_type(_), do: ""

  defp get_mode(%{"mode" => mode}), do: mode
  defp get_mode(%{mode: mode}), do: to_string(mode)
  defp get_mode(_), do: "NULLABLE"

  defp same_type?(f1, f2), do: get_type(f1) == get_type(f2)
  defp same_mode?(f1, f2), do: get_mode(f1) == get_mode(f2)

  @spec levenshtein_distance(String.t(), String.t()) :: non_neg_integer()
  def levenshtein_distance(s1, s2) do
    chars1 = String.graphemes(s1)
    chars2 = String.graphemes(s2)
    len1 = length(chars1)
    len2 = length(chars2)

    cond do
      len1 == 0 -> len2
      len2 == 0 -> len1
      true -> levenshtein_matrix(chars1, chars2, len2)
    end
  end

  defp levenshtein_matrix(chars1, chars2, len2) do
    initial_row = Enum.to_list(0..len2)

    {final_row, _} =
      chars1
      |> Enum.with_index(1)
      |> Enum.reduce({initial_row, 0}, fn {c1, i}, {prev_row, _} ->
        new_row = compute_row(chars2, c1, i, prev_row)
        {Enum.reverse(new_row), i}
      end)

    List.last(final_row)
  end

  defp compute_row(chars2, c1, i, prev_row) do
    {new_row, _} =
      chars2
      |> Enum.with_index(1)
      |> Enum.reduce({[i], Enum.at(prev_row, 0)}, fn {c2, j}, {row, diag} ->
        compute_cell(c1, c2, j, row, prev_row, diag)
      end)

    new_row
  end

  defp compute_cell(c1, c2, j, row, prev_row, diag) do
    left = hd(row)
    up = Enum.at(prev_row, j)
    cost = if c1 == c2, do: 0, else: 1
    min_val = min(min(left + 1, up + 1), diag + cost)
    {[min_val | row], up}
  end

  @spec high_confidence?(rename_candidate()) :: boolean()
  def high_confidence?(%{confidence: confidence}), do: confidence > 0.8

  @spec format_candidate(rename_candidate()) :: String.t()
  def format_candidate(%{from: from, to: to, confidence: confidence}) do
    percentage = Float.round(confidence * 100, 1)
    "#{from} -> #{to} (#{percentage}% confidence)"
  end
end
