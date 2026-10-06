# API Contract: Raggio.BigQuery.DDL.Parser
# This file defines the expected public API - not implementation

defmodule Raggio.BigQuery.DDL.Parser do
  @moduledoc """
  NimbleParsec-based parser for BigQuery DDL statements.

  Parses CREATE TABLE, CREATE SCHEMA, and related DDL into
  structured data that can be converted to raggio schemas.

  ## Examples

      # Parse a CREATE TABLE statement
      {:ok, parsed} = Parser.parse_create_table(\"""
        CREATE TABLE myproject.analytics.events (
          id STRING NOT NULL,
          user_id STRING,
          payload STRUCT<action STRING, metadata STRING>,
          created_at DATETIME
        )
        PARTITION BY DATE(created_at)
        CLUSTER BY user_id
      \""")

      # Convert to TableDef
      {:ok, table_def} = Parser.to_table_def(parsed)
  """

  @type parse_result :: {:ok, parsed_ddl()} | {:error, parse_error()}

  @type parsed_ddl :: %{
          statement_type: :create_table | :create_schema | :alter_table | :drop_table,
          qualified_name: qualified_name(),
          columns: [parsed_column()],
          options: map(),
          source_position: {line :: pos_integer(), column :: pos_integer()}
        }

  @type qualified_name :: %{
          project: String.t() | nil,
          dataset: String.t() | nil,
          table: String.t()
        }

  @type parsed_column :: %{
          name: String.t(),
          type: parsed_type(),
          mode: :nullable | :required | :repeated,
          description: String.t() | nil,
          options: map()
        }

  @type parsed_type ::
          :string
          | :int64
          | :float64
          | :bool
          | :bytes
          | :date
          | :datetime
          | :time
          | :timestamp
          | {:numeric, precision :: integer(), scale :: integer()}
          | {:bignumeric, precision :: integer(), scale :: integer()}
          | {:string, max_length :: integer() | :max}
          | {:bytes, max_length :: integer() | :max}
          | {:array, inner :: parsed_type()}
          | {:struct, fields :: [parsed_column()]}

  @type parse_error :: %{
          message: String.t(),
          line: pos_integer(),
          column: pos_integer(),
          context: String.t()
        }

  @doc """
  Parses a BigQuery CREATE TABLE statement.

  ## Returns
    - `{:ok, parsed_ddl}` on success
    - `{:error, parse_error}` on failure with position info
  """
  @spec parse_create_table(String.t()) :: parse_result()
  def parse_create_table(ddl_string)

  @doc """
  Parses a BigQuery CREATE SCHEMA statement.
  """
  @spec parse_create_schema(String.t()) :: parse_result()
  def parse_create_schema(ddl_string)

  @doc """
  Parses any supported BigQuery DDL statement.

  Automatically detects statement type.
  """
  @spec parse(String.t()) :: parse_result()
  def parse(ddl_string)

  @doc """
  Parses a BigQuery type expression.

  Useful for parsing standalone type definitions.

  ## Examples

      Parser.parse_type("STRUCT<name STRING, age INT64>")
      # => {:ok, {:struct, [%{name: "name", type: :string}, ...]}}

      Parser.parse_type("ARRAY<STRING>")
      # => {:ok, {:array, :string}}
  """
  @spec parse_type(String.t()) :: {:ok, parsed_type()} | {:error, parse_error()}
  def parse_type(type_string)

  @doc """
  Converts parsed DDL to a TableDef struct.

  ## Options
    - `:validate` - Run validation on result (default: true)
  """
  @spec to_table_def(parsed_ddl(), keyword()) ::
          {:ok, Raggio.BigQuery.TableDef.t()} | {:error, [Raggio.BigQuery.Error.t()]}
  def to_table_def(parsed, opts \\ [])

  @doc """
  Converts parsed DDL to a raggio.syntax AST.

  Returns a SchemaNode that can be traversed and transformed.
  """
  @spec to_syntax_ast(parsed_ddl()) :: Raggio.Syntax.SchemaNode.t()
  def to_syntax_ast(parsed)

  @doc """
  Converts parsed type to a raggio.schema Type.

  ## Examples

      Parser.to_schema_type({:struct, [%{name: "id", type: :string}]})
      # => %Type{kind: :struct, fields: [{:id, %Type{kind: :string}}]}
  """
  @spec to_schema_type(parsed_type()) :: Raggio.Schema.Type.t()
  def to_schema_type(parsed_type)
end

defmodule Raggio.BigQuery.DDL.Parser.Error do
  @moduledoc """
  Parse error with source position information.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          line: pos_integer(),
          column: pos_integer(),
          context: String.t(),
          expected: [String.t()]
        }

  defstruct [:message, :line, :column, :context, expected: []]

  @doc """
  Formats error for display.

  ## Examples

      Error.format(error)
      # => "Parse error at line 3, column 15: expected data type
      #           payload STRUCT<action STRING, metadata>
      #                                                  ^"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = error)
end
