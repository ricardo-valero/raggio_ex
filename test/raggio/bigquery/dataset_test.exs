defmodule Raggio.BigQuery.DatasetTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{Dataset, TableDef, Column}
  alias Raggio.Schema.Type

  @valid_table %TableDef{
    name: "events",
    columns: [
      %Column{name: :id, type: %Type{kind: :string}, mode: :required}
    ]
  }

  describe "new/3" do
    test "creates dataset with defaults" do
      ds = Dataset.new("analytics")

      assert ds.name == "analytics"
      assert ds.tables == []
      assert ds.location == nil
    end

    test "creates dataset with options" do
      ds =
        Dataset.new("analytics", [@valid_table],
          location: "US",
          metadata: %{env: "prod"}
        )

      assert ds.name == "analytics"
      assert length(ds.tables) == 1
      assert ds.location == "US"
      assert ds.metadata == %{env: "prod"}
    end
  end

  describe "validate/1" do
    test "returns {:ok, dataset} for valid dataset" do
      ds = %Dataset{name: "analytics", tables: [@valid_table]}

      assert {:ok, ^ds} = Dataset.validate(ds)
    end

    test "returns error for nil name" do
      ds = %Dataset{name: nil, tables: []}

      assert {:error, errors} = Dataset.validate(ds)
      assert Enum.any?(errors, &(&1.type == :invalid_dataset_name))
    end

    test "returns error for invalid name format" do
      ds = %Dataset{name: "123invalid", tables: []}

      assert {:error, errors} = Dataset.validate(ds)
      assert Enum.any?(errors, &(&1.type == :invalid_dataset_name))
    end

    test "accepts valid name patterns" do
      valid_names = ["analytics", "_private", "CamelCase", "snake_case", "UPPER"]

      for name <- valid_names do
        ds = %Dataset{name: name, tables: []}
        assert {:ok, _} = Dataset.validate(ds), "Expected #{inspect(name)} to be valid"
      end
    end

    test "returns error for invalid location" do
      ds = %Dataset{name: "analytics", tables: [], location: "INVALID"}

      assert {:error, errors} = Dataset.validate(ds)
      assert Enum.any?(errors, &(&1.type == :invalid_location))
    end

    test "accepts valid locations" do
      valid_locations = ["US", "EU", "us-central1", "europe-west1", "asia-east1"]

      for location <- valid_locations do
        ds = %Dataset{name: "analytics", tables: [], location: location}
        assert {:ok, _} = Dataset.validate(ds), "Expected #{location} to be valid"
      end
    end

    test "returns error for duplicate table names" do
      tables = [
        %TableDef{name: "events", columns: [%Column{name: :id, type: %Type{kind: :string}}]},
        %TableDef{name: "events", columns: [%Column{name: :id, type: %Type{kind: :integer}}]}
      ]

      ds = %Dataset{name: "analytics", tables: tables}

      assert {:error, errors} = Dataset.validate(ds)
      assert Enum.any?(errors, &(&1.type == :duplicate_table))
    end

    test "validates nested tables" do
      tables = [
        %TableDef{name: nil, columns: [%Column{name: :id, type: %Type{kind: :string}}]}
      ]

      ds = %Dataset{name: "analytics", tables: tables}

      assert {:error, errors} = Dataset.validate(ds)
      assert Enum.any?(errors, &(&1.type == :invalid_table_name))
      # Error should have path prefix
      table_error = Enum.find(errors, &(&1.type == :invalid_table_name))
      assert [:tables, 0 | _] = table_error.path
    end
  end

  describe "add_table/2" do
    test "adds table to dataset" do
      ds = Dataset.new("analytics")
      ds = Dataset.add_table(ds, @valid_table)

      assert length(ds.tables) == 1
      assert hd(ds.tables).name == "events"
    end
  end

  describe "get_table/2" do
    test "returns table by name" do
      ds = %Dataset{name: "analytics", tables: [@valid_table]}

      assert %TableDef{name: "events"} = Dataset.get_table(ds, "events")
    end

    test "returns nil for non-existent table" do
      ds = %Dataset{name: "analytics", tables: [@valid_table]}

      assert Dataset.get_table(ds, "nonexistent") == nil
    end
  end
end
