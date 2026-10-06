defmodule Raggio.BigQuery.ColumnTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Column
  alias Raggio.Schema.Type

  describe "new/3" do
    test "creates column with defaults" do
      col = Column.new(:id, %Type{kind: :string})

      assert col.name == :id
      assert col.type.kind == :string
      assert col.mode == :nullable
      assert col.description == nil
    end

    test "creates column with options" do
      col =
        Column.new(:user_id, %Type{kind: :string},
          mode: :required,
          description: "User identifier",
          metadata: %{custom: "value"}
        )

      assert col.name == :user_id
      assert col.mode == :required
      assert col.description == "User identifier"
      assert col.metadata == %{custom: "value"}
    end
  end

  describe "validate/1" do
    test "returns {:ok, column} for valid column" do
      col = %Column{name: :id, type: %Type{kind: :string}, mode: :required}

      assert {:ok, ^col} = Column.validate(col)
    end

    test "returns error for nil name" do
      col = %Column{name: nil, type: %Type{kind: :string}}

      assert {:error, errors} = Column.validate(col)
      assert Enum.any?(errors, &(&1.type == :invalid_column_name))
    end

    test "returns error for invalid name format" do
      col = %Column{name: "123invalid", type: %Type{kind: :string}}

      assert {:error, errors} = Column.validate(col)
      assert Enum.any?(errors, &(&1.type == :invalid_column_name))
    end

    test "accepts valid name patterns" do
      valid_names = [:id, :_private, :camelCase, :snake_case, :UPPER, :mixed_123]

      for name <- valid_names do
        col = %Column{name: name, type: %Type{kind: :string}}
        assert {:ok, _} = Column.validate(col), "Expected #{inspect(name)} to be valid"
      end
    end

    test "returns error for nil type" do
      col = %Column{name: :id, type: nil}

      assert {:error, errors} = Column.validate(col)
      assert Enum.any?(errors, &(&1.type == :unsupported_type))
    end

    test "returns error for unsupported type kind" do
      col = %Column{name: :id, type: %Type{kind: :unknown_type}}

      assert {:error, errors} = Column.validate(col)
      assert Enum.any?(errors, &(&1.type == :unsupported_type))
    end

    test "accepts all supported BigQuery types" do
      supported = [
        :string,
        :integer,
        :float,
        :boolean,
        :decimal,
        :datetime,
        :date,
        :time,
        :timestamp,
        :binary,
        :struct,
        :list
      ]

      for kind <- supported do
        col = %Column{name: :test, type: %Type{kind: kind}}
        assert {:ok, _} = Column.validate(col), "Expected #{inspect(kind)} to be supported"
      end
    end

    test "returns error for invalid mode" do
      col = %Column{name: :id, type: %Type{kind: :string}, mode: :invalid_mode}

      assert {:error, errors} = Column.validate(col)
      assert Enum.any?(errors, &(&1.type == :invalid_mode))
    end

    test "accepts all valid modes" do
      for mode <- [:nullable, :required, :repeated] do
        col = %Column{name: :id, type: %Type{kind: :string}, mode: mode}
        assert {:ok, _} = Column.validate(col), "Expected #{inspect(mode)} to be valid"
      end
    end

    test "collects multiple errors" do
      col = %Column{name: nil, type: nil, mode: :invalid}

      assert {:error, errors} = Column.validate(col)
      assert length(errors) >= 2
    end
  end
end
