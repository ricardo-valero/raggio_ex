defmodule Raggio.BigQuery.Error do
  @moduledoc """
  Represents a validation error for BigQuery schema definitions.

  ## Fields

  - `type` - Error type atom (e.g., `:invalid_project_id`, `:duplicate_table`)
  - `message` - Human-readable error message
  - `path` - Path to the invalid field (e.g., `[:datasets, 0, :tables, 1, :name]`)

  ## Error Types

  | Type | Description |
  |------|-------------|
  | `:invalid_project_id` | Project ID doesn't match required format |
  | `:duplicate_dataset` | Duplicate dataset names in project |
  | `:invalid_dataset_name` | Dataset name doesn't match required format |
  | `:duplicate_table` | Duplicate table names in dataset |
  | `:invalid_table_name` | Table name doesn't match required format |
  | `:duplicate_column` | Duplicate column names in table |
  | `:invalid_column_name` | Column name doesn't match required format |
  | `:invalid_partition_field` | Partition field references non-existent column |
  | `:invalid_clustering` | Clustering configuration is invalid |
  | `:unsupported_type` | Column type not supported by BigQuery |
  | `:invalid_mode` | Invalid column mode |
  | `:invalid_location` | Invalid BigQuery location/region |

  ## Examples

      %Error{
        type: :invalid_project_id,
        message: "Project ID must be 6-30 lowercase letters, digits, or hyphens",
        path: [:project_id]
      }
  """

  @type error_type ::
          :invalid_project_id
          | :duplicate_dataset
          | :invalid_dataset_name
          | :duplicate_table
          | :invalid_table_name
          | :duplicate_column
          | :invalid_column_name
          | :invalid_partition_field
          | :invalid_clustering
          | :unsupported_type
          | :invalid_mode
          | :invalid_location

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          path: [atom() | String.t() | integer()]
        }

  defstruct type: nil,
            message: nil,
            path: []

  @doc """
  Creates a new Error struct.

  ## Examples

      iex> Error.new(:invalid_project_id, "Invalid format", [:project_id])
      %Error{type: :invalid_project_id, message: "Invalid format", path: [:project_id]}
  """
  @spec new(error_type(), String.t(), list()) :: t()
  def new(type, message, path \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      path: path
    }
  end

  @doc """
  Formats an error as a human-readable string.

  ## Examples

      iex> Error.format(%Error{type: :invalid_project_id, message: "Bad format", path: [:project_id]})
      "[project_id] invalid_project_id: Bad format"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{type: type, message: message, path: path}) do
    path_str =
      case path do
        [] -> ""
        _ -> "[#{Enum.join(Enum.map(path, &to_string/1), ".")}] "
      end

    "#{path_str}#{type}: #{message}"
  end

  @doc """
  Formats a list of errors as a human-readable string.
  """
  @spec format_all([t()]) :: String.t()
  def format_all(errors) when is_list(errors) do
    errors
    |> Enum.map(&format/1)
    |> Enum.join("\n")
  end
end
