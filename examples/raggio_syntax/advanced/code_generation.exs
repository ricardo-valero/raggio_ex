# Code Generation Example
# Demonstrates generating code from AST

alias RaggioSyntax, as: RS

# Create a schema to generate code from
user_schema =
  RS.schema(:user, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:name, RS.type(:string)),
    RS.field(:email, RS.type(:string)),
    RS.field(:age, RS.type(:integer))
  ])

ast = RS.ast(user_schema, %{namespace: "MyApp"})

IO.puts("Generating code from AST...\n")

# Helper: Map AST types to Elixir types
defmodule TypeMapper do
  def to_elixir_type(:string), do: "String.t()"
  def to_elixir_type(:integer), do: "integer()"
  def to_elixir_type(:datetime), do: "DateTime.t()"
  def to_elixir_type(:decimal), do: "Decimal.t()"
  def to_elixir_type(:boolean), do: "boolean()"
  def to_elixir_type(:array), do: "list()"
  def to_elixir_type(:map), do: "map()"
  def to_elixir_type(other), do: "term()"
end

# Code Generator 1: Generate struct definition
IO.puts("=== Generated Struct Definition ===\n")

fields = RS.get_fields(ast)
schema_name = ast.root.name |> to_string() |> String.capitalize()

struct_code = """
defmodule #{ast.metadata.namespace}.#{schema_name} do
  @moduledoc \"\"\"
  #{schema_name} entity
  Generated from AST
  \"\"\"

  defstruct [
#{Enum.map_join(fields, ",\n", fn field -> "    :#{field.name}" end)}
  ]

  @type t :: %__MODULE__{
#{Enum.map_join(fields, ",\n", fn field -> "    #{field.name}: #{TypeMapper.to_elixir_type(field.field_type.name)}" end)}
  }
end
"""

IO.puts(struct_code)

# Code Generator 2: Generate validation function
IO.puts("\n=== Generated Validation Function ===\n")

validation_code = """
defmodule #{ast.metadata.namespace}.#{schema_name}Validator do
  @moduledoc \"\"\"
  Validation functions for #{schema_name}
  Generated from AST
  \"\"\"

  def validate(data) do
    with #{Enum.map_join(fields, ",\n         ", fn field -> ":ok <- validate_#{field.name}(data[:#{field.name}])" end)} do
      {:ok, data}
    end
  end

#{Enum.map_join(fields, "\n\n", fn field ->
  type_validation = case field.field_type.name do
    :string -> "is_binary(value)"
    :integer -> "is_integer(value)"
    _ -> "true"
  end

  "  defp validate_#{field.name}(value) when #{type_validation}, do: :ok\n" <> "  defp validate_#{field.name}(_), do: {:error, :invalid_#{field.name}}"
end)}
end
"""

IO.puts(validation_code)

# Code Generator 3: Generate database migration
IO.puts("\n=== Generated Database Migration ===\n")

defmodule MigrationMapper do
  def to_db_type(:string), do: "string"
  def to_db_type(:integer), do: "integer"
  def to_db_type(:datetime), do: "utc_datetime"
  def to_db_type(:decimal), do: "decimal"
  def to_db_type(:boolean), do: "boolean"
  def to_db_type(_), do: "text"
end

table_name = "#{ast.root.name}s"

migration_code = """
defmodule #{ast.metadata.namespace}.Repo.Migrations.Create#{schema_name}s do
  use Ecto.Migration

  def change do
    create table(:#{table_name}) do
#{Enum.map_join(fields, "\n", fn field -> if field.name != :id do
    "      add :#{field.name}, :#{MigrationMapper.to_db_type(field.field_type.name)}"
  else
    ""
  end end)}

      timestamps()
    end
  end
end
"""

IO.puts(migration_code)

# Code Generator 4: Generate API documentation
IO.puts("\n=== Generated API Documentation ===\n")

doc_code = """
# #{schema_name} API

## Fields

#{Enum.map_join(fields, "\n", fn field -> "- `#{field.name}` (#{field.field_type.name})" end)}

## Example

\`\`\`elixir
%#{ast.metadata.namespace}.#{schema_name}{
#{Enum.map_join(fields, ",\n", fn field ->
  example_value = case field.field_type.name do
    :string -> "\"example\""
    :integer -> "123"
    _ -> "nil"
  end

  "  #{field.name}: #{example_value}"
end)}
}
\`\`\`
"""

IO.puts(doc_code)

IO.puts("\n✓ Code generation complete!")
