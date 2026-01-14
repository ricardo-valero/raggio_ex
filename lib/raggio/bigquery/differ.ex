defmodule Raggio.BigQuery.Differ do
  @moduledoc """
  Compares local schema definitions to remote BigQuery table schemas.

  Produces a list of `Change` structs that can be used to generate DDL or display to users.
  """

  alias Raggio.BigQuery.Differ.{Change, RenameDetector}

  @type diff_result :: {:ok, [Change.t()]} | {:error, term()}

  @spec diff(module(), module(), keyword()) :: diff_result()
  def diff(repo, table_module, opts \\ []) do
    detect_renames = Keyword.get(opts, :detect_renames, true)
    min_confidence = Keyword.get(opts, :min_rename_confidence, 0.5)

    dataset = table_module.__dataset__()
    table = table_module.__table__()
    qualified_table = "#{dataset}.#{table}"

    with {:ok, local_fields} <- get_local_fields(table_module),
         {:ok, remote_result} <- get_remote_schema(repo, dataset, table) do
      case remote_result do
        :not_found ->
          {:ok, [create_table_change(qualified_table, local_fields)]}

        remote_fields ->
          changes =
            compare_fields(
              qualified_table,
              local_fields,
              remote_fields,
              detect_renames,
              min_confidence
            )

          {:ok, Change.sort(changes)}
      end
    end
  end

  @spec compare([map()], [map()], String.t(), keyword()) :: [Change.t()]
  def compare(local_fields, remote_fields, table, opts \\ []) do
    detect_renames = Keyword.get(opts, :detect_renames, true)
    min_confidence = Keyword.get(opts, :min_rename_confidence, 0.5)

    compare_fields(table, local_fields, remote_fields, detect_renames, min_confidence)
    |> Change.sort()
  end

  defp get_local_fields(table_module) do
    schema = table_module.to_bigquery_schema()
    {:ok, schema["fields"]}
  end

  defp get_remote_schema(repo, dataset, table) do
    case repo.get_table_schema(dataset, table) do
      {:ok, %{"schema" => %{"fields" => fields}}} ->
        {:ok, fields}

      {:ok, %{"schema" => _}} ->
        {:ok, []}

      {:error, :not_found} ->
        {:ok, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_table_change(table, local_fields) do
    Change.new(:create_table, table, details: %{fields: local_fields})
  end

  defp compare_fields(table, local_fields, remote_fields, detect_renames, min_confidence) do
    local_by_name = index_by_name(local_fields)
    remote_by_name = index_by_name(remote_fields)

    local_names = MapSet.new(Map.keys(local_by_name))
    remote_names = MapSet.new(Map.keys(remote_by_name))

    added_names = MapSet.difference(local_names, remote_names)
    removed_names = MapSet.difference(remote_names, local_names)
    common_names = MapSet.intersection(local_names, remote_names)

    {rename_changes, remaining_added, remaining_removed} =
      if detect_renames and MapSet.size(added_names) > 0 and MapSet.size(removed_names) > 0 do
        detect_and_process_renames(
          table,
          MapSet.to_list(added_names),
          MapSet.to_list(removed_names),
          local_by_name,
          remote_by_name,
          min_confidence
        )
      else
        {[], MapSet.to_list(added_names), MapSet.to_list(removed_names)}
      end

    add_changes =
      Enum.map(remaining_added, fn name ->
        field = local_by_name[name]

        Change.new(:add_column, table,
          column: name,
          details: %{
            bq_type: field["type"],
            mode: field["mode"],
            description: field["description"]
          }
        )
      end)

    drop_changes =
      Enum.map(remaining_removed, fn name ->
        field = remote_by_name[name]

        Change.new(:drop_column, table,
          column: name,
          details: %{
            bq_type: field["type"],
            mode: field["mode"]
          }
        )
      end)

    common_changes =
      common_names
      |> MapSet.to_list()
      |> Enum.flat_map(fn name ->
        local = local_by_name[name]
        remote = remote_by_name[name]
        compare_column(table, name, local, remote)
      end)

    rename_changes ++ add_changes ++ drop_changes ++ common_changes
  end

  defp index_by_name(fields) do
    Map.new(fields, fn field ->
      name = field["name"] || to_string(field[:name])
      {name, field}
    end)
  end

  defp detect_and_process_renames(
         table,
         added_names,
         removed_names,
         local_by_name,
         remote_by_name,
         min_confidence
       ) do
    added_fields = Enum.map(added_names, &local_by_name[&1])
    removed_fields = Enum.map(removed_names, &remote_by_name[&1])

    candidates =
      RenameDetector.detect(removed_fields, added_fields, min_confidence: min_confidence)

    rename_changes =
      candidates
      |> Enum.filter(&RenameDetector.high_confidence?/1)
      |> Enum.map(fn %{from: from, to: to, confidence: confidence} ->
        Change.new(:rename_column, table,
          column: to,
          details: %{from: from, to: to, confidence: confidence}
        )
      end)

    renamed_from = Enum.map(rename_changes, &get_in(&1.details, [:from]))
    renamed_to = Enum.map(rename_changes, &get_in(&1.details, [:to]))

    remaining_added = Enum.reject(added_names, &(&1 in renamed_to))
    remaining_removed = Enum.reject(removed_names, &(&1 in renamed_from))

    {rename_changes, remaining_added, remaining_removed}
  end

  defp compare_column(table, name, local, remote) do
    changes = []

    changes =
      if local["type"] != remote["type"] do
        change =
          Change.new(:change_type, table,
            column: name,
            details: %{from: remote["type"], to: local["type"]}
          )

        [change | changes]
      else
        changes
      end

    changes =
      if local["mode"] != remote["mode"] do
        change =
          Change.new(:change_mode, table,
            column: name,
            details: %{from: remote["mode"], to: local["mode"]}
          )

        [change | changes]
      else
        changes
      end

    local_desc = local["description"]
    remote_desc = remote["description"]

    changes =
      if local_desc != remote_desc and local_desc != nil do
        change =
          Change.new(:change_description, table,
            column: name,
            details: %{from: remote_desc, to: local_desc}
          )

        [change | changes]
      else
        changes
      end

    changes
  end

  @spec summary([Change.t()]) :: map()
  def summary(changes) do
    changes
    |> Enum.group_by(& &1.type)
    |> Enum.into(%{}, fn {type, list} -> {type, length(list)} end)
  end

  @spec has_destructive?([Change.t()]) :: boolean()
  def has_destructive?(changes) do
    Enum.any?(changes, & &1.destructive)
  end

  @spec destructive_changes([Change.t()]) :: [Change.t()]
  def destructive_changes(changes) do
    Enum.filter(changes, & &1.destructive)
  end
end
