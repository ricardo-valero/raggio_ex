defmodule Raggio.Schema.Importer.SheetSchemaTest do
  use ExUnit.Case, async: true

  alias Raggio.Schema.Importer.SheetSchema

  describe "from_csv/1" do
    test "imports simple schema from CSV" do
      csv_content = """
      field_name,type,required,constraints
      name,string,true,min(2)
      age,integer,false,min(0)
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "Raggio.Schema.struct")
      assert String.contains?(code, ":name")
      assert String.contains?(code, ":age")
      assert String.contains?(code, "min: 2")

      File.rm(path)
    end

    test "imports schema with nested fields" do
      csv_content = """
      field_name,type,required,parent_path
      name,string,true,
      street,string,false,address
      city,string,false,address
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, ":name")
      assert String.contains?(code, ":address")
      assert String.contains?(code, ":street")
      assert String.contains?(code, ":city")

      File.rm(path)
    end

    test "returns error for missing file" do
      assert {:error, _} = SheetSchema.from_csv("/nonexistent/file.csv")
    end

    test "returns error for invalid format" do
      csv_content = """
      wrong_column,other_column
      value1,value2
      """

      path = write_temp_csv(csv_content)

      assert {:error, {:format_error, message, _}} = SheetSchema.from_csv(path)
      assert String.contains?(message, "Missing required columns")

      File.rm(path)
    end
  end

  describe "from_csv/2 with options" do
    test "wraps code in module when module_name option provided" do
      csv_content = """
      field_name,type
      name,string
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path, module_name: "MySchema")
      assert String.contains?(code, "defmodule MySchema")
      assert String.contains?(code, "def schema do")

      File.rm(path)
    end
  end

  describe "validate/1" do
    test "validates correct format" do
      csv_content = """
      field_name,type
      name,string
      age,integer
      """

      path = write_temp_csv(csv_content)

      assert :ok = SheetSchema.validate(path)

      File.rm(path)
    end

    test "returns errors for invalid format" do
      csv_content = """
      field_name,type
      ,string
      name,invalid_type
      """

      path = write_temp_csv(csv_content)

      assert {:error, {:validation_errors, errors}} = SheetSchema.validate(path)
      assert length(errors) > 0

      File.rm(path)
    end
  end

  describe "type parsing" do
    test "parses primitive types" do
      csv_content = """
      field_name,type
      str_field,string
      int_field,integer
      float_field,float
      bool_field,boolean
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "Raggio.Schema.string()")
      assert String.contains?(code, "Raggio.Schema.integer()")
      assert String.contains?(code, "Raggio.Schema.float()")
      assert String.contains?(code, "Raggio.Schema.boolean()")

      File.rm(path)
    end

    test "parses list types" do
      csv_content = """
      field_name,type
      tags,list(string)
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "Raggio.Schema.list")

      File.rm(path)
    end
  end

  describe "constraint parsing" do
    test "parses pipe-separated constraints" do
      csv_content = """
      field_name,type,constraints
      email,string,max(255)
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "max: 255")

      File.rm(path)
    end

    test "handles min constraint" do
      csv_content = """
      field_name,type,constraints
      age,integer,min(0)
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "min: 0")

      File.rm(path)
    end
  end

  describe "optional and default handling" do
    test "marks fields as optional when required is false" do
      csv_content = """
      field_name,type,required
      name,string,false
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "Raggio.Schema.optional(")

      File.rm(path)
    end

    test "adds default values" do
      csv_content = """
      field_name,type,default
      status,string,active
      """

      path = write_temp_csv(csv_content)

      assert {:ok, code} = SheetSchema.from_csv(path)
      assert String.contains?(code, "default")

      File.rm(path)
    end
  end

  # Helper functions

  defp write_temp_csv(content) do
    path = Path.join(System.tmp_dir!(), "test_schema_#{:rand.uniform(100_000)}.csv")
    File.write!(path, content)
    path
  end
end
