defmodule Raggio.Schema.Adapters.BigQueryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Raggio.Schema.Adapters.BigQuery, as: BQAdapter
  alias Raggio.Schema.Type
  alias Raggio.BigQuery.{Column, TableDef}

  describe "adapter_namespace/0" do
    test "returns :bigquery" do
      assert BQAdapter.adapter_namespace() == :bigquery
    end
  end

  describe "to_schema/1" do
    test "converts TableDef to Type" do
      table_def = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :count, type: %Type{kind: :integer}, mode: :nullable}
        ]
      }

      result = BQAdapter.to_schema(table_def)

      assert %Type{kind: :struct} = result
      assert length(result.fields) == 2

      # Check first field
      {name1, type1} = Enum.at(result.fields, 0)
      assert name1 == :id
      assert type1.kind == :string
      assert type1.nullable == false

      # Check second field
      {name2, type2} = Enum.at(result.fields, 1)
      assert name2 == :count
      assert type2.kind == :integer
      assert type2.nullable == true
    end

    test "preserves metadata under :bigquery namespace" do
      table_def = %TableDef{
        name: "events",
        columns: [%Column{name: :id, type: %Type{kind: :string}, mode: :required}],
        partition_by: {:field, :created_at, :day},
        cluster_by: [:user_id, :event_type],
        description: "Event tracking table"
      }

      result = BQAdapter.to_schema(table_def)

      assert result.metadata[:bigquery][:table_name] == "events"
      assert result.metadata[:bigquery][:partition_by] == {:field, :created_at, :day}
      assert result.metadata[:bigquery][:cluster_by] == [:user_id, :event_type]
      assert result.metadata[:bigquery][:description] == "Event tracking table"
      # Also preserved at root level for portability
      assert result.metadata[:description] == "Event tracking table"
    end

    test "converts repeated mode to list type" do
      table_def = %TableDef{
        name: "users",
        columns: [
          %Column{name: :tags, type: %Type{kind: :string}, mode: :repeated}
        ]
      }

      result = BQAdapter.to_schema(table_def)
      {_name, type} = Enum.at(result.fields, 0)

      assert type.kind == :list
      assert type.inner.kind == :string
    end

    test "preserves column descriptions in field metadata" do
      table_def = %TableDef{
        name: "users",
        columns: [
          %Column{
            name: :id,
            type: %Type{kind: :string},
            mode: :required,
            description: "Unique user identifier"
          }
        ]
      }

      result = BQAdapter.to_schema(table_def)
      {_name, type} = Enum.at(result.fields, 0)

      assert type.metadata[:description] == "Unique user identifier"
    end
  end

  describe "from_schema/1" do
    test "converts Type to {:ok, TableDef}" do
      schema = %Type{
        kind: :struct,
        fields: [
          {:id, %Type{kind: :string, nullable: false, optional: false}},
          {:email, %Type{kind: :string, nullable: true}}
        ],
        metadata: %{bigquery: %{table_name: "users"}}
      }

      assert {:ok, table_def} = BQAdapter.from_schema(schema)
      assert table_def.name == "users"
      assert length(table_def.columns) == 2

      id_col = Enum.find(table_def.columns, &(&1.name == :id))
      assert id_col.mode == :required
      assert id_col.type.kind == :string

      email_col = Enum.find(table_def.columns, &(&1.name == :email))
      assert email_col.mode == :nullable
    end

    test "returns {:error, _} for incompatible types" do
      schema = %Type{kind: :string}

      assert {:error, {:unsupported_type, :string, _}} = BQAdapter.from_schema(schema)
    end

    test "uses name option when provided" do
      schema = %Type{
        kind: :struct,
        fields: [{:id, %Type{kind: :string}}]
      }

      assert {:ok, table_def} = BQAdapter.from_schema(schema, name: "custom_table")
      assert table_def.name == "custom_table"
    end

    test "preserves partition_by from metadata" do
      schema = %Type{
        kind: :struct,
        fields: [{:id, %Type{kind: :string}}],
        metadata: %{
          bigquery: %{
            table_name: "events",
            partition_by: {:field, :created_at, :day}
          }
        }
      }

      assert {:ok, table_def} = BQAdapter.from_schema(schema)
      assert table_def.partition_by == {:field, :created_at, :day}
    end

    test "converts list type to repeated mode" do
      schema = %Type{
        kind: :struct,
        fields: [
          {:tags, %Type{kind: :list, inner: %Type{kind: :string}}}
        ]
      }

      assert {:ok, table_def} = BQAdapter.from_schema(schema, name: "test")

      tags_col = Enum.find(table_def.columns, &(&1.name == :tags))
      assert tags_col.mode == :repeated
      assert tags_col.type.kind == :string
    end
  end

  describe "from_schema/1 foreign metadata warning" do
    test "emits warning for foreign adapter metadata" do
      schema = %Type{
        kind: :struct,
        fields: [{:id, %Type{kind: :string}}],
        metadata: %{
          api: %{endpoint: "/users", method: "GET"},
          bigquery: %{table_name: "users"}
        }
      }

      log =
        capture_log(fn ->
          BQAdapter.from_schema(schema)
        end)

      assert log =~ "BigQuery adapter ignoring api metadata"
      assert log =~ "endpoint"
    end

    test "does not warn when warn: false option is set" do
      schema = %Type{
        kind: :struct,
        fields: [{:id, %Type{kind: :string}}],
        metadata: %{
          api: %{endpoint: "/users"}
        }
      }

      log =
        capture_log(fn ->
          BQAdapter.from_schema(schema, name: "test", warn: false)
        end)

      assert log == ""
    end
  end

  describe "round-trip conversion" do
    test "TableDef -> to_schema -> from_schema -> TableDef preserves structure" do
      original = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :user_id, type: %Type{kind: :string}, mode: :nullable},
          %Column{name: :tags, type: %Type{kind: :string}, mode: :repeated},
          %Column{name: :count, type: %Type{kind: :integer}, mode: :nullable}
        ],
        partition_by: {:field, :created_at, :day},
        cluster_by: [:user_id],
        description: "Event log"
      }

      # Convert to canonical
      canonical = BQAdapter.to_schema(original)

      # Convert back to TableDef
      assert {:ok, round_tripped} = BQAdapter.from_schema(canonical)

      # Verify structure preserved
      assert round_tripped.name == original.name
      assert length(round_tripped.columns) == length(original.columns)
      assert round_tripped.partition_by == original.partition_by
      assert round_tripped.cluster_by == original.cluster_by
      assert round_tripped.description == original.description

      # Verify each column
      Enum.zip(original.columns, round_tripped.columns)
      |> Enum.each(fn {orig, rt} ->
        assert orig.name == rt.name
        assert orig.mode == rt.mode
        assert orig.type.kind == rt.type.kind
      end)
    end
  end

  describe "type mapping" do
    test "bigquery_type_to_schema/1 maps simple types" do
      assert BQAdapter.bigquery_type_to_schema("STRING") == :string
      assert BQAdapter.bigquery_type_to_schema("INT64") == :integer
      assert BQAdapter.bigquery_type_to_schema("INTEGER") == :integer
      assert BQAdapter.bigquery_type_to_schema("FLOAT64") == :float
      assert BQAdapter.bigquery_type_to_schema("BOOL") == :boolean
      assert BQAdapter.bigquery_type_to_schema("BOOLEAN") == :boolean
      assert BQAdapter.bigquery_type_to_schema("NUMERIC") == :decimal
      assert BQAdapter.bigquery_type_to_schema("DATETIME") == :datetime
      assert BQAdapter.bigquery_type_to_schema("DATE") == :date
      assert BQAdapter.bigquery_type_to_schema("TIMESTAMP") == :timestamp
      assert BQAdapter.bigquery_type_to_schema("BYTES") == :binary
    end

    test "bigquery_type_to_schema/1 handles ARRAY types" do
      assert BQAdapter.bigquery_type_to_schema("ARRAY<STRING>") == {:list, :string}
      assert BQAdapter.bigquery_type_to_schema("ARRAY<INT64>") == {:list, :integer}
    end

    test "schema_to_bigquery_type/1 maps schema kinds" do
      assert BQAdapter.schema_to_bigquery_type(:string) == "STRING"
      assert BQAdapter.schema_to_bigquery_type(:integer) == "INT64"
      assert BQAdapter.schema_to_bigquery_type(:float) == "FLOAT64"
      assert BQAdapter.schema_to_bigquery_type(:boolean) == "BOOL"
      assert BQAdapter.schema_to_bigquery_type(:decimal) == "NUMERIC"
      assert BQAdapter.schema_to_bigquery_type(:datetime) == "DATETIME"
      assert BQAdapter.schema_to_bigquery_type(:date) == "DATE"
    end

    test "type_to_bq_sql/1 handles complex types" do
      # Simple type
      assert BQAdapter.type_to_bq_sql(%Type{kind: :string}) == "STRING"

      # Array type
      array_type = %Type{kind: :list, inner: %Type{kind: :integer}}
      assert BQAdapter.type_to_bq_sql(array_type) == "ARRAY<INT64>"

      # Struct type
      struct_type = %Type{
        kind: :struct,
        fields: [
          {:name, %Type{kind: :string}},
          {:age, %Type{kind: :integer}}
        ]
      }

      assert BQAdapter.type_to_bq_sql(struct_type) == "STRUCT<name STRING, age INT64>"
    end
  end
end
