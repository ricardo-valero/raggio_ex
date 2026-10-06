defmodule Raggio.BigQuery.DDL.ParserTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.DDL.Parser
  alias Raggio.BigQuery.{TableDef, Column}
  alias Raggio.Schema.Type

  describe "parse_type/1 simple types" do
    test "parses STRING" do
      assert {:ok, %Type{kind: :string}} = Parser.parse_type("STRING")
    end

    test "parses INT64" do
      assert {:ok, %Type{kind: :integer}} = Parser.parse_type("INT64")
    end

    test "parses INTEGER as alias for INT64" do
      assert {:ok, %Type{kind: :integer}} = Parser.parse_type("INTEGER")
    end

    test "parses FLOAT64" do
      assert {:ok, %Type{kind: :float}} = Parser.parse_type("FLOAT64")
    end

    test "parses BOOL" do
      assert {:ok, %Type{kind: :boolean}} = Parser.parse_type("BOOL")
    end

    test "parses BOOLEAN as alias" do
      assert {:ok, %Type{kind: :boolean}} = Parser.parse_type("BOOLEAN")
    end

    test "parses NUMERIC" do
      assert {:ok, %Type{kind: :decimal}} = Parser.parse_type("NUMERIC")
    end

    test "parses BIGNUMERIC" do
      assert {:ok, %Type{kind: :decimal}} = Parser.parse_type("BIGNUMERIC")
    end

    test "parses DATETIME" do
      assert {:ok, %Type{kind: :datetime}} = Parser.parse_type("DATETIME")
    end

    test "parses DATE" do
      assert {:ok, %Type{kind: :date}} = Parser.parse_type("DATE")
    end

    test "parses TIMESTAMP" do
      assert {:ok, %Type{kind: :timestamp}} = Parser.parse_type("TIMESTAMP")
    end

    test "parses BYTES" do
      assert {:ok, %Type{kind: :binary}} = Parser.parse_type("BYTES")
    end

    test "parses TIME" do
      assert {:ok, %Type{kind: :time}} = Parser.parse_type("TIME")
    end

    test "is case-insensitive" do
      assert {:ok, %Type{kind: :string}} = Parser.parse_type("string")
      assert {:ok, %Type{kind: :string}} = Parser.parse_type("String")
    end
  end

  describe "parse_type/1 ARRAY types" do
    test "parses ARRAY<STRING>" do
      assert {:ok, %Type{kind: :list, inner: %Type{kind: :string}}} =
               Parser.parse_type("ARRAY<STRING>")
    end

    test "parses ARRAY<INT64>" do
      assert {:ok, %Type{kind: :list, inner: %Type{kind: :integer}}} =
               Parser.parse_type("ARRAY<INT64>")
    end

    test "handles whitespace" do
      assert {:ok, %Type{kind: :list, inner: %Type{kind: :string}}} =
               Parser.parse_type("ARRAY< STRING >")
    end
  end

  describe "parse_type/1 STRUCT types" do
    test "parses STRUCT<field1 type1, field2 type2>" do
      {:ok, type} = Parser.parse_type("STRUCT<name STRING, age INT64>")

      assert type.kind == :struct
      assert length(type.fields) == 2

      {name1, type1} = Enum.at(type.fields, 0)
      assert name1 == :name
      assert type1.kind == :string

      {name2, type2} = Enum.at(type.fields, 1)
      assert name2 == :age
      assert type2.kind == :integer
    end

    test "parses STRUCT with single field" do
      {:ok, type} = Parser.parse_type("STRUCT<id STRING>")

      assert type.kind == :struct
      assert length(type.fields) == 1
    end

    test "handles whitespace in STRUCT" do
      {:ok, type} = Parser.parse_type("STRUCT< name STRING , age INT64 >")

      assert type.kind == :struct
      assert length(type.fields) == 2
    end
  end

  describe "parse_type/1 nested types" do
    test "parses nested STRUCT<ARRAY<STRUCT<...>>>" do
      ddl = "STRUCT<tags ARRAY<STRING>, meta STRUCT<key STRING, value STRING>>"
      {:ok, type} = Parser.parse_type(ddl)

      assert type.kind == :struct
      assert length(type.fields) == 2

      # First field: tags ARRAY<STRING>
      {:tags, tags_type} = Enum.at(type.fields, 0)
      assert tags_type.kind == :list
      assert tags_type.inner.kind == :string

      # Second field: meta STRUCT<...>
      {:meta, meta_type} = Enum.at(type.fields, 1)
      assert meta_type.kind == :struct
      assert length(meta_type.fields) == 2
    end

    test "parses ARRAY<STRUCT<...>>" do
      {:ok, type} = Parser.parse_type("ARRAY<STRUCT<id STRING, value INT64>>")

      assert type.kind == :list
      assert type.inner.kind == :struct
      assert length(type.inner.fields) == 2
    end
  end

  describe "parse_create_table/1" do
    test "parses full CREATE TABLE statement" do
      ddl = """
      CREATE TABLE `project.dataset.events` (
        id STRING NOT NULL,
        user_id STRING,
        count INT64
      )
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.table_name == "events"
      assert parsed.dataset == "dataset"
      assert parsed.project == "project"
      assert length(parsed.columns) == 3
    end

    test "parses table with schema prefix only" do
      ddl = """
      CREATE TABLE `dataset.events` (
        id STRING
      )
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.table_name == "events"
      assert parsed.dataset == "dataset"
      assert parsed.project == nil
    end

    test "parses table with simple name" do
      ddl = """
      CREATE TABLE events (
        id STRING
      )
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.table_name == "events"
    end

    test "extracts PARTITION BY" do
      ddl = """
      CREATE TABLE events (
        id STRING,
        created_at DATETIME
      )
      PARTITION BY DATE(created_at)
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.partition_by != nil
      assert parsed.partition_by.column == "created_at"
    end

    test "extracts CLUSTER BY" do
      ddl = """
      CREATE TABLE events (
        id STRING,
        user_id STRING,
        event_type STRING
      )
      CLUSTER BY user_id, event_type
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.cluster_by == ["user_id", "event_type"]
    end

    test "handles IF NOT EXISTS" do
      ddl = """
      CREATE TABLE IF NOT EXISTS events (
        id STRING
      )
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.table_name == "events"
      assert parsed.if_not_exists == true
    end

    test "handles OPTIONS" do
      ddl = """
      CREATE TABLE events (
        id STRING
      )
      OPTIONS (description = "Event log")
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)

      assert parsed.options[:description] == "Event log"
    end
  end

  describe "parse error handling" do
    test "returns error for invalid DDL" do
      assert {:error, _} = Parser.parse_create_table("NOT VALID DDL")
    end

    test "returns error for invalid type" do
      assert {:error, _} = Parser.parse_type("INVALID_TYPE")
    end

    test "error includes position information" do
      {:error, error} = Parser.parse_create_table("CREATE TABL events ()")

      assert is_binary(error) or is_map(error)
    end
  end

  describe "to_table_def/1" do
    test "converts parsed DDL to TableDef struct" do
      ddl = """
      CREATE TABLE `project.dataset.events` (
        id STRING NOT NULL,
        user_id STRING,
        created_at DATETIME NOT NULL
      )
      PARTITION BY DATE(created_at)
      CLUSTER BY user_id
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)
      {:ok, table_def} = Parser.to_table_def(parsed)

      assert %TableDef{} = table_def
      assert table_def.name == "events"
      assert length(table_def.columns) == 3

      id_col = Enum.find(table_def.columns, &(&1.name == :id))
      assert id_col.mode == :required
      assert id_col.type.kind == :string

      user_col = Enum.find(table_def.columns, &(&1.name == :user_id))
      assert user_col.mode == :nullable

      assert table_def.partition_by != nil
      assert table_def.cluster_by == [:user_id]
    end

    test "handles STRUCT columns" do
      ddl = """
      CREATE TABLE users (
        id STRING,
        address STRUCT<city STRING, zip STRING>
      )
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)
      {:ok, table_def} = Parser.to_table_def(parsed)

      address_col = Enum.find(table_def.columns, &(&1.name == :address))
      assert address_col.type.kind == :struct
      assert length(address_col.type.fields) == 2
    end

    test "handles ARRAY columns" do
      ddl = """
      CREATE TABLE users (
        id STRING,
        tags ARRAY<STRING>
      )
      """

      {:ok, parsed} = Parser.parse_create_table(ddl)
      {:ok, table_def} = Parser.to_table_def(parsed)

      tags_col = Enum.find(table_def.columns, &(&1.name == :tags))
      assert tags_col.type.kind == :list
      assert tags_col.type.inner.kind == :string
    end
  end

  describe "round-trip: TableDef -> DDL -> parse -> TableDef" do
    test "preserves structure" do
      original = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :user_id, type: %Type{kind: :string}, mode: :nullable},
          %Column{name: :count, type: %Type{kind: :integer}, mode: :nullable}
        ],
        partition_by: {:field, :created_at, :day},
        cluster_by: [:user_id]
      }

      # Add created_at column for partition
      original = %{
        original
        | columns:
            original.columns ++
              [%Column{name: :created_at, type: %Type{kind: :datetime}, mode: :required}]
      }

      # Generate DDL
      ddl = TableDef.to_ddl(original, "project.dataset")

      # Parse back
      {:ok, parsed} = Parser.parse_create_table(ddl)
      {:ok, round_tripped} = Parser.to_table_def(parsed)

      # Verify structure preserved
      assert round_tripped.name == original.name
      assert length(round_tripped.columns) == length(original.columns)

      # Verify columns match
      for orig_col <- original.columns do
        rt_col = Enum.find(round_tripped.columns, &(&1.name == orig_col.name))
        assert rt_col != nil, "Column #{orig_col.name} not found"
        assert rt_col.type.kind == orig_col.type.kind
        assert rt_col.mode == orig_col.mode
      end
    end
  end
end
