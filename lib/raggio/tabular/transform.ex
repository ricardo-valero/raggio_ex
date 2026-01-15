defmodule Raggio.Tabular.Transform do
  @moduledoc """
  Spreadsheet-oriented value transforms for common data cleanup.

  Transforms are opt-in and applied before type validation.
  Use these to normalize messy spreadsheet data.

  ## Example

      transforms = [
        Transform.trim_whitespace(),
        Transform.strip_currency(),
        Transform.remove_thousand_separators()
      ]

      schema = SheetSchema.define([...])
        |> SheetSchema.with_transforms(transforms)

  """

  @type transform :: (String.t() -> String.t())

  @spec trim_whitespace() :: transform()
  def trim_whitespace do
    fn
      value when is_binary(value) -> String.trim(value)
      value -> value
    end
  end

  @spec strip_currency(list(String.t())) :: transform()
  def strip_currency(symbols \\ ["$", "€", "£", "¥", "₹"]) do
    pattern = symbols |> Enum.map(&Regex.escape/1) |> Enum.join("|")
    regex = Regex.compile!("(#{pattern})")

    fn
      value when is_binary(value) -> Regex.replace(regex, value, "")
      value -> value
    end
  end

  @spec remove_thousand_separators(String.t()) :: transform()
  def remove_thousand_separators(separator \\ ",") do
    fn
      value when is_binary(value) ->
        if Regex.match?(~r/^\d{1,3}(#{Regex.escape(separator)}\d{3})+(\.\d+)?$/, value) do
          String.replace(value, separator, "")
        else
          value
        end

      value ->
        value
    end
  end

  @spec excel_date_serial_to_date() :: transform()
  def excel_date_serial_to_date do
    fn
      value when is_binary(value) ->
        case Integer.parse(value) do
          {serial, ""} when serial > 0 ->
            Date.add(~D[1899-12-30], serial) |> Date.to_iso8601()

          _ ->
            value
        end

      value when is_integer(value) and value > 0 ->
        Date.add(~D[1899-12-30], value) |> Date.to_iso8601()

      value ->
        value
    end
  end

  @spec float_to_integer_id() :: transform()
  def float_to_integer_id do
    fn
      value when is_binary(value) ->
        case Float.parse(value) do
          {float_val, ""} ->
            int_val = round(float_val)

            if float_val == int_val * 1.0 do
              Integer.to_string(int_val)
            else
              value
            end

          _ ->
            value
        end

      value when is_float(value) ->
        int_val = round(value)

        if value == int_val * 1.0 do
          Integer.to_string(int_val)
        else
          Float.to_string(value)
        end

      value ->
        value
    end
  end

  @spec normalize_boolean() :: transform()
  def normalize_boolean do
    fn
      value when is_binary(value) ->
        case String.downcase(String.trim(value)) do
          v when v in ["true", "yes", "1", "y", "t"] -> "true"
          v when v in ["false", "no", "0", "n", "f"] -> "false"
          _ -> value
        end

      value ->
        value
    end
  end

  @spec compose([transform()]) :: transform()
  def compose(transforms) when is_list(transforms) do
    fn value ->
      Enum.reduce(transforms, value, fn transform, acc -> transform.(acc) end)
    end
  end

  @spec run(any(), transform() | [transform()]) :: any()
  def run(value, transform) when is_function(transform, 1) do
    transform.(value)
  end

  def run(value, transforms) when is_list(transforms) do
    run(value, compose(transforms))
  end
end
