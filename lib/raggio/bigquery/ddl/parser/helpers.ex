defmodule Raggio.BigQuery.DDL.Parser.Helpers do
  @moduledoc """
  Common NimbleParsec combinators for BigQuery DDL parsing.
  """

  import NimbleParsec

  # Whitespace
  def whitespace do
    ascii_string([?\s, ?\t, ?\n, ?\r], min: 1)
  end

  def optional_whitespace do
    ascii_string([?\s, ?\t, ?\n, ?\r], min: 0)
  end

  # Keywords (case-insensitive)
  def keyword(word) do
    word
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(fn char ->
      lower = char + 32
      if char >= ?A and char <= ?Z, do: [char, lower], else: [char]
    end)
    |> Enum.reduce(empty(), fn chars, acc ->
      concat(acc, ascii_char(chars))
    end)
    |> ignore()
  end

  # Identifiers
  def identifier do
    ascii_char([?a..?z, ?A..?Z, ?_])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})
  end

  # Quoted identifier (backtick)
  def quoted_identifier do
    ignore(ascii_char([?`]))
    |> repeat(
      choice([
        ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?.]),
        # Escaped backtick
        string("``") |> replace(?`)
      ])
    )
    |> ignore(ascii_char([?`]))
    |> reduce({List, :to_string, []})
  end

  # Table reference (can be qualified)
  def table_reference do
    choice([
      quoted_identifier(),
      identifier()
    ])
  end

  # String literal (double-quoted)
  def string_literal do
    ignore(ascii_char([?"]))
    |> repeat(
      choice([
        string("\\\"") |> replace(?"),
        string("\\\\") |> replace(?\\),
        ascii_char([{:not, ?"}])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})
  end

  # Integer
  def integer_literal do
    optional(ascii_char([?-, ?+]))
    |> ascii_string([?0..?9], min: 1)
    |> reduce({__MODULE__, :parse_integer, []})
  end

  def parse_integer(parts) do
    parts
    |> Enum.join()
    |> String.to_integer()
  end

  # Comma-separated list
  def comma_sep(parser) do
    parser
    |> repeat(
      ignore(optional_whitespace())
      |> ignore(ascii_char([?,]))
      |> ignore(optional_whitespace())
      |> concat(parser)
    )
    |> wrap()
  end
end
