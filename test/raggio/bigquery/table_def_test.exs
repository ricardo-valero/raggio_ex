defmodule Raggio.BigQuery.TableDefTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{TableDef, Column}
  alias Raggio.Schema.Type

  @valid_columns [
    %Column{name: :id, type: %Type{kind: :string}, mode: :required},
    %Column{name: :created_at, type: %Type{kind: :datetime}, mode: :required},
    %Column{name: :user_id, type: %Type{kind: :string}, mode: :nullable}
  ]

  describe "new/3" do
    test "creates table with defaults" do
      table = TableDef.new("events", @valid_columns)

      assert table.name == "events"
      assert length(table.columns) == 3
      assert table.partition_by == nil
      assert table.cluster_by == nil
    end

    test "creates table with options" do
      table =
        TableDef.new("events", @valid_columns,
          partition_by: {:field, :created_at, :day},
          cluster_by: [:user_id],
          description: "Event log"
        )

      assert table.partition_by == {:field, :created_at, :day}
      assert table.cluster_by == [:user_id]
      assert table.description == "Event log"
    end
  end

  describe "validate/1" do
    test "returns {:ok, table} for valid table" do
      table = %TableDef{name: "events", columns: @valid_columns}

      assert {:ok, ^table} = TableDef.validate(table)
    end

    test "returns error for nil name" do
      table = %TableDef{name: nil, columns: @valid_columns}

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_table_name))
    end

    test "returns error for invalid name format" do
      table = %TableDef{name: "123invalid", columns: @valid_columns}

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_table_name))
    end

    test "accepts valid name patterns" do
      valid_names = ["events", "_private", "CamelCase", "snake_case", "UPPER_CASE"]

      for name <- valid_names do
        table = %TableDef{name: name, columns: @valid_columns}
        assert {:ok, _} = TableDef.validate(table), "Expected #{inspect(name)} to be valid"
      end
    end

    test "returns error for duplicate column names" do
      columns = [
        %Column{name: :id, type: %Type{kind: :string}},
        %Column{name: :id, type: %Type{kind: :integer}}
      ]

      table = %TableDef{name: "test", columns: columns}

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :duplicate_column))
    end

    test "validates nested columns" do
      columns = [
        %Column{name: nil, type: %Type{kind: :string}}
      ]

      table = %TableDef{name: "test", columns: columns}

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_column_name))
      # Error should have path prefix
      col_error = Enum.find(errors, &(&1.type == :invalid_column_name))
      assert [:columns, 0 | _] = col_error.path
    end
  end

  describe "validate/1 partition_by" do
    test "accepts valid field partitioning" do
      table = %TableDef{
        name: "events",
        columns: @valid_columns,
        partition_by: {:field, :created_at, :day}
      }

      assert {:ok, _} = TableDef.validate(table)
    end

    test "accepts valid ingestion time partitioning" do
      table = %TableDef{
        name: "events",
        columns: @valid_columns,
        partition_by: {:ingestion_time, :hour}
      }

      assert {:ok, _} = TableDef.validate(table)
    end

    test "returns error for non-existent partition column" do
      table = %TableDef{
        name: "events",
        columns: @valid_columns,
        partition_by: {:field, :nonexistent, :day}
      }

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_partition_field))
    end

    test "returns error for invalid granularity" do
      table = %TableDef{
        name: "events",
        columns: @valid_columns,
        partition_by: {:field, :created_at, :invalid}
      }

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_partition_field))
    end

    test "accepts all valid granularities" do
      for granularity <- [:hour, :day, :month, :year] do
        table = %TableDef{
          name: "events",
          columns: @valid_columns,
          partition_by: {:field, :created_at, granularity}
        }

        assert {:ok, _} = TableDef.validate(table), "Expected #{granularity} to be valid"
      end
    end
  end

  describe "validate/1 cluster_by" do
    test "accepts valid clustering columns" do
      table = %TableDef{
        name: "events",
        columns: @valid_columns,
        cluster_by: [:user_id]
      }

      assert {:ok, _} = TableDef.validate(table)
    end

    test "accepts up to 4 clustering columns" do
      columns = [
        %Column{name: :a, type: %Type{kind: :string}},
        %Column{name: :b, type: %Type{kind: :string}},
        %Column{name: :c, type: %Type{kind: :string}},
        %Column{name: :d, type: %Type{kind: :string}}
      ]

      table = %TableDef{
        name: "events",
        columns: columns,
        cluster_by: [:a, :b, :c, :d]
      }

      assert {:ok, _} = TableDef.validate(table)
    end

    test "returns error for more than 4 clustering columns" do
      columns = [
        %Column{name: :a, type: %Type{kind: :string}},
        %Column{name: :b, type: %Type{kind: :string}},
        %Column{name: :c, type: %Type{kind: :string}},
        %Column{name: :d, type: %Type{kind: :string}},
        %Column{name: :e, type: %Type{kind: :string}}
      ]

      table = %TableDef{
        name: "events",
        columns: columns,
        cluster_by: [:a, :b, :c, :d, :e]
      }

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_clustering))
    end

    test "returns error for non-existent clustering column" do
      table = %TableDef{
        name: "events",
        columns: @valid_columns,
        cluster_by: [:nonexistent]
      }

      assert {:error, errors} = TableDef.validate(table)
      assert Enum.any?(errors, &(&1.type == :invalid_clustering))
    end
  end

  describe "get_column/2" do
    test "returns column by name" do
      table = %TableDef{name: "events", columns: @valid_columns}

      assert %Column{name: :id} = TableDef.get_column(table, :id)
    end

    test "returns nil for non-existent column" do
      table = %TableDef{name: "events", columns: @valid_columns}

      assert TableDef.get_column(table, :nonexistent) == nil
    end
  end

  describe "column_names/1" do
    test "returns all column names" do
      table = %TableDef{name: "events", columns: @valid_columns}

      names = TableDef.column_names(table)

      assert :id in names
      assert :created_at in names
      assert :user_id in names
    end
  end
end
