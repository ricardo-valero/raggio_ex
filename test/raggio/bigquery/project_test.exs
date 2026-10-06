defmodule Raggio.BigQuery.ProjectTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{Project, Dataset, TableDef, Column}
  alias Raggio.Schema.Type

  @valid_table %TableDef{
    name: "events",
    columns: [
      %Column{name: :id, type: %Type{kind: :string}, mode: :required}
    ]
  }

  @valid_dataset %Dataset{
    name: "analytics",
    tables: [@valid_table]
  }

  describe "new/3" do
    test "creates project with defaults" do
      proj = Project.new("my-project")

      assert proj.project_id == "my-project"
      assert proj.datasets == []
      assert proj.metadata == %{}
    end

    test "creates project with datasets" do
      proj = Project.new("my-project", [@valid_dataset], metadata: %{env: "prod"})

      assert proj.project_id == "my-project"
      assert length(proj.datasets) == 1
      assert proj.metadata == %{env: "prod"}
    end
  end

  describe "validate/1" do
    test "returns {:ok, project} for valid project" do
      proj = %Project{project_id: "my-project", datasets: [@valid_dataset]}

      assert {:ok, ^proj} = Project.validate(proj)
    end

    test "returns error for nil project_id" do
      proj = %Project{project_id: nil, datasets: []}

      assert {:error, errors} = Project.validate(proj)
      assert Enum.any?(errors, &(&1.type == :invalid_project_id))
    end

    test "returns error for invalid project_id format - too short" do
      proj = %Project{project_id: "ab", datasets: []}

      assert {:error, errors} = Project.validate(proj)
      assert Enum.any?(errors, &(&1.type == :invalid_project_id))
    end

    test "returns error for invalid project_id format - starts with number" do
      proj = %Project{project_id: "123-project", datasets: []}

      assert {:error, errors} = Project.validate(proj)
      assert Enum.any?(errors, &(&1.type == :invalid_project_id))
    end

    test "returns error for invalid project_id format - uppercase" do
      proj = %Project{project_id: "My-Project", datasets: []}

      assert {:error, errors} = Project.validate(proj)
      assert Enum.any?(errors, &(&1.type == :invalid_project_id))
    end

    test "accepts valid project_id patterns" do
      valid_ids = [
        "my-project",
        "project123",
        "a-valid-project-id",
        "company-prod-data"
      ]

      for id <- valid_ids do
        proj = %Project{project_id: id, datasets: []}
        assert {:ok, _} = Project.validate(proj), "Expected #{inspect(id)} to be valid"
      end
    end

    test "returns error for duplicate dataset names" do
      datasets = [
        %Dataset{name: "analytics", tables: []},
        %Dataset{name: "analytics", tables: []}
      ]

      proj = %Project{project_id: "my-project", datasets: datasets}

      assert {:error, errors} = Project.validate(proj)
      assert Enum.any?(errors, &(&1.type == :duplicate_dataset))
    end

    test "validates nested datasets" do
      datasets = [
        %Dataset{name: nil, tables: []}
      ]

      proj = %Project{project_id: "my-project", datasets: datasets}

      assert {:error, errors} = Project.validate(proj)
      assert Enum.any?(errors, &(&1.type == :invalid_dataset_name))
      # Error should have path prefix
      ds_error = Enum.find(errors, &(&1.type == :invalid_dataset_name))
      assert [:datasets, 0 | _] = ds_error.path
    end
  end

  describe "add_dataset/2" do
    test "adds dataset to project" do
      proj = Project.new("my-project")
      proj = Project.add_dataset(proj, @valid_dataset)

      assert length(proj.datasets) == 1
      assert hd(proj.datasets).name == "analytics"
    end
  end

  describe "get_dataset/2" do
    test "returns dataset by name" do
      proj = %Project{project_id: "my-project", datasets: [@valid_dataset]}

      assert %Dataset{name: "analytics"} = Project.get_dataset(proj, "analytics")
    end

    test "returns nil for non-existent dataset" do
      proj = %Project{project_id: "my-project", datasets: [@valid_dataset]}

      assert Project.get_dataset(proj, "nonexistent") == nil
    end
  end

  describe "get_table/3" do
    test "returns table by dataset and table name" do
      proj = %Project{project_id: "my-project", datasets: [@valid_dataset]}

      assert %TableDef{name: "events"} = Project.get_table(proj, "analytics", "events")
    end

    test "returns nil for non-existent dataset" do
      proj = %Project{project_id: "my-project", datasets: [@valid_dataset]}

      assert Project.get_table(proj, "nonexistent", "events") == nil
    end

    test "returns nil for non-existent table" do
      proj = %Project{project_id: "my-project", datasets: [@valid_dataset]}

      assert Project.get_table(proj, "analytics", "nonexistent") == nil
    end
  end

  describe "all_tables/1" do
    test "returns all tables with dataset names" do
      table2 = %TableDef{
        name: "users",
        columns: [%Column{name: :id, type: %Type{kind: :string}}]
      }

      datasets = [
        %Dataset{name: "analytics", tables: [@valid_table]},
        %Dataset{name: "users", tables: [table2]}
      ]

      proj = %Project{project_id: "my-project", datasets: datasets}

      tables = Project.all_tables(proj)

      assert length(tables) == 2
      assert Enum.any?(tables, fn {ds, t} -> ds == "analytics" and t.name == "events" end)
      assert Enum.any?(tables, fn {ds, t} -> ds == "users" and t.name == "users" end)
    end

    test "returns empty list for project with no tables" do
      proj = %Project{project_id: "my-project", datasets: []}

      assert Project.all_tables(proj) == []
    end
  end
end
