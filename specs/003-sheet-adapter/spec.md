# Feature Specification: Sheet Adapter

**Feature Branch**: `003-sheet-adapter`  
**Created**: 2026-01-14  
**Status**: Draft  
**Input**: User description: "can we adapt what is in /old folder and create a sheet adapter (for csv, excel, and other similar formats)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer parses tabular files into typed data (Priority: P1)

A developer receives tabular files from business users and needs a single, consistent way to parse them (CSV and Excel) into typed rows using a declarative mapping. They use the Sheet adapter to read the file, apply a SheetSchema mapping, and get a result that cleanly separates valid and invalid rows.

**Why this priority**: This is the core value: turning real-world spreadsheet data into structured, validated data with actionable error reporting.

**Independent Test**: Can be fully tested by providing a small CSV and a small XLSX representing the same table, defining a SheetSchema mapping, running the parser for each, and verifying that both produce equivalent typed output and row-level errors.

**Acceptance Scenarios**:

1. **Given** a CSV file with headers and data rows, **When** a developer parses it with a SheetSchema mapping, **Then** the system returns valid rows as typed data and invalid rows with row numbers and per-field error details
2. **Given** an XLSX file containing a table on the first worksheet, **When** a developer parses it with the same SheetSchema mapping, **Then** the system returns the same logical output structure and error reporting as CSV
3. **Given** a file with structural issues (missing required headers, inconsistent row width), **When** a developer attempts to parse, **Then** the system fails early with a clear format error that explains what needs to be fixed

---

### User Story 2 - Developer supports multiple input formats and header variants (Priority: P2)

A developer needs to support multiple versions of incoming spreadsheets where column names vary (e.g., "ID" vs "User ID"), or different file versions have different column sets. They define header variants and/or union schemas so that parsing succeeds as long as the input matches one of the expected variants.

**Why this priority**: Real spreadsheets evolve. Supporting controlled variance avoids brittle import pipelines.

**Independent Test**: Can be fully tested by providing two different CSV/XLSX files with different headers but equivalent meaning, configuring header variants and a union schema, and verifying both parse successfully to the same normalized field names.

**Acceptance Scenarios**:

1. **Given** two spreadsheet variants with different header naming, **When** the developer configures header variants, **Then** the system maps variant headers into a single canonical schema and parses successfully
2. **Given** two different format versions with different sets of fields, **When** the developer configures a union of SheetSchemas, **Then** the system parses the input using the matching schema and reports which variant matched
3. **Given** an input that matches multiple schemas and the matching strategy requires uniqueness, **When** parsing occurs, **Then** the system returns an explicit ambiguous-match error

---

### User Story 3 - Developer filters relevant rows and handles common spreadsheet messiness (Priority: P2)

A developer receives spreadsheets with leading junk rows (titles, notes), repeated headers, and irrelevant ranges. They configure row range and skip settings, and optionally apply common spreadsheet transforms so that the parser yields clean, typed results.

**Why this priority**: Spreadsheet inputs frequently contain non-data rows and inconsistent value formatting; enabling controlled cleanup reduces manual preprocessing.

**Independent Test**: Can be fully tested by providing a file with extra leading rows and messy value formats, configuring row filtering and transforms, and verifying that only relevant rows are processed and values are normalized.

**Acceptance Scenarios**:

1. **Given** a spreadsheet where the first N rows are non-data, **When** the developer configures row skipping, **Then** parsing ignores those rows and row numbers in errors still align to the original file
2. **Given** a spreadsheet where only a subset of rows are relevant, **When** the developer configures a row range, **Then** only rows in that range are processed
3. **Given** messy spreadsheet values (currency symbols, thousand separators, IDs represented as floats/strings), **When** the developer applies spreadsheet-oriented transforms, **Then** parsed output matches expected normalized values or yields precise errors

---

### Edge Cases

