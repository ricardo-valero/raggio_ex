# AST Analysis Example
# Demonstrates analyzing AST structure and patterns

alias RaggioSyntax, as: RS

# Create a complex schema for analysis
order_schema =
  RS.schema(:order, [
    RS.field(:id, RS.type(:integer)),
    RS.field(:order_number, RS.type(:string)),
    RS.field(:customer_id, RS.type(:integer)),
    RS.field(:customer_email, RS.type(:string)),
    RS.field(:total_amount, RS.type(:decimal)),
    RS.field(:tax_amount, RS.type(:decimal)),
    RS.field(:discount_amount, RS.type(:decimal)),
    RS.field(:status, RS.type(:string)),
    RS.field(:items, RS.type(:array)),
    RS.field(:shipping_address, RS.type(:map)),
    RS.field(:billing_address, RS.type(:map)),
    RS.field(:notes, RS.type(:string)),
    RS.field(:created_at, RS.type(:datetime)),
    RS.field(:updated_at, RS.type(:datetime)),
    RS.field(:completed_at, RS.type(:datetime))
  ])

ast = RS.ast(order_schema, %{domain: "e-commerce", version: "2.0"})

IO.puts("=== AST Analysis Report ===\n")

# Analysis 1: Field count and types
IO.puts("## 1. Field Statistics")

fields = RS.get_fields(ast)
IO.puts("Total fields: #{length(fields)}")

# Count by type
type_counts =
  RS.traverse(ast, %{}, fn node, acc ->
    case node.type do
      :type ->
        type_name = node.name
        {:continue, Map.update(acc, type_name, 1, &(&1 + 1))}

      _ ->
        {:continue, acc}
    end
  end)

IO.puts("\nType distribution:")

Enum.each(type_counts, fn {type, count} ->
  percentage = Float.round(count / length(fields) * 100, 1)
  IO.puts("  #{type}: #{count} (#{percentage}%)")
end)

# Analysis 2: Naming patterns
IO.puts("\n## 2. Naming Pattern Analysis")

field_names = Enum.map(fields, &to_string(&1.name))

id_fields = Enum.filter(field_names, &String.ends_with?(&1, "_id"))
amount_fields = Enum.filter(field_names, &String.contains?(&1, "amount"))
timestamp_fields = Enum.filter(field_names, &String.ends_with?(&1, "_at"))
address_fields = Enum.filter(field_names, &String.contains?(&1, "address"))

IO.puts("Foreign key fields (ending with _id): #{length(id_fields)}")
Enum.each(id_fields, fn name -> IO.puts("  - #{name}") end)

IO.puts("\nAmount fields: #{length(amount_fields)}")
Enum.each(amount_fields, fn name -> IO.puts("  - #{name}") end)

IO.puts("\nTimestamp fields (ending with _at): #{length(timestamp_fields)}")
Enum.each(timestamp_fields, fn name -> IO.puts("  - #{name}") end)

IO.puts("\nAddress fields: #{length(address_fields)}")
Enum.each(address_fields, fn name -> IO.puts("  - #{name}") end)

# Analysis 3: Complexity metrics
IO.puts("\n## 3. Complexity Metrics")

# Count total nodes
node_count =
  RS.traverse(ast, 0, fn _node, acc ->
    {:continue, acc + 1}
  end)

IO.puts("Total nodes in AST: #{node_count}")
IO.puts("Average nodes per field: #{Float.round(node_count / length(fields), 2)}")

# Depth calculation
max_depth =
  RS.traverse(ast, {0, 0}, fn node, {current_depth, max_depth} ->
    new_depth =
      case node.type do
        :schema -> current_depth + 1
        :field -> current_depth + 1
        _ -> current_depth
      end

    {:continue, {new_depth, max(new_depth, max_depth)}}
  end)
  |> elem(1)

IO.puts("Maximum depth: #{max_depth}")

# Analysis 4: Data quality indicators
IO.puts("\n## 4. Data Quality Indicators")

# Check for potential duplicates
duplicate_patterns =
  field_names
  |> Enum.group_by(fn name ->
    name
    |> String.split("_")
    |> List.first()
  end)
  |> Enum.filter(fn {_, names} -> length(names) > 1 end)

if Enum.any?(duplicate_patterns) do
  IO.puts("\nPotential duplicate patterns detected:")

  Enum.each(duplicate_patterns, fn {prefix, names} ->
    IO.puts("  #{prefix}: #{inspect(names)}")
  end)
else
  IO.puts("No obvious duplicate patterns detected")
end

# Check for required audit fields
audit_fields = ["created_at", "updated_at"]
has_audit_fields = Enum.all?(audit_fields, &(&1 in field_names))

IO.puts("\nAudit fields present: #{has_audit_fields}")

if has_audit_fields do
  IO.puts("  ✓ Schema includes standard audit fields")
else
  missing = Enum.filter(audit_fields, &(&1 not in field_names))
  IO.puts("  ✗ Missing audit fields: #{inspect(missing)}")
end

# Analysis 5: Domain analysis
IO.puts("\n## 5. Domain Context")

IO.puts("Domain: #{ast.metadata.domain}")
IO.puts("Version: #{ast.metadata.version}")

# Infer domain from field names
domain_indicators = %{
  "e-commerce" => ["order", "customer", "total", "discount", "shipping"],
  "financial" => ["amount", "tax", "billing", "payment"],
  "temporal" => ["created_at", "updated_at", "completed_at"]
}

detected_domains =
  Enum.reduce(domain_indicators, %{}, fn {domain, keywords}, acc ->
    matches =
      Enum.count(field_names, fn name ->
        Enum.any?(keywords, &String.contains?(name, &1))
      end)

    if matches > 0 do
      Map.put(acc, domain, matches)
    else
      acc
    end
  end)

IO.puts("\nDomain indicators:")

Enum.each(detected_domains, fn {domain, count} ->
  IO.puts("  #{domain}: #{count} matches")
end)

# Analysis 6: Recommendations
IO.puts("\n## 6. Recommendations")

recommendations = []

recommendations =
  if length(fields) > 10 do
    [
      "Consider splitting into multiple related schemas (#{length(fields)} fields is complex)"
      | recommendations
    ]
  else
    recommendations
  end

recommendations =
  if length(amount_fields) > 2 do
    ["Consider creating a Money/Amount nested type for amount fields" | recommendations]
  else
    recommendations
  end

recommendations =
  if length(address_fields) > 1 do
    ["Consider extracting address fields into a separate Address schema" | recommendations]
  else
    recommendations
  end

if Enum.any?(recommendations) do
  Enum.each(recommendations, fn rec -> IO.puts("  • #{rec}") end)
else
  IO.puts("  Schema design looks good!")
end

IO.puts("\n✓ AST analysis complete!")
