defmodule Raggio.BigQuery.ComposerTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{Composer, Project, Column}
  alias Raggio.Schema.Type

  import Composer, only: [required: 1, repeated: 1, description: 2]

  describe "project/1" do
    test "creates Context with project_id" do
      ctx = Composer.project("my-project")

      assert ctx.project_id == "my-project"
      assert ctx.current_dataset == nil
      assert ctx.datasets == %{}
      assert ctx.errors == []
    end

    test "accepts options" do
      ctx = Composer.project("my-project", metadata: %{env: "prod"})

      assert ctx.project_id == "my-project"
      assert ctx.metadata == %{env: "prod"}
    end
  end

  describe "dataset/2" do
    test "sets current dataset in Context" do
      ctx =
        Composer.project("my-project")
        |> Composer.dataset("analytics")

      assert ctx.current_dataset == "analytics"
    end

    test "flushes previous dataset when switching" do
      ctx =
        Composer.project("my-project")
        |> Composer.dataset("analytics")
        |> Composer.table("events", [
          Composer.column(:id, %Type{kind: :string})
        ])
        |> Composer.dataset("users")

      # Previous dataset should be saved
      assert Map.has_key?(ctx.datasets, "analytics")
      assert length(ctx.datasets["analytics"].tables) == 1

      # Current dataset should be new one
      assert ctx.current_dataset == "users"
    end

    test "accepts options" do
      ctx =
        Composer.project("my-project")
        |> Composer.dataset("analytics", location: "US")

      assert ctx.current_dataset == "analytics"
      assert ctx.dataset_opts[:location] == "US"
    end
  end

  describe "table/3" do
    test "adds TableDef to current dataset" do
      ctx =
        Composer.project("my-project")
        |> Composer.dataset("analytics")
        |> Composer.table("events", [
          Composer.column(:id, %Type{kind: :string}, mode: :required)
        ])

      # Table should be in pending tables for current dataset
      assert length(ctx.pending_tables) == 1
      assert hd(ctx.pending_tables).name == "events"
    end

    test "accepts options" do
      ctx =
        Composer.project("my-project")
        |> Composer.dataset("analytics")
        |> Composer.table(
          "events",
          [
            Composer.column(:id, %Type{kind: :string}),
            Composer.column(:created_at, %Type{kind: :datetime})
          ],
          partition_by: {:field, :created_at, :day},
          cluster_by: [:id]
        )

      table = hd(ctx.pending_tables)
      assert table.partition_by == {:field, :created_at, :day}
      assert table.cluster_by == [:id]
    end
  end

  describe "column/3" do
    test "creates Column with correct defaults" do
      col = Composer.column(:id, %Type{kind: :string})

      assert %Column{} = col
      assert col.name == :id
      assert col.type.kind == :string
      assert col.mode == :nullable
    end

    test "accepts options" do
      col =
        Composer.column(:id, %Type{kind: :string},
          mode: :required,
          description: "Unique identifier"
        )

      assert col.mode == :required
      assert col.description == "Unique identifier"
    end
  end

  describe "build/1" do
    test "returns valid Project struct" do
      result =
        Composer.project("my-project")
        |> Composer.dataset("analytics")
        |> Composer.table("events", [
          Composer.column(:id, %Type{kind: :string}, mode: :required)
        ])
        |> Composer.build()

      assert {:ok, %Project{} = proj} = result
      assert proj.project_id == "my-project"
      assert length(proj.datasets) == 1

      ds = hd(proj.datasets)
      assert ds.name == "analytics"
      assert length(ds.tables) == 1

      table = hd(ds.tables)
      assert table.name == "events"
      assert length(table.columns) == 1
    end

    test "returns {:error, errors} for invalid project" do
      # Invalid project ID (uppercase)
      result =
        Composer.project("BAD")
        |> Composer.build()

      assert {:error, errors} = result
      assert length(errors) > 0
    end
  end

  describe "build!/1" do
    test "returns Project struct on success" do
      proj =
        Composer.project("my-project")
        |> Composer.dataset("analytics")
        |> Composer.table("events", [
          Composer.column(:id, %Type{kind: :string})
        ])
        |> Composer.build!()

      assert %Project{} = proj
      assert proj.project_id == "my-project"
    end

    test "raises on error" do
      assert_raise RuntimeError, fn ->
        Composer.project("BAD")
        |> Composer.build!()
      end
    end
  end

  describe "integration: full pipeline" do
    test "project -> datasets -> tables -> build" do
      result =
        Composer.project("my-analytics-project")
        |> Composer.dataset("raw", location: "US")
        |> Composer.table(
          "events",
          [
            Composer.column(:id, %Type{kind: :string}, mode: :required),
            Composer.column(:event_type, %Type{kind: :string}, mode: :required),
            Composer.column(:payload, %Type{kind: :string}),
            Composer.column(:created_at, %Type{kind: :datetime}, mode: :required)
          ],
          partition_by: {:field, :created_at, :day},
          cluster_by: [:event_type]
        )
        |> Composer.table("users", [
          Composer.column(:id, %Type{kind: :string}, mode: :required),
          Composer.column(:email, %Type{kind: :string}, mode: :required)
        ])
        |> Composer.dataset("staging")
        |> Composer.table("processed_events", [
          Composer.column(:id, %Type{kind: :string}, mode: :required)
        ])
        |> Composer.build()

      assert {:ok, proj} = result
      assert proj.project_id == "my-analytics-project"
      assert length(proj.datasets) == 2

      # Check raw dataset
      raw = Enum.find(proj.datasets, &(&1.name == "raw"))
      assert raw.location == "US"
      assert length(raw.tables) == 2

      # Check events table
      events = Enum.find(raw.tables, &(&1.name == "events"))
      assert events.partition_by == {:field, :created_at, :day}
      assert events.cluster_by == [:event_type]
      assert length(events.columns) == 4

      # Check staging dataset
      staging = Enum.find(proj.datasets, &(&1.name == "staging"))
      assert length(staging.tables) == 1
    end

    test "project with multiple datasets and tables preserves hierarchy" do
      proj =
        Composer.project("test-project")
        |> Composer.dataset("ds1")
        |> Composer.table("t1", [Composer.column(:a, %Type{kind: :string})])
        |> Composer.table("t2", [Composer.column(:b, %Type{kind: :string})])
        |> Composer.dataset("ds2")
        |> Composer.table("t3", [Composer.column(:c, %Type{kind: :string})])
        |> Composer.build!()

      assert length(proj.datasets) == 2

      ds1 = Project.get_dataset(proj, "ds1")
      assert length(ds1.tables) == 2

      ds2 = Project.get_dataset(proj, "ds2")
      assert length(ds2.tables) == 1

      assert Project.get_table(proj, "ds1", "t1") != nil
      assert Project.get_table(proj, "ds1", "t2") != nil
      assert Project.get_table(proj, "ds2", "t3") != nil
    end
  end

  # ==========================================================================
  # User Story 4: Effect-TS/Schema Style Composition
  # ==========================================================================

  describe "required/1" do
    test "sets mode: :required in type metadata" do
      type = %Type{kind: :string} |> required()

      assert type.metadata[:mode] == :required
    end

    test "preserves other metadata" do
      type = %Type{kind: :string, metadata: %{custom: "value"}} |> required()

      assert type.metadata[:mode] == :required
      assert type.metadata[:custom] == "value"
    end
  end

  describe "repeated/1" do
    test "sets mode: :repeated in type metadata" do
      type = %Type{kind: :string} |> repeated()

      assert type.metadata[:mode] == :repeated
    end
  end

  describe "description/2" do
    test "sets description in type metadata" do
      type = %Type{kind: :string} |> description("User email address")

      assert type.metadata[:description] == "User email address"
    end
  end

  describe "pipe composition" do
    test "Schema.string() |> required() |> description()" do
      type =
        %Type{kind: :string}
        |> required()
        |> description("Test field")

      assert type.kind == :string
      assert type.metadata[:mode] == :required
      assert type.metadata[:description] == "Test field"
    end

    test "column/3 extracts mode from type metadata" do
      type = %Type{kind: :string} |> required()
      col = Composer.column(:id, type)

      assert col.mode == :required
    end

    test "column/3 extracts description from type metadata" do
      type = %Type{kind: :string} |> description("User ID")
      col = Composer.column(:id, type)

      assert col.description == "User ID"
    end

    test "column/3 prefers explicit options over metadata" do
      type = %Type{kind: :string} |> required() |> description("From metadata")
      col = Composer.column(:id, type, mode: :nullable, description: "From option")

      assert col.mode == :nullable
      assert col.description == "From option"
    end

    test "full pipeline with pipe composition" do
      proj =
        Composer.project("my-project")
        |> Composer.dataset("analytics")
        |> Composer.table("events", [
          Composer.column(:id, %Type{kind: :string} |> required()),
          Composer.column(:tags, %Type{kind: :string} |> repeated()),
          Composer.column(:email, %Type{kind: :string} |> description("User email"))
        ])
        |> Composer.build!()

      table = Project.get_table(proj, "analytics", "events")
      columns = table.columns

      id_col = Enum.find(columns, &(&1.name == :id))
      assert id_col.mode == :required

      tags_col = Enum.find(columns, &(&1.name == :tags))
      assert tags_col.mode == :repeated

      email_col = Enum.find(columns, &(&1.name == :email))
      assert email_col.description == "User email"
    end
  end

  # ==========================================================================
  # Phase 8: Integration & Backward Compatibility
  # ==========================================================================

  describe "from_modules/2" do
    defmodule TestTableModule do
      @moduledoc false
      use Raggio.BigQuery.Table

      @impl true
      def __dataset__, do: "test_dataset"

      @impl true
      def __table__, do: "test_events"

      @impl true
      def __schema__ do
        %Raggio.Schema.Type{
          kind: :struct,
          fields: [
            {:id, %Raggio.Schema.Type{kind: :string}},
            {:name, %Raggio.Schema.Type{kind: :string, optional: true}},
            {:count, %Raggio.Schema.Type{kind: :integer}},
            {:created_at, %Raggio.Schema.Type{kind: :datetime}}
          ]
        }
      end

      @impl true
      def __time_partitioning__, do: [field: :created_at, type: :day]

      @impl true
      def __clustering__, do: [:id]
    end

    defmodule TestTableModule2 do
      @moduledoc false
      use Raggio.BigQuery.Table

      @impl true
      def __dataset__, do: "test_dataset"

      @impl true
      def __table__, do: "test_users"

      @impl true
      def __schema__ do
        %Raggio.Schema.Type{
          kind: :struct,
          fields: [
            {:user_id, %Raggio.Schema.Type{kind: :string}},
            {:email, %Raggio.Schema.Type{kind: :string}}
          ]
        }
      end
    end

    defmodule TestTableModuleOtherDataset do
      @moduledoc false
      use Raggio.BigQuery.Table

      @impl true
      def __dataset__, do: "other_dataset"

      @impl true
      def __table__, do: "logs"

      @impl true
      def __schema__ do
        %Raggio.Schema.Type{
          kind: :struct,
          fields: [
            {:message, %Raggio.Schema.Type{kind: :string}}
          ]
        }
      end
    end

    test "converts single Table behaviour module to Project" do
      {:ok, proj} = Composer.from_modules([TestTableModule], "my-project")

      assert %Project{} = proj
      assert proj.project_id == "my-project"
      assert length(proj.datasets) == 1

      ds = hd(proj.datasets)
      assert ds.name == "test_dataset"
      assert length(ds.tables) == 1

      table = hd(ds.tables)
      assert table.name == "test_events"
      assert length(table.columns) == 4
    end

    test "groups multiple modules from same dataset" do
      {:ok, proj} = Composer.from_modules([TestTableModule, TestTableModule2], "my-project")

      assert length(proj.datasets) == 1

      ds = hd(proj.datasets)
      assert ds.name == "test_dataset"
      assert length(ds.tables) == 2

      table_names = Enum.map(ds.tables, & &1.name)
      assert "test_events" in table_names
      assert "test_users" in table_names
    end

    test "creates separate datasets for different dataset names" do
      {:ok, proj} =
        Composer.from_modules(
          [TestTableModule, TestTableModuleOtherDataset],
          "my-project"
        )

      assert length(proj.datasets) == 2

      dataset_names = Enum.map(proj.datasets, & &1.name)
      assert "test_dataset" in dataset_names
      assert "other_dataset" in dataset_names
    end

    test "preserves time partitioning from module" do
      {:ok, proj} = Composer.from_modules([TestTableModule], "my-project")

      table = Project.get_table(proj, "test_dataset", "test_events")
      assert table.partition_by == {:field, :created_at, :day}
    end

    test "preserves clustering from module" do
      {:ok, proj} = Composer.from_modules([TestTableModule], "my-project")

      table = Project.get_table(proj, "test_dataset", "test_events")
      assert table.cluster_by == [:id]
    end

    test "returns error for empty modules list" do
      {:error, errors} = Composer.from_modules([], "my-project")

      assert length(errors) > 0
    end
  end

  describe "backward compatibility with use Raggio.BigQuery.Table" do
    test "existing Table modules still work with __qualified_name__" do
      module = __MODULE__.TestTableModule
      assert module.__qualified_name__() == "test_dataset.test_events"
    end

    test "existing Table modules still work with to_create_table_ddl" do
      module = __MODULE__.TestTableModule
      ddl = module.to_create_table_ddl()

      assert is_binary(ddl)
      assert ddl =~ "CREATE TABLE"
      assert ddl =~ "test_events"
    end

    test "existing Table modules still work with to_bigquery_schema" do
      module = __MODULE__.TestTableModule
      schema = module.to_bigquery_schema()

      assert is_map(schema)
      assert Map.has_key?(schema, "fields")
      assert is_list(schema["fields"])
    end
  end
end
