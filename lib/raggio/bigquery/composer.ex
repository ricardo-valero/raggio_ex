defmodule Raggio.BigQuery.Composer do
  @moduledoc """
  Fluent builder API for composing BigQuery project hierarchies.

  Provides a Drizzle-inspired composable API for defining BigQuery schemas with
  a declarative, chainable syntax.

  ## Usage

      import Raggio.BigQuery.Composer
      alias Raggio.Schema

      project("my-analytics-project")
      |> dataset("raw", location: "US")
      |> table("events", [
        column(:id, Schema.string(), mode: :required),
        column(:event_type, Schema.string(), mode: :required),
        column(:created_at, Schema.datetime(), mode: :required)
      ],
        partition_by: {:field, :created_at, :day},
        cluster_by: [:event_type]
      )
      |> table("users", [
        column(:id, Schema.string(), mode: :required),
        column(:email, Schema.string(), mode: :required)
      ])
      |> dataset("staging")
      |> table("processed_events", [
        column(:id, Schema.string(), mode: :required)
      ])
      |> build!()

  ## Builder Pattern

  The Composer uses a Context struct to accumulate definitions:

  1. `project/1,2` - Initialize with project ID
  2. `dataset/2,3` - Set current dataset (flushes previous)
  3. `table/3` - Add table to current dataset
  4. `column/2,3` - Create column for use in table definitions
  5. `build/1` or `build!/1` - Finalize and validate

  ## Column Helpers

  For convenience, column definitions can use `Raggio.Schema` type constructors:

      column(:id, Schema.string(), mode: :required)
      column(:count, Schema.integer())
      column(:tags, Schema.list(Schema.string()), mode: :repeated)
  """

  alias Raggio.BigQuery.{Project, Dataset, TableDef, Column, Error}
  alias Raggio.Schema.Type

  @type context :: %__MODULE__.Context{}

  defmodule Context do
    @moduledoc false

    @type t :: %__MODULE__{
            project_id: String.t(),
            current_dataset: String.t() | nil,
            datasets: map(),
            pending_tables: [TableDef.t()],
            dataset_opts: keyword(),
            metadata: map(),
            errors: [Error.t()]
          }

    defstruct project_id: nil,
              current_dataset: nil,
              datasets: %{},
              pending_tables: [],
              dataset_opts: [],
              metadata: %{},
              errors: []
  end

  # ============================================================================
  # Project Builder Functions
  # ============================================================================

  @doc """
  Initialize a new project builder context.

  ## Options

  - `:metadata` - Custom metadata map for the project

  ## Examples

      iex> Composer.project("my-project")
      %Composer.Context{project_id: "my-project", ...}

      iex> Composer.project("my-project", metadata: %{env: "prod"})
      %Composer.Context{project_id: "my-project", metadata: %{env: "prod"}, ...}
  """
  @spec project(String.t(), keyword()) :: Context.t()
  def project(project_id, opts \\ []) do
    %Context{
      project_id: project_id,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Set the current dataset in the builder context.

  If a previous dataset was being built, it is flushed (saved) first.

  ## Options

  - `:location` - Geographic location (e.g., "US", "EU")
  - `:default_partition_expiration_ms` - Auto-delete partitions after N ms
  - `:metadata` - Custom metadata map

  ## Examples

      iex> project("my-project") |> dataset("analytics")
      %Composer.Context{current_dataset: "analytics", ...}

      iex> project("my-project") |> dataset("analytics", location: "US")
      %Composer.Context{current_dataset: "analytics", dataset_opts: [location: "US"], ...}
  """
  @spec dataset(Context.t(), String.t(), keyword()) :: Context.t()
  def dataset(%Context{} = ctx, name, opts \\ []) do
    ctx
    |> flush_current_dataset()
    |> Map.merge(%{
      current_dataset: name,
      pending_tables: [],
      dataset_opts: opts
    })
  end

  @doc """
  Add a table definition to the current dataset.

  ## Options

  - `:partition_by` - Partitioning configuration
  - `:cluster_by` - List of clustering columns (max 4)
  - `:description` - Table description
  - `:expiration_time` - Table expiration DateTime
  - `:metadata` - Custom metadata map

  ## Examples

      iex> project("p") |> dataset("d") |> table("t", [column(:id, %Type{kind: :string})])
      %Composer.Context{pending_tables: [%TableDef{name: "t", ...}], ...}
  """
  @spec table(Context.t(), String.t(), [Column.t()], keyword()) :: Context.t()
  def table(%Context{} = ctx, name, columns, opts \\ []) do
    table_def = TableDef.new(name, columns, opts)

    %{ctx | pending_tables: ctx.pending_tables ++ [table_def]}
  end

  @doc """
  Create a column definition.

  This is a helper function for creating columns to pass to `table/3`.

  The function also extracts mode and description from type metadata if not
  explicitly provided in options. This enables pipe composition:

      column(:id, Schema.string() |> required() |> description("Unique ID"))

  ## Options

  - `:mode` - Column mode: `:nullable` (default), `:required`, or `:repeated`
  - `:description` - Column description
  - `:default_value` - Default value expression
  - `:metadata` - Custom metadata map

  ## Examples

      iex> Composer.column(:id, %Type{kind: :string}, mode: :required)
      %Column{name: :id, type: %Type{kind: :string}, mode: :required}

      iex> Composer.column(:email, %Type{kind: :string}, description: "User email")
      %Column{name: :email, type: %Type{kind: :string}, description: "User email"}

      # Using pipe composition
      iex> Composer.column(:id, %Type{kind: :string} |> required())
      %Column{name: :id, type: %Type{kind: :string}, mode: :required}
  """
  @spec column(atom() | String.t(), Type.t(), keyword()) :: Column.t()
  def column(name, type, opts \\ []) do
    # Extract mode and description from type metadata if not in opts
    type_metadata = type.metadata || %{}

    opts =
      opts
      |> maybe_extract_from_metadata(:mode, type_metadata)
      |> maybe_extract_from_metadata(:description, type_metadata)

    Column.new(name, type, opts)
  end

  # ============================================================================
  # Pipe Composition Functions (Effect-TS/Schema Style)
  # ============================================================================

  @doc """
  Mark a type as required (NOT NULL in BigQuery).

  This function is designed for pipe composition:

      Schema.string() |> required()

  The mode is stored in `Type.metadata[:mode]` and extracted by `column/3`.

  ## Examples

      iex> %Type{kind: :string} |> Composer.required()
      %Type{kind: :string, metadata: %{mode: :required}}
  """
  @spec required(Type.t()) :: Type.t()
  def required(%Type{} = type) do
    update_metadata(type, :mode, :required)
  end

  @doc """
  Mark a type as repeated (ARRAY in BigQuery).

  This function is designed for pipe composition:

      Schema.string() |> repeated()

  The mode is stored in `Type.metadata[:mode]` and extracted by `column/3`.

  ## Examples

      iex> %Type{kind: :string} |> Composer.repeated()
      %Type{kind: :string, metadata: %{mode: :repeated}}
  """
  @spec repeated(Type.t()) :: Type.t()
  def repeated(%Type{} = type) do
    update_metadata(type, :mode, :repeated)
  end

  @doc """
  Add a description to a type.

  This function is designed for pipe composition:

      Schema.string() |> description("User email address")

  The description is stored in `Type.metadata[:description]` and extracted by `column/3`.

  ## Examples

      iex> %Type{kind: :string} |> Composer.description("User email")
      %Type{kind: :string, metadata: %{description: "User email"}}
  """
  @spec description(Type.t(), String.t()) :: Type.t()
  def description(%Type{} = type, desc) when is_binary(desc) do
    update_metadata(type, :description, desc)
  end

  @doc """
  Finalize the builder and return the validated Project.

  ## Returns

  - `{:ok, project}` if valid
  - `{:error, errors}` if validation fails

  ## Examples

      iex> project("my-project") |> dataset("d") |> table("t", [...]) |> build()
      {:ok, %Project{...}}
  """
  @spec build(Context.t()) :: {:ok, Project.t()} | {:error, [Error.t()]}
  def build(%Context{} = ctx) do
    ctx = flush_current_dataset(ctx)

    datasets =
      ctx.datasets
      |> Enum.map(fn {name, %{tables: tables, opts: opts}} ->
        Dataset.new(name, tables, opts)
      end)

    project = Project.new(ctx.project_id, datasets, metadata: ctx.metadata)

    case Project.validate(project) do
      {:ok, _} = result -> result
      {:error, errors} -> {:error, ctx.errors ++ errors}
    end
  end

  @doc """
  Finalize the builder and return the Project, raising on error.

  ## Raises

  - `RuntimeError` if validation fails

  ## Examples

      iex> project("my-project") |> dataset("d") |> table("t", [...]) |> build!()
      %Project{...}
  """
  @spec build!(Context.t()) :: Project.t()
  def build!(%Context{} = ctx) do
    case build(ctx) do
      {:ok, project} ->
        project

      {:error, errors} ->
        error_msg = Error.format_all(errors)
        raise "Failed to build BigQuery project:\n#{error_msg}"
    end
  end

  # ============================================================================
  # Module Conversion (Backward Compatibility)
  # ============================================================================

  @doc """
  Convert existing `Raggio.BigQuery.Table` behaviour modules to a Project.

  This provides backward compatibility with the existing Table-based API,
  allowing you to migrate gradually to the new Composer API.

  ## Arguments

  - `modules` - List of modules implementing `Raggio.BigQuery.Table` behaviour
  - `project_id` - The BigQuery project ID
  - `opts` - Options passed to the project

  ## Returns

  - `{:ok, project}` - Successfully converted modules to a Project
  - `{:error, errors}` - Conversion or validation failed

  ## Examples

      {:ok, proj} = Composer.from_modules([
        MyApp.Tables.Events,
        MyApp.Tables.Users
      ], "my-project")

      # Modules from the same dataset are grouped together
  """
  @spec from_modules([module()], String.t(), keyword()) ::
          {:ok, Project.t()} | {:error, [Error.t()]}
  def from_modules(modules, project_id, opts \\ [])

  def from_modules([], _project_id, _opts) do
    {:error, [%Error{type: :invalid_argument, message: "modules list cannot be empty", path: []}]}
  end

  def from_modules(modules, project_id, opts) do
    # Group modules by dataset
    modules_by_dataset =
      modules
      |> Enum.map(fn mod ->
        {mod.__dataset__(), mod}
      end)
      |> Enum.group_by(fn {dataset, _mod} -> dataset end, fn {_dataset, mod} -> mod end)

    # Convert each dataset and its tables
    datasets =
      modules_by_dataset
      |> Enum.map(fn {dataset_name, mods} ->
        tables = Enum.map(mods, &module_to_table_def/1)
        Dataset.new(dataset_name, tables, [])
      end)

    # Build project
    project = Project.new(project_id, datasets, opts)
    Project.validate(project)
  end

  @doc """
  Convert existing `Raggio.BigQuery.Table` behaviour modules to a Project, raising on error.

  See `from_modules/3` for details.

  ## Raises

  - `RuntimeError` if validation fails
  """
  @spec from_modules!([module()], String.t(), keyword()) :: Project.t()
  def from_modules!(modules, project_id, opts \\ []) do
    case from_modules(modules, project_id, opts) do
      {:ok, project} ->
        project

      {:error, errors} ->
        error_msg = Error.format_all(errors)
        raise "Failed to convert modules to BigQuery project:\n#{error_msg}"
    end
  end

  defp module_to_table_def(mod) do
    schema = mod.__schema__()
    table_name = mod.__table__()

    # Extract columns from struct schema
    columns =
      case schema do
        %Type{kind: :struct, fields: fields} ->
          Enum.map(fields, fn {name, field_type} ->
            mode = extract_mode(field_type)
            Column.new(name, field_type, mode: mode)
          end)

        _ ->
          []
      end

    # Extract partitioning
    partition_by =
      case safe_callback(mod, :__time_partitioning__, 0) do
        nil ->
          nil

        partition_opts ->
          field = Keyword.get(partition_opts, :field)
          type = Keyword.get(partition_opts, :type, :day)
          {:field, field, type}
      end

    # Extract clustering
    cluster_by = safe_callback(mod, :__clustering__, 0)

    TableDef.new(table_name, columns,
      partition_by: partition_by,
      cluster_by: cluster_by
    )
  end

  defp safe_callback(mod, callback, arity) do
    if function_exported?(mod, callback, arity) do
      apply(mod, callback, [])
    else
      nil
    end
  end

  defp extract_mode(%Type{kind: :list}), do: :repeated
  defp extract_mode(%Type{optional: true}), do: :nullable
  defp extract_mode(%Type{nullable: true}), do: :nullable
  defp extract_mode(_), do: :required

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp flush_current_dataset(%Context{current_dataset: nil} = ctx), do: ctx

  defp flush_current_dataset(
         %Context{current_dataset: name, pending_tables: tables, dataset_opts: opts} = ctx
       ) do
    dataset_entry = %{tables: tables, opts: opts}

    %{
      ctx
      | datasets: Map.put(ctx.datasets, name, dataset_entry),
        current_dataset: nil,
        pending_tables: [],
        dataset_opts: []
    }
  end

  defp update_metadata(%Type{metadata: metadata} = type, key, value) do
    %{type | metadata: Map.put(metadata || %{}, key, value)}
  end

  defp maybe_extract_from_metadata(opts, key, type_metadata) do
    if Keyword.has_key?(opts, key) do
      opts
    else
      case Map.get(type_metadata, key) do
        nil -> opts
        value -> Keyword.put(opts, key, value)
      end
    end
  end
end
