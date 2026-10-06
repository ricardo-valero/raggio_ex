defmodule Raggio.BigQuery.Project do
  @moduledoc """
  Represents a BigQuery project containing datasets and tables.

  ## Fields

  - `project_id` - GCP project identifier
  - `datasets` - List of `Raggio.BigQuery.Dataset` definitions
  - `metadata` - Custom metadata map

  ## Validation Rules

  - `project_id` must match pattern `^[a-z][a-z0-9-]{4,28}[a-z0-9]$`
  - `datasets` names must be unique within project

  ## Examples

      %Project{
        project_id: "my-analytics-project",
        datasets: [
          %Dataset{name: "raw", tables: [...]},
          %Dataset{name: "staging", tables: [...]}
        ]
      }
  """

  alias Raggio.BigQuery.{Dataset, TableDef, Error}

  @type t :: %__MODULE__{
          project_id: String.t(),
          datasets: [Dataset.t()],
          metadata: map()
        }

  defstruct project_id: nil,
            datasets: [],
            metadata: %{}

  # GCP project ID pattern: starts with lowercase letter, 6-30 chars, lowercase letters/digits/hyphens
  @project_id_pattern ~r/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/

  @doc """
  Creates a new Project struct.

  ## Options

  - `:metadata` - Custom metadata map

  ## Examples

      iex> Project.new("my-project", datasets)
      %Project{project_id: "my-project", datasets: datasets}
  """
  @spec new(String.t(), [Dataset.t()], keyword()) :: t()
  def new(project_id, datasets \\ [], opts \\ []) do
    %__MODULE__{
      project_id: project_id,
      datasets: datasets,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validates a Project struct and returns errors if any.

  ## Returns

  - `{:ok, project}` if valid
  - `{:error, errors}` if invalid, where errors is a list of `Error` structs

  ## Examples

      iex> Project.validate(%Project{project_id: "my-project", datasets: []})
      {:ok, %Project{project_id: "my-project", datasets: []}}

      iex> Project.validate(%Project{project_id: "BAD", datasets: []})
      {:error, [%Error{type: :invalid_project_id, ...}]}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Error.t()]}
  def validate(%__MODULE__{} = project) do
    errors =
      []
      |> validate_project_id(project)
      |> validate_unique_datasets(project)
      |> validate_datasets(project)

    case errors do
      [] -> {:ok, project}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Adds a dataset to the project.
  """
  @spec add_dataset(t(), Dataset.t()) :: t()
  def add_dataset(%__MODULE__{} = project, %Dataset{} = dataset) do
    %{project | datasets: project.datasets ++ [dataset]}
  end

  @doc """
  Gets a dataset by name from the project.
  """
  @spec get_dataset(t(), String.t()) :: Dataset.t() | nil
  def get_dataset(%__MODULE__{datasets: datasets}, name) do
    Enum.find(datasets, fn ds -> ds.name == name end)
  end

  @doc """
  Gets a table by dataset and table name.

  ## Examples

      iex> Project.get_table(project, "analytics", "events")
      %TableDef{name: "events", ...}
  """
  @spec get_table(t(), String.t(), String.t()) :: TableDef.t() | nil
  def get_table(%__MODULE__{} = project, dataset_name, table_name) do
    case get_dataset(project, dataset_name) do
      nil -> nil
      dataset -> Dataset.get_table(dataset, table_name)
    end
  end

  @doc """
  Returns all tables across all datasets in the project.

  ## Returns

  A list of `{dataset_name, table}` tuples.

  ## Examples

      iex> Project.all_tables(project)
      [{"analytics", %TableDef{name: "events"}}, {"analytics", %TableDef{name: "users"}}]
  """
  @spec all_tables(t()) :: [{String.t(), TableDef.t()}]
  def all_tables(%__MODULE__{datasets: datasets}) do
    Enum.flat_map(datasets, fn dataset ->
      Enum.map(dataset.tables, fn table ->
        {dataset.name, table}
      end)
    end)
  end

  # ============================================================================
  # DDL Generation
  # ============================================================================

  @doc """
  Generate BigQuery DDL for all datasets and tables in the project.

  ## Options

  - `:include_schemas` - Include CREATE SCHEMA statements (default: true)
  - `:if_not_exists` - Add IF NOT EXISTS clauses (default: false)
  - `:separator` - Separator between statements (default: "\\n\\n")

  ## Examples

      iex> Project.to_ddl(project)
      "CREATE SCHEMA `my-project.raw` OPTIONS (location = \\"US\\");\\n\\nCREATE TABLE..."
  """
  @spec to_ddl(t(), keyword()) :: String.t()
  def to_ddl(%__MODULE__{} = project, opts \\ []) do
    include_schemas = Keyword.get(opts, :include_schemas, true)
    separator = Keyword.get(opts, :separator, "\n\n")

    statements = []

    # Generate CREATE SCHEMA statements
    statements =
      if include_schemas do
        schema_ddls =
          project.datasets
          |> Enum.map(fn dataset ->
            Dataset.to_ddl(dataset, project.project_id, opts) <> ";"
          end)

        statements ++ schema_ddls
      else
        statements
      end

    # Generate CREATE TABLE statements
    table_ddls =
      project.datasets
      |> Enum.flat_map(fn dataset ->
        qualified_prefix = "#{project.project_id}.#{dataset.name}"

        dataset.tables
        |> Enum.map(fn table ->
          TableDef.to_ddl(table, qualified_prefix, opts) <> ";"
        end)
      end)

    statements = statements ++ table_ddls

    Enum.join(statements, separator)
  end

  # Private validation helpers

  defp validate_project_id(errors, %{project_id: nil}) do
    [Error.new(:invalid_project_id, "Project ID is required", [:project_id]) | errors]
  end

  defp validate_project_id(errors, %{project_id: project_id}) do
    if Regex.match?(@project_id_pattern, project_id) do
      errors
    else
      [
        Error.new(
          :invalid_project_id,
          "Project ID must be 6-30 lowercase letters, digits, or hyphens, starting with a letter",
          [:project_id]
        )
        | errors
      ]
    end
  end

  defp validate_unique_datasets(errors, %{datasets: datasets}) do
    names = Enum.map(datasets, & &1.name)
    duplicates = names -- Enum.uniq(names)

    case duplicates do
      [] ->
        errors

      dups ->
        [
          Error.new(
            :duplicate_dataset,
            "Duplicate dataset names: #{inspect(Enum.uniq(dups))}",
            [:datasets]
          )
          | errors
        ]
    end
  end

  defp validate_datasets(errors, %{datasets: datasets}) do
    datasets
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {dataset, idx}, acc ->
      case Dataset.validate(dataset) do
        {:ok, _} -> acc
        {:error, ds_errors} -> prepend_path_errors(acc, ds_errors, [:datasets, idx])
      end
    end)
  end

  defp prepend_path_errors(errors, new_errors, prefix) do
    Enum.reduce(new_errors, errors, fn error, acc ->
      [%{error | path: prefix ++ error.path} | acc]
    end)
  end
end
