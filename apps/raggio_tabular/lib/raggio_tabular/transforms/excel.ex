defmodule RaggioTabular.Transforms.Excel do
  @moduledoc """
  Excel-specific data transforms for cleaning values.
  """

  @doc """
  Convert Excel decimal string (e.g., "$1,234.56") to float.
  Handles currency symbols and thousand separators.
  """
  def excel_decimal(value) when is_binary(value) do
    cleaned =
      value
      |> String.replace(~r/[$€£¥]/, "")
      |> String.replace(",", "")
      |> String.trim()

    case Float.parse(cleaned) do
      {float, _} -> {:ok, float}
      :error -> {:error, "Invalid decimal: #{value}"}
    end
  end

  def excel_decimal(value) when is_number(value), do: {:ok, value / 1}
  def excel_decimal(nil), do: {:ok, nil}

  @doc """
  Convert Excel float ID (e.g., 123.0) to integer.
  Excel often stores IDs as floats.
  """
  def excel_integer(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> {:ok, trunc(float)}
      :error -> {:error, "Invalid integer: #{value}"}
    end
  end

  def excel_integer(value) when is_float(value), do: {:ok, trunc(value)}
  def excel_integer(value) when is_integer(value), do: {:ok, value}
  def excel_integer(nil), do: {:ok, nil}

  @doc """
  Convert Excel float to string ID (e.g., 123.0 -> "123").
  Useful for preserving leading zeros or converting numeric IDs.
  """
  def excel_string(value) when is_float(value) do
    {:ok, value |> trunc() |> Integer.to_string()}
  end

  def excel_string(value) when is_integer(value) do
    {:ok, Integer.to_string(value)}
  end

  def excel_string(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float |> trunc() |> Integer.to_string()}
      {float, ".0"} -> {:ok, float |> trunc() |> Integer.to_string()}
      _ -> {:ok, value}
    end
  end

  def excel_string(nil), do: {:ok, nil}

  @doc """
  Trim whitespace including non-breaking spaces.
  Excel often includes hidden whitespace characters.
  """
  def excel_trim(value) when is_binary(value) do
    trimmed =
      value
      |> String.replace(~r/[\x{00A0}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/u, " ")
      |> String.trim()

    {:ok, trimmed}
  end

  def excel_trim(value), do: {:ok, value}

  @doc """
  Parse Excel date serial number to Date.
  Excel stores dates as days since 1899-12-30 (with a bug for 1900-02-29).
  """
  def excel_date(value) when is_number(value) do
    base_date = ~D[1899-12-30]
    days = trunc(value)
    adjusted_days = if days > 60, do: days - 1, else: days
    {:ok, Date.add(base_date, adjusted_days)}
  end

  def excel_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "Invalid date: #{value}"}
    end
  end

  def excel_date(nil), do: {:ok, nil}

  @doc """
  Apply a transform function to a value, returning the value unchanged on error.
  """
  def safe_transform(value, transform_fn) do
    case transform_fn.(value) do
      {:ok, transformed} -> transformed
      {:error, _} -> value
    end
  end

  @doc """
  Apply multiple transforms in sequence.
  """
  def pipe_transforms(value, transforms) when is_list(transforms) do
    Enum.reduce_while(transforms, {:ok, value}, fn transform, {:ok, current_value} ->
      case transform.(current_value) do
        {:ok, new_value} -> {:cont, {:ok, new_value}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
