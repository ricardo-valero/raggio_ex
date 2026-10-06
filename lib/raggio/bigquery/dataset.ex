defmodule Raggio.BigQuery.Dataset do
  @moduledoc """
  Represents a BigQuery dataset containing related tables.

  ## Fields

  - `name` - Dataset identifier
  - `tables` - List of `Raggio.BigQuery.TableDef` definitions
  - `location` - Geographic location (e.g., "US", "EU")
  - `default_partition_expiration_ms` - Auto-delete partitions after N ms
  - `metadata` - Custom metadata map

  ## Validation Rules

  - `name` must match `^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$`
  - `tables` names must be unique within dataset
  - `location` if provided must be valid BigQuery region

  ## Examples

      %Dataset{
        name: "analytics",
        tables: [
          %TableDef{name: "events", columns: [...]},
          %TableDef{name: "users", columns: [...]}
        ],
        location: "US"
      }
  """

  alias Raggio.BigQuery.{TableDef, Error}

  @type t :: %__MODULE__{
          name: String.t(),
          tables: [TableDef.t()],
          location: String.t() | nil,
          default_partition_expiration_ms: integer() | nil,
          metadata: map()
        }

  defstruct name: nil,
            tables: [],
            location: nil,
            default_partition_expiration_ms: nil,
            metadata: %{}

  # Valid BigQuery regions
  @valid_locations ~w(
    US EU
    us-central1 us-east1 us-east4 us-west1 us-west2 us-west3 us-west4
    northamerica-northeast1 northamerica-northeast2
    southamerica-east1 southamerica-west1
    europe-central2 europe-north1 europe-west1 europe-west2 europe-west3 europe-west4 europe-west6
    asia-east1 asia-east2 asia-northeast1 asia-northeast2 asia-northeast3 asia-south1 asia-south2 asia-southeast1 asia-southeast2
    australia-southeast1 australia-southeast2
  )

  @name_pattern ~r/^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$/

  @doc """
  Creates a new Dataset struct.

  ## Options

  - `:location` - Geographic location (e.g., "US", "EU")
  - `:default_partition_expiration_ms` - Auto-delete partitions after N ms
  - `:metadata` - Custom metadata map

  ## Examples

      iex> Dataset.new("analytics", tables, location: "US")
      %Dataset{name: "analytics", tables: tables, location: "US"}
  """
  @spec new(String.t(), [TableDef.t()], keyword()) :: t()
  def new(name, tables \\ [], opts \\ []) do
    %__MODULE__{
      name: name,
      tables: tables,
      location: Keyword.get(opts, :location),
      default_partition_expiration_ms: Keyword.get(opts, :default_partition_expiration_ms),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validates a Dataset struct and returns errors if any.

  ## Returns

  - `{:ok, dataset}` if valid
  - `{:error, errors}` if invalid, where errors is a list of `Error` structs

  ## Examples

      iex> Dataset.validate(%Dataset{name: "valid_name", tables: []})
      {:ok, %Dataset{name: "valid_name", tables: []}}

      iex> Dataset.validate(%Dataset{name: "123invalid", tables: []})
      {:error, [%Error{type: :invalid_dataset_name, ...}]}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [Error.t()]}
  def validate(%__MODULE__{} = dataset) do
    errors =
      []
      |> validate_name(dataset)
      |> validate_location(dataset)
      |> validate_unique_tables(dataset)
      |> validate_tables(dataset)

    case errors do
      [] -> {:ok, dataset}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Adds a table to the dataset.
  """
  @spec add_table(t(), TableDef.t()) :: t()
  def add_table(%__MODULE__{} = dataset, %TableDef{} = table) do
    %{dataset | tables: dataset.tables ++ [table]}
  end

  @doc """
  Gets a table by name from the dataset.
  """
  @spec get_table(t(), String.t()) :: TableDef.t() | nil
  def get_table(%__MODULE__{tables: tables}, name) do
    Enum.find(tables, fn table -> table.name == name end)
  end

  # ============================================================================
  # DDL Generation
  # ============================================================================

  @doc """
  Generate BigQuery DDL (CREATE SCHEMA) for this dataset.

  ## Parameters

  - `dataset` - The Dataset struct
  - `project_id` - The GCP project ID

  ## Options

  - `:if_not_exists` - Add IF NOT EXISTS clause (default: false)

  ## Examples

      iex> Dataset.to_ddl(dataset, "my-project")
      "CREATE SCHEMA `my-project.analytics` OPTIONS (location = \\"US\\")"
  """
  @spec to_ddl(t(), String.t(), keyword()) :: String.t()
  def to_ddl(%__MODULE__{} = dataset, project_id, opts \\ []) do
    if_not_exists = if Keyword.get(opts, :if_not_exists, false), do: "IF NOT EXISTS ", else: ""
    full_name = "#{project_id}.#{dataset.name}"
    options = build_schema_options(dataset.location)

    "CREATE SCHEMA #{if_not_exists}`#{full_name}`#{options}"
  end

  defp build_schema_options(nil), do: ""

  defp build_schema_options(location) do
    " OPTIONS (location = \"#{location}\")"
  end

  # Private validation helpers

  defp validate_name(errors, %{name: nil}) do
    [Error.new(:invalid_dataset_name, "Dataset name is required", [:name]) | errors]
  end

  defp validate_name(errors, %{name: name}) do
    if Regex.match?(@name_pattern, name) do
      errors
    else
      [
        Error.new(
          :invalid_dataset_name,
          "Dataset name must match pattern: starts with letter/underscore, max 1024 chars",
          [:name]
        )
        | errors
      ]
    end
  end

  defp validate_location(errors, %{location: nil}), do: errors

  defp validate_location(errors, %{location: location}) do
    if location in @valid_locations do
      errors
    else
      [
        Error.new(
          :invalid_location,
          "Invalid BigQuery location: #{location}",
          [:location]
        )
        | errors
      ]
    end
  end

  defp validate_unique_tables(errors, %{tables: tables}) do
    names = Enum.map(tables, & &1.name)
    duplicates = names -- Enum.uniq(names)

    case duplicates do
      [] ->
        errors

      dups ->
        [
          Error.new(
            :duplicate_table,
            "Duplicate table names: #{inspect(Enum.uniq(dups))}",
            [:tables]
          )
          | errors
        ]
    end
  end

  defp validate_tables(errors, %{tables: tables}) do
    tables
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {table, idx}, acc ->
      case TableDef.validate(table) do
        {:ok, _} -> acc
        {:error, table_errors} -> prepend_path_errors(acc, table_errors, [:tables, idx])
      end
    end)
  end

  defp prepend_path_errors(errors, new_errors, prefix) do
    Enum.reduce(new_errors, errors, fn error, acc ->
      [%{error | path: prefix ++ error.path} | acc]
    end)
  end
end
