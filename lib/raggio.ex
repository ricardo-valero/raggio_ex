defmodule Raggio do
  @moduledoc """
  Composable data schema definition, validation, and syntax manipulation.

  Raggio provides several main submodules:

  ## Core Modules

  - `Raggio.Schema` - Define and validate data schemas
  - `Raggio.Syntax` - Build and manipulate syntax trees

  ## Schema Adapters

  - `Raggio.Schema.Adapter` - Behaviour for bidirectional schema conversion
  - `Raggio.Schema.Adapters.BigQuery` - BigQuery adapter implementation

  ## BigQuery Integration

  - `Raggio.BigQuery` - BigQuery operations with pluggable HTTP/Auth
  - `Raggio.BigQuery.Composer` - Drizzle-style composable schema API
  - `Raggio.BigQuery.DDL.Parser` - Parse BigQuery DDL into schemas
  """

  @version Mix.Project.config()[:version]

  def version, do: @version
end