- When the input file is empty, the system returns a format error with a clear message
- When CSV uses a delimiter other than comma (e.g., tab or semicolon), the system detects or accepts an explicit delimiter and parses correctly
- When CSV contains quoted fields with embedded delimiters or newlines, the system parses records correctly or returns a precise format error
- When the file has duplicate headers, the system returns an actionable error describing which headers are duplicated and how to disambiguate
- When a required header is missing, the system returns a header-not-found error listing missing fields
- When optional columns are missing, the system still parses successfully and omits those fields (or marks them absent) without failing
- When an XLSX workbook has multiple sheets, the system can list sheets and select which to parse
- When an XLSX cell contains a formula, the system can read computed values (and treats formula errors as invalid cells with clear error details)
- When values are ambiguous due to locale (dates and decimal separators), the system uses a consistent default and allows explicit override; ambiguous values are surfaced as errors rather than silently mis-parsed

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Sheet adapter that reads tabular files into a consistent row representation that downstream parsing can consume
- **FR-002**: System MUST support CSV and XLSX as first-class input formats
- **FR-003**: System SHOULD treat TSV as a supported CSV variant (tab-delimited) without requiring a separate user-facing integration
- **FR-004**: System MUST define a clear extension point so additional "sheet-like" formats can be supported in future without changing user code beyond configuration (e.g., adding a new adapter implementation)
- **FR-005**: System MUST allow selecting the sheet/worksheet to parse for multi-sheet workbooks by name and by index
- **FR-006**: System MUST support header-based parsing where columns can be resolved by header name, position, or both
- **FR-007**: System MUST support header variants so that multiple header spellings/cases/synonyms can map to the same canonical field
- **FR-008**: System MUST support union schemas for handling multiple file format versions, with a configurable match strategy (first match vs require exactly one)
- **FR-009**: System MUST support optional columns that may be absent in an input without causing overall parsing failure
- **FR-010**: System MUST support row filtering controls, including skipping a number of rows and parsing only specified row ranges
- **FR-011**: System MUST return row-level parsing results that separate valid rows from invalid rows
- **FR-012**: System MUST include row numbers in errors so users can locate issues in the original file
- **FR-013**: System MUST provide actionable, user-oriented error messages for common format failures (empty file, malformed CSV, missing headers, unknown sheet name)
- **FR-014**: System MUST handle common CSV delimiter and quoting rules, including quoted fields containing delimiters and line breaks
- **FR-015**: System MUST handle common character encodings for CSV inputs, including UTF-8 with or without BOM, and must fail with a clear error when encoding cannot be interpreted
- **FR-016**: System MUST define deterministic default behavior for blank and ragged rows: completely blank rows are skipped; rows with fewer cells than expected are padded with empty values; rows with extra trailing cells ignore the extra cells unless explicitly configured to error
- **FR-017**: System MUST provide a consistent strategy for reading Excel values, including computed values for formulas and explicit handling of spreadsheet error values (e.g., missing/invalid)
- **FR-018**: System MUST support spreadsheet-oriented value normalization consistent with legacy behavior (e.g., currency-like values, float IDs, whitespace trimming, Excel date serials) via an explicit, opt-in transform mechanism
- **FR-019**: System MUST be able to process large inputs without requiring the entire file to fit in memory at once
- **FR-020**: System MUST maintain behavioral parity with the legacy tabular parsing pipeline in `old/` for core capabilities: header detection, optional columns, union schema matching, row range filtering, and row-numbered errors

### Key Entities *(include if feature involves data)*

- **Sheet Adapter**: A pluggable component that reads a file in a supported tabular format and yields rows plus metadata (e.g., available sheets). Provides a consistent interface across CSV, XLSX, and future formats.
- **Sheet Source**: The user-provided input representing a tabular file (e.g., a file path or in-memory content) along with optional parsing hints (delimiter, encoding, worksheet selection).
- **Workbook**: A multi-sheet tabular container (e.g., an Excel file) with addressable worksheets.
- **SheetSchema**: A declarative mapping that describes expected columns, how to resolve them (by header/position), which are optional, and how to parse values into typed fields.
- **Parse Result**: The structured output of a parse operation, including valid rows, invalid rows with detailed errors, and useful metadata (such as total rows processed and which schema variant matched).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can parse both a CSV and an XLSX version of the same dataset and obtain equivalent typed outputs for at least 99% of rows (excluding known format-induced differences like empty trailing columns)
- **SC-002**: When parsing fails due to format issues, the system reports actionable errors that allow a user to correct the file without reading source code (validated by a reviewer using only the error messages)
- **SC-003**: For a dataset of 100,000 rows, the system completes parsing within 10 seconds on a typical developer laptop and does not exceed a reasonable memory footprint for the file size
- **SC-004**: For any invalid row, the system reports the correct original row number and at least one precise field-level error message

## Assumptions & Constraints

### Assumptions

- The primary users are developers building ingestion pipelines for spreadsheet-based inputs from business users
- CSV and XLSX cover the vast majority of real-world spreadsheet imports; TSV is a common export variant
- Parity with the existing legacy sheet parsing behavior is more important than adding many niche formats up front

### Constraints

- The feature MUST remain format-agnostic at the API level: users configure what they need, and the adapter layer handles file-specific details
- Error reporting MUST be consistent across formats so users can build uniform tooling around it

## Out of Scope

- Live integrations (e.g., directly reading a remote Google Sheet without exporting a file)
- Supporting niche formats without clear demand (e.g., fixed-width) in the initial release
- Legacy XLS support unless required by demonstrated user demand
