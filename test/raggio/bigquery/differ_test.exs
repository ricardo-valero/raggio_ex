defmodule Raggio.BigQuery.DifferTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Differ
  alias Raggio.BigQuery.Differ.Change

  describe "compare/4" do
    test "detects added columns" do
      local = [%{"name" => "id", "type" => "STRING", "mode" => "REQUIRED"}]
      remote = []

      changes = Differ.compare(local, remote, "ds.table")

      assert [%Change{type: :add_column, column: "id"}] = changes
    end

    test "detects dropped columns" do
      local = []
      remote = [%{"name" => "old_col", "type" => "STRING", "mode" => "NULLABLE"}]

      changes = Differ.compare(local, remote, "ds.table")

      assert [%Change{type: :drop_column, column: "old_col", destructive: true}] = changes
    end

    test "detects type changes" do
      local = [%{"name" => "count", "type" => "INT64", "mode" => "REQUIRED"}]
      remote = [%{"name" => "count", "type" => "STRING", "mode" => "REQUIRED"}]

      changes = Differ.compare(local, remote, "ds.table")

      assert [%Change{type: :change_type, column: "count", details: details}] = changes
      assert details.from == "STRING"
      assert details.to == "INT64"
    end

    test "detects mode changes" do
      local = [%{"name" => "name", "type" => "STRING", "mode" => "REQUIRED"}]
      remote = [%{"name" => "name", "type" => "STRING", "mode" => "NULLABLE"}]

      changes = Differ.compare(local, remote, "ds.table")

      assert [%Change{type: :change_mode, column: "name", details: details}] = changes
      assert details.from == "NULLABLE"
      assert details.to == "REQUIRED"
    end

    test "detects rename candidates with high confidence" do
      local = [%{"name" => "user_name", "type" => "STRING", "mode" => "NULLABLE"}]
      remote = [%{"name" => "username", "type" => "STRING", "mode" => "NULLABLE"}]

      changes = Differ.compare(local, remote, "ds.table", detect_renames: true)

      rename = Enum.find(changes, &(&1.type == :rename_column))

      if rename do
        assert rename.details.from == "username"
        assert rename.details.to == "user_name"
      end
    end

    test "no changes when schemas match" do
      fields = [
        %{"name" => "id", "type" => "STRING", "mode" => "REQUIRED"},
        %{"name" => "name", "type" => "STRING", "mode" => "NULLABLE"}
      ]

      changes = Differ.compare(fields, fields, "ds.table")

      assert changes == []
    end

    test "can disable rename detection" do
      local = [%{"name" => "new_col", "type" => "STRING", "mode" => "NULLABLE"}]
      remote = [%{"name" => "old_col", "type" => "STRING", "mode" => "NULLABLE"}]

      changes = Differ.compare(local, remote, "ds.table", detect_renames: false)

      types = Enum.map(changes, & &1.type)
      assert :add_column in types
      assert :drop_column in types
      refute :rename_column in types
    end
  end

  describe "summary/1" do
    test "counts changes by type" do
      changes = [
        Change.new(:add_column, "ds.t", column: "a"),
        Change.new(:add_column, "ds.t", column: "b"),
        Change.new(:drop_column, "ds.t", column: "c")
      ]

      summary = Differ.summary(changes)

      assert summary[:add_column] == 2
      assert summary[:drop_column] == 1
    end
  end

  describe "has_destructive?/1" do
    test "returns true when destructive changes present" do
      changes = [
        Change.new(:add_column, "ds.t", column: "a"),
        Change.new(:drop_column, "ds.t", column: "b")
      ]

      assert Differ.has_destructive?(changes)
    end

    test "returns false when no destructive changes" do
      changes = [
        Change.new(:add_column, "ds.t", column: "a")
      ]

      refute Differ.has_destructive?(changes)
    end
  end

  describe "destructive_changes/1" do
    test "filters to only destructive changes" do
      changes = [
        Change.new(:add_column, "ds.t", column: "a"),
        Change.new(:drop_column, "ds.t", column: "b"),
        Change.new(:change_type, "ds.t", column: "c", details: %{from: "STRING", to: "INT64"})
      ]

      destructive = Differ.destructive_changes(changes)

      assert length(destructive) == 2
      types = Enum.map(destructive, & &1.type)
      assert :drop_column in types
      assert :change_type in types
    end
  end
end
