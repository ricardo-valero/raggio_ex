# API Contract: Raggio.BigQuery.Composer
# This file defines the expected public API - not implementation

defmodule Raggio.BigQuery.Composer do
  @moduledoc """
  Fluent builder API for composing BigQuery project schemas.

  Provides a Drizzle-inspired, pipeable API for defining
  BigQuery schemas hierarchically.

  ## Examples

      import Raggio.BigQuery.Composer
      alias Raggio.Schema

      project = 
        project("my-gcp-project")
        |> dataset("analytics")
        |> table("events",
             columns: [
               column(:id, Schema.string() |> required()),
               column(:user_id, Schema.string()),
               column(:payload, Schema.struct([
                 {:action, Schema.string()},
                 {:metadata, Schema.record(Schema.string(), Schema.string())}
               ])),
               column(:created_at, Schema.datetime())
             ],
             partition_by: {:field, :created_at, :day},
             cluster_by: [:user_id]
           )
        |> table("users",
             columns: [
               column(:id, Schema.string() |> required()),
               column(:email, Schema.string()),
               column(:created_at, Schema.datetime())
             ]
           )
        |> dataset("billing")
        |> table("invoices", columns: [...])
        |> build()
  """

  @opaque context :: %__MODULE__.Context{}

  @doc """
  Starts a new project definition.

  ## Examples

      project("my-gcp-project")
      project("my-gcp-project", metadata: %{env: "prod"})
  """
  @spec project(String.t(), keyword()) :: context()
  def project(project_id, opts \\ [])

  @doc """
  Adds a dataset to the current project.

  If there's a current dataset being built, it is finalized first.

  ## Examples

      project("my-project")
      |> dataset("analytics")
      |> dataset("billing", location: "EU")
  """
  @spec dataset(context(), String.t(), keyword()) :: context()
  def dataset(ctx, name, opts \\ [])

  @doc """
  Adds a table to the current dataset.

  ## Options
    - `:columns` - List of column definitions (required)
    - `:partition_by` - Partition configuration
    - `:cluster_by` - List of clustering columns
    - `:description` - Table description

  ## Examples

      dataset("analytics")
      |> table("events",
           columns: [
             column(:id, Schema.string()),
             column(:created_at, Schema.datetime())
           ],
           partition_by: {:field, :created_at, :day}
         )
  """
  @spec table(context(), String.t(), keyword()) :: context()
  def table(ctx, name, opts)

  @doc """
  Finalizes the builder and returns a Project struct.

  Validates the entire project and returns errors if invalid.

  ## Returns
    - `{:ok, %Project{}}` on success
    - `{:error, [Error.t()]}` if validation fails
  """
  @spec build(context()) ::
          {:ok, Raggio.BigQuery.Project.t()} | {:error, [Raggio.BigQuery.Error.t()]}
  def build(ctx)

  @doc """
  Finalizes and returns Project, raising on validation errors.
  """
  @spec build!(context()) :: Raggio.BigQuery.Project.t()
  def build!(ctx)

  @doc """
  Creates a column definition for use in table/3.

  ## Examples

      column(:id, Schema.string())
      column(:id, Schema.string(), mode: :required, description: "Unique ID")
  """
  @spec column(atom(), Raggio.Schema.Type.t(), keyword()) ::
          Raggio.BigQuery.Column.t()
  def column(name, type, opts \\ [])

  @doc """
  Marks a schema type as required (NOT NULL in BigQuery).

  ## Examples

      Schema.string() |> required()
  """
  @spec required(Raggio.Schema.Type.t()) :: Raggio.Schema.Type.t()
  def required(type)

  @doc """
  Marks a schema type as repeated (ARRAY mode in BigQuery).

  ## Examples

      Schema.string() |> repeated()
  """
  @spec repeated(Raggio.Schema.Type.t()) :: Raggio.Schema.Type.t()
  def repeated(type)

  @doc """
  Adds a description to a schema type.

  ## Examples

      Schema.string() |> description("User email address")
  """
  @spec description(Raggio.Schema.Type.t(), String.t()) :: Raggio.Schema.Type.t()
  def description(type, desc)

  @doc """
  Creates a Project from existing Table modules.

  Converts modules using `use Raggio.BigQuery.Table` behaviour
  into the composable Project structure.

  ## Examples

      Composer.from_modules([
        MyApp.Tables.Events,
        MyApp.Tables.Users
      ], project_id: "my-project")
  """
  @spec from_modules([module()], keyword()) ::
          {:ok, Raggio.BigQuery.Project.t()} | {:error, [Raggio.BigQuery.Error.t()]}
  def from_modules(modules, opts)
end

defmodule Raggio.BigQuery.Composer.Context do
  @moduledoc false
  # Internal builder state - not part of public API

  @type t :: %__MODULE__{
          project_id: String.t(),
          current_dataset: String.t() | nil,
          datasets: %{String.t() => [Raggio.BigQuery.TableDef.t()]},
          dataset_opts: %{String.t() => keyword()},
          errors: [Raggio.BigQuery.Error.t()],
          metadata: map()
        }

  defstruct [
    :project_id,
    :current_dataset,
    datasets: %{},
    dataset_opts: %{},
    errors: [],
    metadata: %{}
  ]
end
