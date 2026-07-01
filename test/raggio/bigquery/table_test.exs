defmodule Raggio.BigQuery.TableTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema

  defmodule BasicTable do
    use Raggio.BigQuery.Table

    @impl true
    def __dataset__, do: "test_dataset"

    @impl true
    def __table__, do: "basic_table"

    @impl true
    def __schema__ do
      Schema.struct([
        {:id, Schema.string()},
        {:name, Schema.string() |> Schema.nullable()},
        {:count, Schema.integer()}
      ])
    end
  end

  defmodule PartitionedTable do
    use Raggio.BigQuery.Table

    @impl true
    def __dataset__, do: "analytics"

    @impl true
    def __table__, do: "events"

    @impl true
    def __schema__ do
      Schema.struct([
        {:event_id, Schema.string()},
        {:event_type, Schema.string()},
        {:event_date, Schema.date()},
        {:payload, Schema.string() |> Schema.optional()}
      ])
    end

    @impl true
    def __time_partitioning__, do: [field: :event_date, type: :day]

    @impl true
    def __clustering__, do: [:event_type]
  end

  describe "behaviour compliance" do
    test "BasicTable implements Table behaviour" do
      behaviours = BasicTable.__info__(:attributes)[:behaviour] || []
      assert Raggio.BigQuery.Table in behaviours
    end

    test "PartitionedTable implements Table behaviour" do
      behaviours = PartitionedTable.__info__(:attributes)[:behaviour] || []
      assert Raggio.BigQuery.Table in behaviours
    end
  end

  describe "__dataset__/0" do
    test "returns dataset name" do
      assert BasicTable.__dataset__() == "test_dataset"
      assert PartitionedTable.__dataset__() == "analytics"
    end
  end

  describe "__table__/0" do
    test "returns table name" do
      assert BasicTable.__table__() == "basic_table"
      assert PartitionedTable.__table__() == "events"
    end
  end

  describe "__schema__/0" do
    test "returns Raggio.Schema struct type" do
      schema = BasicTable.__schema__()

      assert %Schema.AST{kind: :struct, fields: fields} = schema
      assert is_list(fields)
      assert Keyword.has_key?(fields, :id)
      assert Keyword.has_key?(fields, :name)
      assert Keyword.has_key?(fields, :count)
    end

    test "schema field types are correct" do
      %Schema.AST{fields: fields} = BasicTable.__schema__()

      {_, id_type} = List.keyfind(fields, :id, 0)
      assert id_type.kind == :string

      {_, count_type} = List.keyfind(fields, :count, 0)
      assert count_type.kind == :integer
    end
  end

  describe "__qualified_name__/0" do
    test "returns dataset.table format" do
      assert BasicTable.__qualified_name__() == "test_dataset.basic_table"
      assert PartitionedTable.__qualified_name__() == "analytics.events"
    end
  end

  describe "__time_partitioning__/0" do
    test "returns nil by default" do
      assert BasicTable.__time_partitioning__() == nil
    end

    test "returns partitioning config when defined" do
      partition = PartitionedTable.__time_partitioning__()

      assert partition[:field] == :event_date
      assert partition[:type] == :day
    end
  end

  describe "__clustering__/0" do
    test "returns nil by default" do
      assert BasicTable.__clustering__() == nil
    end

    test "returns clustering fields when defined" do
      assert PartitionedTable.__clustering__() == [:event_type]
    end
  end

  describe "to_create_table_ddl/0" do
    test "generates CREATE TABLE DDL for basic table" do
      ddl = BasicTable.to_create_table_ddl()

      assert String.contains?(ddl, "CREATE TABLE")
      assert String.contains?(ddl, "test_dataset.basic_table")
      assert String.contains?(ddl, "id STRING NOT NULL")
      assert String.contains?(ddl, "name STRING")
      assert String.contains?(ddl, "count INT64 NOT NULL")
    end

    test "generates DDL with partitioning" do
      ddl = PartitionedTable.to_create_table_ddl()

      assert String.contains?(ddl, "PARTITION BY")
      assert String.contains?(ddl, "event_date")
    end

    test "generates DDL with clustering" do
      ddl = PartitionedTable.to_create_table_ddl()

      assert String.contains?(ddl, "CLUSTER BY")
      assert String.contains?(ddl, "event_type")
    end
  end

  describe "to_bigquery_schema/0" do
    test "generates BigQuery REST API schema format" do
      schema = BasicTable.to_bigquery_schema()

      assert is_map(schema)
      assert Map.has_key?(schema, "fields")
      assert is_list(schema["fields"])

      field_names = Enum.map(schema["fields"], & &1["name"])
      assert "id" in field_names
      assert "name" in field_names
      assert "count" in field_names
    end

    test "includes correct types" do
      schema = BasicTable.to_bigquery_schema()

      id_field = Enum.find(schema["fields"], &(&1["name"] == "id"))
      assert id_field["type"] == "STRING"
      assert id_field["mode"] == "REQUIRED"

      name_field = Enum.find(schema["fields"], &(&1["name"] == "name"))
      assert name_field["type"] == "STRING"
      assert name_field["mode"] == "NULLABLE"

      count_field = Enum.find(schema["fields"], &(&1["name"] == "count"))
      assert count_field["type"] == "INT64"
      assert count_field["mode"] == "REQUIRED"
    end
  end
end
