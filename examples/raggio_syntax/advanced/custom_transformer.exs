# Custom Transformer Example
# Demonstrates US4: Extending functionality through composition

# This example shows how to create custom AST transformers using
# RaggioSyntax's composable API.

alias RaggioSyntax, as: RS

# =============================================================================
# Example 1: Field Annotation Transformer
# =============================================================================

IO.puts("Example 1: Field Annotation Transformer")
IO.puts("=======================================\n")

# Create a base schema
user_schema =
  RS.schema(:user, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:name, RS.type(:string)),
    RS.field(:email, RS.type(:string)),
    RS.field(:created_at, RS.type(:datetime))
  ])

user_ast = RS.ast(user_schema)

# Custom transformer: Add database column info to field metadata
defmodule FieldAnnotator do
  @doc """
  Annotates fields with database column information.
  """
  def with_db_columns(ast) do
    RaggioSyntax.transform(ast, fn node ->
      case node do
        %{type: :field, name: name, field_type: %{name: type_name}} = field ->
          db_info = %{
            column_name: Atom.to_string(name),
            db_type: type_to_db_type(type_name),
            nullable: Map.get(field, :required, false) == false
          }

          Map.put(field, :metadata, Map.merge(field.metadata || %{}, %{db: db_info}))

        other ->
          other
      end
    end)
  end

  defp type_to_db_type(:integer), do: "BIGINT"
  defp type_to_db_type(:string), do: "VARCHAR(255)"
  defp type_to_db_type(:datetime), do: "TIMESTAMP"
  defp type_to_db_type(:boolean), do: "BOOLEAN"
  defp type_to_db_type(_), do: "TEXT"
end

annotated_ast = FieldAnnotator.with_db_columns(user_ast)

IO.puts("Fields with DB annotations:")

RS.traverse(annotated_ast, fn node ->
  case node do
    %{type: :field, name: name, metadata: %{db: db}} ->
      IO.puts("  #{name}: #{db.db_type} #{if db.nullable, do: "NULL", else: "NOT NULL"}")

    _ ->
      nil
  end
end)

# =============================================================================
# Example 2: Schema Versioning Transformer
# =============================================================================

IO.puts("\n\nExample 2: Schema Versioning Transformer")
IO.puts("========================================\n")

defmodule SchemaVersioner do
  @doc """
  Adds version tracking to schema and all fields.
  """
  def add_version(ast, version) do
    RaggioSyntax.transform(ast, fn node ->
      case node do
        %{type: :schema} = schema ->
          metadata =
            Map.merge(schema.metadata || %{}, %{
              version: version,
              created_at: DateTime.utc_now() |> DateTime.to_iso8601()
            })

          Map.put(schema, :metadata, metadata)

        %{type: :field} = field ->
          metadata =
            Map.merge(field.metadata || %{}, %{
              since_version: version
            })

          Map.put(field, :metadata, metadata)

        other ->
          other
      end
    end)
  end

  @doc """
  Marks deprecated fields.
  """
  def deprecate_fields(ast, field_names, reason \\ "Deprecated") do
    RaggioSyntax.transform(ast, fn node ->
      case node do
        %{type: :field, name: name} = field ->
          if name in field_names do
            metadata =
              Map.merge(field.metadata || %{}, %{
                deprecated: true,
                deprecation_reason: reason
              })

            Map.put(field, :metadata, metadata)
          else
            field
          end

        other ->
          other
      end
    end)
  end
end

versioned_ast =
  user_ast
  |> SchemaVersioner.add_version("1.0.0")
  |> SchemaVersioner.deprecate_fields([:created_at], "Use updated_at instead")

schema_node = RS.find(versioned_ast, fn n -> n.type == :schema end)
IO.puts("Schema version: #{schema_node.metadata.version}")

deprecated =
  RS.find_all(versioned_ast, fn n ->
    n.type == :field && Map.get(n.metadata || %{}, :deprecated) == true
  end)

IO.puts("Deprecated fields: #{Enum.map(deprecated, & &1.name) |> inspect()}")

# =============================================================================
# Example 3: Type Migration Transformer
# =============================================================================

IO.puts("\n\nExample 3: Type Migration Transformer")
IO.puts("=====================================\n")

defmodule TypeMigrator do
  @doc """
  Migrates types according to a mapping.
  """
  def migrate_types(ast, type_mapping) do
    RaggioSyntax.transform(ast, fn node ->
      case node do
        %{type: :type, name: old_name} = type_node ->
          case Map.get(type_mapping, old_name) do
            nil -> type_node
            new_name -> %{type_node | name: new_name}
          end

        other ->
          other
      end
    end)
  end

  @doc """
  Adds precision to numeric types.
  """
  def add_numeric_precision(ast, precision_opts \\ []) do
    RaggioSyntax.transform(ast, fn node ->
      case node do
        %{type: :type, name: :decimal} = type_node ->
          metadata =
            Map.merge(type_node.metadata || %{}, %{
              precision: Keyword.get(precision_opts, :precision, 18),
              scale: Keyword.get(precision_opts, :scale, 2)
            })

          Map.put(type_node, :metadata, metadata)

        other ->
          other
      end
    end)
  end
end

# Create a schema with old types
order_schema =
  RS.schema(:order, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:total, RS.type(:float)),
    RS.field(:status, RS.type(:string))
  ])

order_ast = RS.ast(order_schema)

migrated_ast =
  TypeMigrator.migrate_types(order_ast, %{
    float: :decimal,
    string: :text
  })

IO.puts("Original types:")

RS.traverse(order_ast, fn n ->
  if n.type == :type, do: IO.puts("  - #{n.name}")
end)

IO.puts("\nMigrated types:")

RS.traverse(migrated_ast, fn n ->
  if n.type == :type, do: IO.puts("  - #{n.name}")
end)

# =============================================================================
# Example 4: Composite Transformer Pipeline
# =============================================================================

IO.puts("\n\nExample 4: Composite Transformer Pipeline")
IO.puts("=========================================\n")

defmodule TransformerPipeline do
  @doc """
  Runs multiple transformers in sequence.
  """
  def run(ast, transformers) do
    Enum.reduce(transformers, ast, fn transformer, acc ->
      transformer.(acc)
    end)
  end
end

# Define transformers as functions
add_timestamps = fn ast ->
  RaggioSyntax.transform(ast, fn node ->
    case node do
      %{type: :field} = field ->
        Map.put(
          field,
          :metadata,
          Map.merge(field.metadata || %{}, %{
            tracked: true
          })
        )

      other ->
        other
    end
  end)
end

uppercase_field_names = fn ast ->
  RaggioSyntax.transform(ast, fn node ->
    case node do
      %{type: :field, name: name} = field ->
        Map.put(
          field,
          :metadata,
          Map.merge(field.metadata || %{}, %{
            display_name: name |> Atom.to_string() |> String.upcase()
          })
        )

      other ->
        other
    end
  end)
end

# Run pipeline
pipeline_result =
  TransformerPipeline.run(user_ast, [
    add_timestamps,
    uppercase_field_names
  ])

IO.puts("Pipeline result - field display names:")

RS.traverse(pipeline_result, fn n ->
  case n do
    %{type: :field, name: name, metadata: %{display_name: display}} ->
      IO.puts("  #{name} -> #{display}")

    _ ->
      nil
  end
end)

IO.puts("\n\nCustom transformer composition complete!")
