# Capability: tabular

Parser-agnostic ingestion of sheet-like files (CSV, XLSX, TSV) into typed,
validated rows via a user-supplied parser behaviour and a declarative
`SheetSchema`.

## ADDED Requirements

### Requirement: Parser Behaviour Contract

The system SHALL define a `Raggio.Tabular.Parser` behaviour as the single
extension point for all tabular formats. It SHALL declare exactly two callbacks:
`stream_rows/2` returning `{:ok, Enumerable.t({pos_integer(), [term()]})} |
{:error, map()}`, and `sheet_names/1` returning `{:ok, [String.t()]} | {:error,
map()}`. Implementations MUST stream lazily (they MUST NOT require loading all
rows into memory), MUST emit `{row_number, cells}` tuples where `row_number` is
1-based and aligned to the original file, and MUST NOT be bundled by the core
library — users provide them.

#### Scenario: CSV parser implements the behaviour
- **WHEN** a module declares `@behaviour Raggio.Tabular.Parser` and implements
  `stream_rows/2` and `sheet_names/1`
- **THEN** it can be supplied to `Raggio.Tabular` as a valid parser and its
  streamed `{row_number, cells}` tuples are consumed by the row-parsing pipeline

#### Scenario: Single-sheet format reports a default sheet
- **WHEN** `sheet_names/1` is called on a single-sheet source such as CSV
- **THEN** the parser returns `{:ok, ["default"]}`

#### Scenario: Streaming is lazy for large inputs
- **WHEN** `stream_rows/2` is invoked on a large file
- **THEN** rows are produced lazily as an `Enumerable` without loading the whole
  file into memory

### Requirement: Explicit Parser Selection

The system SHALL require the parser module to be supplied explicitly at the call
site via the `parser:` option on `Raggio.Tabular.parse/3` and
`Raggio.Tabular.list_sheets/2`. There SHALL be no implicit registration,
auto-detection, or config-based resolution. When the `parser:` option is absent,
the system SHALL return `{:error, %{type: :missing_parser}}`.

#### Scenario: Parse with explicit parser succeeds
- **WHEN** `Raggio.Tabular.parse("data.csv", schema, parser: MyApp.CSVParser)`
  is called
- **THEN** the system invokes `MyApp.CSVParser.stream_rows/2` and returns
  `{:ok, result}`

#### Scenario: Missing parser option is rejected
- **WHEN** `Raggio.Tabular.parse/3` is called without a `parser:` option
- **THEN** the system returns `{:error, %{type: :missing_parser}}`

### Requirement: Source Abstraction Across Formats

The system SHALL parse CSV and XLSX through the same API and SHALL support TSV as
a CSV variant via delimiter configuration in the user's parser. The public
`parse/3` output structure and error reporting SHALL be consistent regardless of
the underlying format, so equivalent CSV and XLSX inputs yield equivalent
logical results.

#### Scenario: Equivalent CSV and XLSX produce equivalent output
- **WHEN** a CSV file and an XLSX file representing the same table are parsed
  with the same `SheetSchema`
- **THEN** both produce equivalent typed valid rows and equivalent row-level
  error reporting

#### Scenario: TSV via delimiter configuration
- **WHEN** a tab-delimited file is parsed with a CSV-style parser configured for
  a tab delimiter
- **THEN** records are parsed correctly through the same behaviour

### Requirement: Worksheet Selection

The system SHALL allow selecting the worksheet to parse for multi-sheet
workbooks by name via the `sheet:` option, which is passed through to the
parser's `stream_rows/2`. It SHALL expose available sheet names through
`list_sheets/2`. Requesting a sheet that does not exist SHALL return
`{:error, %{type: :sheet_not_found, ...}}` including the requested and available
sheet names.

#### Scenario: List sheets of a workbook
- **WHEN** `Raggio.Tabular.list_sheets("workbook.xlsx", parser: MyApp.XLSXParser)`
  is called
- **THEN** the system returns `{:ok, sheet_names}` in workbook order

#### Scenario: Parse a named sheet
- **WHEN** `parse/3` is called with `sheet: "Data"` on a multi-sheet workbook
- **THEN** only the "Data" worksheet is parsed

#### Scenario: Unknown sheet name errors
- **WHEN** `parse/3` requests a sheet name that does not exist in the workbook
- **THEN** the system returns `{:error, %{type: :sheet_not_found, details:
  %{requested: name, available: [...]}}}`

### Requirement: Schema-Driven Column Definitions

The system SHALL support a declarative `SheetSchema` composed of `ColumnDef`
entries. Each `ColumnDef` SHALL map one output `field_name` (atom) and MAY
specify an expected `header`, a fixed 0-based position `at`, a `type_schema`
(a `Raggio.Schema` used to validate the cell), and a `required` flag (default
true). Column resolution SHALL follow the order: fixed position `at`, then
header text (case-insensitive), then header variants; if unresolved and
`required: false` the column SHALL be skipped without failing the parse.

#### Scenario: Resolve a column by header
- **WHEN** a `ColumnDef` specifies `header: "Email"` and the file has an "email"
  header column
- **THEN** the column resolves case-insensitively to that field

#### Scenario: Optional column missing does not fail parsing
- **WHEN** a `ColumnDef` with `required: false` has no matching header or
  position in the input
- **THEN** parsing succeeds and that field is omitted from output rows

#### Scenario: Missing required header errors
- **WHEN** a required column cannot be resolved by position, header, or variant
- **THEN** the system returns `{:error, %{type: :missing_headers, missing:
  [...], required: [...]}}`

### Requirement: Header Variants

