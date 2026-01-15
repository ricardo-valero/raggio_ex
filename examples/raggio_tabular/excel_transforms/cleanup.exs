alias Raggio.Tabular.Transform

IO.puts("=== Spreadsheet Transforms Example ===\n")

IO.puts("1. Currency symbol stripping:")
test_values = ["$1,234.56", "€999.99", "£50.00", "100.00"]
strip = Transform.strip_currency()

Enum.each(test_values, fn val ->
  result = strip.(val)
  IO.puts("  #{val} -> #{result}")
end)

IO.puts("\n2. Thousand separator removal:")
test_numbers = ["1,234.56", "1,000,000.00", "999.99"]
remove_sep = Transform.remove_thousand_separators()

Enum.each(test_numbers, fn val ->
  result = remove_sep.(val)
  IO.puts("  #{val} -> #{result}")
end)

IO.puts("\n3. Whitespace trimming:")
test_strings = ["  hello  ", " world ", "no trim"]
trim = Transform.trim_whitespace()

Enum.each(test_strings, fn val ->
  result = trim.(val)
  IO.puts("  \"#{val}\" -> \"#{result}\"")
end)

IO.puts("\n4. Float to integer ID:")
test_floats = ["123.0", "456.00", "789.5"]
float_to_int = Transform.float_to_integer_id()

Enum.each(test_floats, fn val ->
  result = float_to_int.(val)
  IO.puts("  #{val} -> #{result}")
end)

IO.puts("\n5. Excel date serial conversion:")
test_dates = ["44927", "45000"]
date_convert = Transform.excel_date_serial_to_date()

Enum.each(test_dates, fn val ->
  result = date_convert.(val)
  IO.puts("  #{val} -> #{result}")
end)

IO.puts("\n6. Composed transforms:")

composed =
  Transform.compose([
    Transform.trim_whitespace(),
    Transform.strip_currency(),
    Transform.remove_thousand_separators()
  ])

messy_value = "  $1,234.56  "
result = composed.(messy_value)
IO.puts("  \"#{messy_value}\" -> \"#{result}\"")

IO.puts("\nTransforms can be applied to a SheetSchema:")

IO.puts("""
  schema = SheetSchema.define([...])
    |> SheetSchema.with_transforms([
      Transform.trim_whitespace(),
      Transform.strip_currency()
    ])
""")

IO.puts("\nSpreadsheet transforms example complete!")
