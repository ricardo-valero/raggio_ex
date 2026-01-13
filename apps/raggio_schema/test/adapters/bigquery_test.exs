defmodule Raggio.Schema.Adapters.BigQueryTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema.Adapters.BigQuery
  alias Raggio.Schema, as: S

  describe "to_ddl/2" do
    test "generates DDL for simple struct schema" do
      schema =
        S.struct([
          {:id, S.integer()},
          {:email, S.optional(S.string())}
        ])

      ddl = BigQuery.to_ddl(schema, "users")

      assert ddl =~ "CREATE TABLE `users`"
      assert ddl =~ "id INT64 NOT NULL"
      assert ddl =~ "email STRING"
    end

    test "handles all primitive types" do
      schema =
        S.struct([
          {:str_field, S.string()},
          {:int_field, S.integer()},
          {:float_field, S.float()},
          {:bool_field, S.boolean()},
          {:date_field, S.date()},
          {:datetime_field, S.datetime()}
        ])

      ddl = BigQuery.to_ddl(schema, "types_table")

      assert ddl =~ "str_field STRING NOT NULL"
      assert ddl =~ "int_field INT64 NOT NULL"
      assert ddl =~ "float_field FLOAT64 NOT NULL"
      assert ddl =~ "bool_field BOOL NOT NULL"
      assert ddl =~ "date_field DATE NOT NULL"
      assert ddl =~ "datetime_field DATETIME NOT NULL"
    end

    test "handles list types" do
      schema =
        S.struct([
          {:tags, S.list(S.string())}
        ])

      ddl = BigQuery.to_ddl(schema, "with_arrays")

      assert ddl =~ "tags ARRAY<STRING> NOT NULL"
    end

    test "handles nested struct types" do
      address_schema =
        S.struct([
          {:street, S.optional(S.string())},
          {:city, S.string()}
        ])

      schema =
        S.struct([
          {:id, S.integer()},
          {:address, address_schema}
        ])

      ddl = BigQuery.to_ddl(schema, "with_nested")

      assert ddl =~ "address STRUCT<street STRING, city STRING NOT NULL> NOT NULL"
    end

    test "handles default values" do
      schema =
        S.struct([
          {:status, S.string(default: "active")},
          {:count, S.integer(default: 0)}
        ])

      ddl = BigQuery.to_ddl(schema, "with_defaults")

      assert ddl =~ "status STRING NOT NULL DEFAULT 'active'"
      assert ddl =~ "count INT64 NOT NULL DEFAULT 0"
    end
  end

  describe "to_ddl/3 with options" do
    test "adds PARTITION BY clause" do
      schema =
        S.struct([
          {:id, S.integer()},
          {:created_at, S.datetime()}
        ])

      ddl = BigQuery.to_ddl(schema, "partitioned_table", partition_by: "DATE(created_at)")

      assert ddl =~ "PARTITION BY DATE(created_at)"
    end

    test "adds CLUSTER BY clause" do
      schema =
        S.struct([
          {:id, S.integer()},
          {:status, S.string()}
        ])

      ddl = BigQuery.to_ddl(schema, "clustered_table", cluster_by: ["id", "status"])

      assert ddl =~ "CLUSTER BY id, status"
    end

    test "combines partition and cluster clauses" do
      schema =
        S.struct([
          {:id, S.integer()},
          {:created_at, S.datetime()}
        ])

      ddl =
        BigQuery.to_ddl(schema, "optimized_table",
          partition_by: "DATE(created_at)",
          cluster_by: ["id"]
        )

      assert ddl =~ "PARTITION BY DATE(created_at)"
      assert ddl =~ "CLUSTER BY id"
    end
  end

  describe "error handling" do
    test "raises for non-struct schemas" do
      schema = S.string()

      assert_raise ArgumentError, ~r/must be a struct type/, fn ->
        BigQuery.to_ddl(schema, "invalid")
      end
    end
  end
end
