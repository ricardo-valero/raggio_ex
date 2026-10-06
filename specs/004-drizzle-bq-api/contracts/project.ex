# API Contract: Raggio.BigQuery.Project
# This file defines the expected public API - not implementation

defmodule Raggio.BigQuery.Project do
  @moduledoc """
  BigQuery project container for hierarchical schema composition.

  A Project represents a GCP project and contains multiple datasets,
  each containing multiple tables.

  ## Examples

      # Using composer functions
      project = 
        Raggio.BigQuery.Composer.project("my-project")
        |> Raggio.BigQuery.Composer.dataset("analytics")
        |> Raggio.BigQuery.Composer.table("events", schema: [...])
        |> Raggio.BigQuery.Composer.build()

      # Direct struct construction
      project = %Raggio.BigQuery.Project{
        project_id: "my-project",
        datasets: [%Raggio.BigQuery.Dataset{...}]
      }
  """

  @type t :: %__MODULE__{
          project_id: String.t(),
          datasets: [Raggio.BigQuery.Dataset.t()],
          metadata: map()
        }

  @enforce_keys [:project_id]
  defstruct [
    :project_id,
    datasets: [],
    metadata: %{}
  ]

  @doc """
  Validates a project struct and returns errors if invalid.

  ## Returns
    - `{:ok, project}` if valid
    - `{:error, [error]}` if validation fails
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Raggio.BigQuery.Error.t()]}
  def validate(%__MODULE__{} = project)

  @doc """
  Returns all tables across all datasets as a flat list.
  """
  @spec all_tables(t()) :: [Raggio.BigQuery.TableDef.t()]
  def all_tables(%__MODULE__{} = project)

  @doc """
  Looks up a table by qualified name.

  ## Examples

      get_table(project, "analytics", "events")
      # => {:ok, %TableDef{...}}

      get_table(project, "missing", "table")
      # => {:error, :not_found}
  """
  @spec get_table(t(), String.t(), String.t()) ::
          {:ok, Raggio.BigQuery.TableDef.t()} | {:error, :not_found}
  def get_table(%__MODULE__{} = project, dataset_name, table_name)

  @doc """
  Generates DDL statements for the entire project.

  ## Options
    - `:if_not_exists` - Add IF NOT EXISTS clause (default: false)
    - `:include_datasets` - Generate CREATE SCHEMA statements (default: false)

  ## Returns
    List of DDL statement strings
  """
  @spec to_ddl(t(), keyword()) :: [String.t()]
  def to_ddl(%__MODULE__{} = project, opts \\ [])
end
