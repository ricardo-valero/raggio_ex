alias RaggioTabular.Transforms.Excel

IO.puts("=== Excel Transforms Example ===\n")

IO.puts("1. Decimal cleanup (currency):")
test_decimals = ["$1,234.56", "€999.99", "1,000,000.00", "123.45"]

Enum.each(test_decimals, fn val ->
  {:ok, result} = Excel.excel_decimal(val)
  IO.puts("  #{val} -> #{result}")
end)

IO.puts("\n2. Float ID to integer:")
test_floats = ["123.0", "456.00", 789.0, 1000]

Enum.each(test_floats, fn val ->
  {:ok, result} = Excel.excel_integer(val)
  IO.puts("  #{inspect(val)} -> #{result}")
end)

IO.puts("\n3. Float to string ID:")
test_ids = [123.0, 456, "789.0", "001234"]

Enum.each(test_ids, fn val ->
  {:ok, result} = Excel.excel_string(val)
  IO.puts("  #{inspect(val)} -> \"#{result}\"")
end)

IO.puts("\n4. Whitespace trimming:")
test_strings = ["  hello  ", " \u00A0world\u00A0 ", "no trim needed"]

Enum.each(test_strings, fn val ->
  {:ok, result} = Excel.excel_trim(val)
  IO.puts("  #{inspect(val)} -> \"#{result}\"")
end)

IO.puts("\n5. Excel date serial:")
test_dates = [44927, 44562, 45000]

Enum.each(test_dates, fn val ->
  {:ok, result} = Excel.excel_date(val)
  IO.puts("  #{val} -> #{result}")
end)

IO.puts("\n6. Chained transforms:")
messy_value = "  $1,234.56  "

{:ok, result} =
  Excel.pipe_transforms(messy_value, [
    &Excel.excel_trim/1,
    &Excel.excel_decimal/1
  ])

IO.puts("  \"#{messy_value}\" -> #{result}")

IO.puts("\nExcel transforms complete!")
