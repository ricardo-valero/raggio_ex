defmodule Raggio.BigQuery.DDLGeneratorTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{TableDef, Dataset, Project, Column}
  alias Raggio.Schema.Type

  describe "TableDef.to_ddl/2" do
    test "generates valid CREATE TABLE DDL" do
      table = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :user_id, type: %Type{kind: :string}, mode: :nullable}
        ]
      }

      ddl = TableDef.to_ddl(table, "my_project.my_dataset")

      assert ddl =~ "CREATE TABLE"
      assert ddl =~ "`my_project.my_dataset.events`"
      assert ddl =~ "id STRING NOT NULL"
      assert ddl =~ "user_id STRING"
    end

    test "includes PARTITION BY clause when partition_by is set" do
      table = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :created_at, type: %Type{kind: :datetime}, mode: :required}
        ],
        partition_by: {:field, :created_at, :day}
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "PARTITION BY"
      assert ddl =~ "DATE(created_at)"
    end

    test "includes CLUSTER BY clause when cluster_by is set" do
      table = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :user_id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :event_type, type: %Type{kind: :string}, mode: :required}
        ],
        cluster_by: [:user_id, :event_type]
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "CLUSTER BY"
      assert ddl =~ "user_id, event_type"
    end

    test "nested STRUCT types render correctly in DDL" do
      struct_type = %Type{
        kind: :struct,
        fields: [
          {:name, %Type{kind: :string}},
          {:age, %Type{kind: :integer}}
        ]
      }

      table = %TableDef{
        name: "users",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{name: :profile, type: struct_type, mode: :nullable}
        ]
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "profile STRUCT<"
      assert ddl =~ "name STRING"
      assert ddl =~ "age INT64"
    end

    test "ARRAY types render correctly in DDL" do
      table = %TableDef{
        name: "users",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required},
          %Column{
            name: :tags,
            type: %Type{kind: :list, inner: %Type{kind: :string}},
            mode: :nullable
          }
        ]
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "tags ARRAY<STRING>"
    end

    test "repeated mode generates ARRAY type" do
      table = %TableDef{
        name: "users",
        columns: [
          %Column{name: :emails, type: %Type{kind: :string}, mode: :repeated}
        ]
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "emails ARRAY<STRING>"
    end

    test "includes description as OPTIONS" do
      table = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required}
        ],
        description: "Event tracking table"
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "OPTIONS"
      assert ddl =~ ~s(description = "Event tracking table")
    end

    test "handles all BigQuery types" do
      table = %TableDef{
        name: "all_types",
        columns: [
          %Column{name: :str, type: %Type{kind: :string}},
          %Column{name: :int, type: %Type{kind: :integer}},
          %Column{name: :flt, type: %Type{kind: :float}},
          %Column{name: :bool, type: %Type{kind: :boolean}},
          %Column{name: :dec, type: %Type{kind: :decimal}},
          %Column{name: :dt, type: %Type{kind: :datetime}},
          %Column{name: :d, type: %Type{kind: :date}},
          %Column{name: :ts, type: %Type{kind: :timestamp}},
          %Column{name: :bin, type: %Type{kind: :binary}}
        ]
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "str STRING"
      assert ddl =~ "int INT64"
      assert ddl =~ "flt FLOAT64"
      assert ddl =~ "bool BOOL"
      assert ddl =~ "dec NUMERIC"
      assert ddl =~ "dt DATETIME"
      assert ddl =~ "d DATE"
      assert ddl =~ "ts TIMESTAMP"
      assert ddl =~ "bin BYTES"
    end

    test "handles ingestion time partitioning" do
      table = %TableDef{
        name: "events",
        columns: [
          %Column{name: :id, type: %Type{kind: :string}, mode: :required}
        ],
        partition_by: {:ingestion_time, :day}
      }

      ddl = TableDef.to_ddl(table, "proj.ds")

      assert ddl =~ "PARTITION BY"
      assert ddl =~ "_PARTITIONDATE"
    end
  end

  describe "Dataset.to_ddl/2" do
    test "generates CREATE SCHEMA DDL" do
      dataset = %Dataset{
        name: "analytics",
        tables: [],
        location: "US"
      }

      ddl = Dataset.to_ddl(dataset, "my_project")

      assert ddl =~ "CREATE SCHEMA"
      assert ddl =~ "`my_project.analytics`"
    end

    test "includes OPTIONS for location" do
      dataset = %Dataset{
        name: "analytics",
        tables: [],
        location: "EU"
      }

      ddl = Dataset.to_ddl(dataset, "my_project")

      assert ddl =~ "OPTIONS"
      assert ddl =~ ~s(location = "EU")
    end
  end

  describe "Project.to_ddl/1" do
    test "generates DDL for all tables across datasets" do
      project = %Project{
        project_id: "my-project",
        datasets: [
          %Dataset{
            name: "raw",
            tables: [
              %TableDef{
                name: "events",
                columns: [%Column{name: :id, type: %Type{kind: :string}, mode: :required}]
              }
            ]
          },
          %Dataset{
            name: "staging",
            tables: [
              %TableDef{
                name: "users",
                columns: [%Column{name: :id, type: %Type{kind: :string}, mode: :required}]
              }
            ]
          }
        ]
      }

      ddl = Project.to_ddl(project)

      # Should contain CREATE SCHEMA for each dataset
      assert ddl =~ "CREATE SCHEMA"
      assert ddl =~ "`my-project.raw`"
      assert ddl =~ "`my-project.staging`"

      # Should contain CREATE TABLE for each table
      assert ddl =~ "CREATE TABLE"
      assert ddl =~ "`my-project.raw.events`"
      assert ddl =~ "`my-project.staging.users`"
    end

    test "respects include_schemas option" do
      project = %Project{
        project_id: "my-project",
        datasets: [
          %Dataset{
            name: "raw",
            tables: [
              %TableDef{
                name: "events",
                columns: [%Column{name: :id, type: %Type{kind: :string}}]
              }
            ]
          }
        ]
      }

      ddl = Project.to_ddl(project, include_schemas: false)

      refute ddl =~ "CREATE SCHEMA"
      assert ddl =~ "CREATE TABLE"
    end
  end

  describe "TableDef.to_bigquery_schema/1" do
    test "generates BigQuery REST API schema format" do
      table = %TableDef{
        name: "events",
        columns: [
          %Column{
            name: :id,
            type: %Type{kind: :string},
            mode: :required,
            description: "Event ID"
          },
          %Column{name: :count, type: %Type{kind: :integer}, mode: :nullable}
        ]
      }

      schema = TableDef.to_bigquery_schema(table)

      assert is_list(schema)
      assert length(schema) == 2

      id_field = Enum.find(schema, &(&1["name"] == "id"))
      assert id_field["type"] == "STRING"
      assert id_field["mode"] == "REQUIRED"
      assert id_field["description"] == "Event ID"

      count_field = Enum.find(schema, &(&1["name"] == "count"))
      assert count_field["type"] == "INT64"
      assert count_field["mode"] == "NULLABLE"
    end

    test "handles nested STRUCT fields" do
      struct_type = %Type{
        kind: :struct,
        fields: [
          {:city, %Type{kind: :string}},
          {:zip, %Type{kind: :string}}
        ]
      }

      table = %TableDef{
        name: "users",
        columns: [
          %Column{name: :address, type: struct_type, mode: :nullable}
        ]
      }

      schema = TableDef.to_bigquery_schema(table)

      address_field = hd(schema)
      assert address_field["type"] == "RECORD"
      assert address_field["mode"] == "NULLABLE"
      assert is_list(address_field["fields"])
      assert length(address_field["fields"]) == 2
    end

    test "handles REPEATED mode" do
      table = %TableDef{
        name: "users",
        columns: [
          %Column{name: :tags, type: %Type{kind: :string}, mode: :repeated}
        ]
      }

      schema = TableDef.to_bigquery_schema(table)

      tags_field = hd(schema)
      assert tags_field["type"] == "STRING"
      assert tags_field["mode"] == "REPEATED"
    end
  end
end
