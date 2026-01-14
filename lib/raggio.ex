defmodule Raggio do
  @moduledoc """
  Composable data schema definition, validation, and syntax manipulation.

  Raggio provides two main submodules:

  - `Raggio.Schema` - Define and validate data schemas
  - `Raggio.Syntax` - Build and manipulate syntax trees
  """

  @version Mix.Project.config()[:version]

  def version, do: @version
end