The system SHALL support header variants so multiple header spellings, cases, or
synonyms map to the same canonical field, configured via
`SheetSchema.with_header_variants/2`. Variant lookup SHALL be consulted when the
primary header is not found.

#### Scenario: Variant header maps to canonical field
- **WHEN** header variants `%{"User ID" => :id, "user_id" => :id}` are
  configured and the file header is "User ID"
- **THEN** the column resolves to the `:id` field

### Requirement: Union Schemas For Format Versions

The system SHALL support a `Raggio.Tabular.Union` of multiple `SheetSchema`s
with a configurable match strategy. `:first_match` SHALL use the first schema
whose required headers match; `:exact_one` SHALL require exactly one matching
schema and SHALL error otherwise. The matched schema SHALL be reported in
`Result.matched_schema`.

#### Scenario: First-match selects the earliest matching schema
- **WHEN** a union with `strategy: :first_match` is parsed and the input matches
  the first schema's required headers
- **THEN** that schema is used and `result.matched_schema` identifies it

#### Scenario: Exact-one rejects ambiguous input
- **WHEN** a union with `strategy: :exact_one` is parsed and two schemas match
- **THEN** the system returns `{:error, %{type: :ambiguous_match, count: 2}}`

#### Scenario: No schema matches
- **WHEN** a union is parsed and no schema's required headers match
- **THEN** the system returns `{:error, %{type: :no_match}}`

### Requirement: Row Filtering

The system SHALL support row filtering via `SheetSchema.with_row_filters/2`,
including `skip_rows` (skip the first N rows) and `row_range` (process only rows
within a range). Row numbers reported in errors SHALL continue to align to the
original file positions after filtering.

#### Scenario: Skip leading junk rows
- **WHEN** `skip_rows: 3` is configured and the file begins with 3 non-data rows
- **THEN** those rows are ignored and parsing begins after them

#### Scenario: Row range limits processing
- **WHEN** a `row_range` is configured
- **THEN** only rows within that range are processed

#### Scenario: Error row numbers survive filtering
- **WHEN** filtering removes leading rows and a later row is invalid
- **THEN** the reported `row` matches that row's original position in the file

### Requirement: Value Transforms

The system SHALL support opt-in, spreadsheet-oriented value transforms applied
before type validation, configured via `SheetSchema.with_transforms/2`. It SHALL
provide at least `:trim`, `:strip_currency`, `:normalize_decimal` (thousand
separators), `:excel_date` (serial to Date), and `:float_to_int` (e.g., "1.0" to
"1" for IDs).

#### Scenario: Currency and separators normalized
- **WHEN** a cell value `"$1,234.50"` is parsed with `:strip_currency` and
  `:normalize_decimal` transforms
- **THEN** the value is normalized before type validation

#### Scenario: Float ID coerced to integer form
- **WHEN** a cell value `"1.0"` is parsed with the `:float_to_int` transform for
  an integer field
- **THEN** the value is coerced to `"1"` before validation

### Requirement: Parse Result And Row-Level Errors

The system SHALL return a `Raggio.Tabular.Result` separating `valid_rows` (typed
maps) from `invalid_rows` (errors), along with `row_count` and `matched_schema`.
Partial-row failures SHALL be represented in `invalid_rows`, not as an overall
`{:error, ...}`. Each row error SHALL be a `Raggio.Tabular.Error` struct with
`row` (1-based, original), `path` (field), `message`, `value`, and optional
`constraint`.

#### Scenario: Valid and invalid rows are separated
- **WHEN** a file contains both valid and invalid rows
- **THEN** the result returns valid typed rows in `valid_rows` and per-field
  errors in `invalid_rows`, and the overall return is `{:ok, result}`

#### Scenario: Row error carries actionable detail
- **WHEN** a cell fails validation on row 42 for the `:email` field
- **THEN** the corresponding `Error` has `row: 42`, `path: :email`, a human
  message, the offending `value`, and an optional `constraint`

### Requirement: Deterministic Blank And Ragged Row Handling

The system SHALL apply deterministic defaults: completely blank rows are skipped
and not counted; rows with fewer cells than expected are padded with empty
values; rows with extra trailing cells ignore the extras unless explicitly
configured to error. Header matching SHALL be case-insensitive and row numbering
SHALL always be 1-based from the original file.

#### Scenario: Blank row skipped
- **WHEN** a completely blank row appears in the input
- **THEN** it is skipped and not included in `row_count`

#### Scenario: Short row padded
- **WHEN** a row has fewer cells than the schema expects
- **THEN** missing trailing cells are treated as empty values

#### Scenario: Extra trailing cells ignored
- **WHEN** a row has more cells than the schema expects and no error is
  configured
- **THEN** the extra trailing cells are ignored

### Requirement: Format-Level Error Model

The system SHALL return `{:error, map}` for inputs that cannot be read or
structurally validated, with each map containing at least a `type` atom and a
`message`. Recognized types SHALL include `:file_not_found`, `:invalid_format`,
`:sheet_not_found`, `:missing_headers`, `:no_match`, `:ambiguous_match`, and
`:missing_parser`. Errors raised by the user's parser SHALL be wrapped into this
consistent shape.

#### Scenario: Unreadable file returns a format error
- **WHEN** `parse/3` is called on a path that does not exist
- **THEN** the system returns `{:error, %{type: :file_not_found, message: ...}}`

#### Scenario: Empty input returns a clear format error
- **WHEN** the input file is empty
- **THEN** the system returns a format error with a clear message

#### Scenario: Parser errors are wrapped consistently
- **WHEN** the supplied parser returns or raises an error from `stream_rows/2`
- **THEN** the system surfaces it as `{:error, map}` with a `type` and `message`
