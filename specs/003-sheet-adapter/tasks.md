# Tasks: Sheet Adapter

**Input**: Design documents from `/specs/003-sheet-adapter/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/  

**Tests**: Not explicitly requested in spec - test tasks omitted (add if needed)

**Organization**: Tasks grouped by user story for independent implementation/testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Library**: `lib/raggio/tabular/` for implementation
- **Tests**: `test/raggio/tabular/` for tests
- **Legacy reference**: `old/data_schema/` for behavioral parity

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency configuration

- [x] T001 Add `nimble_csv` dependency to `mix.exs`
- [x] T002 Add `xlsx_reader` dependency to `mix.exs`
- [x] T003 Create base module `lib/raggio/tabular.ex` with module doc and placeholder public API
- [x] T004 Create directory structure `lib/raggio/tabular/` for submodules

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Error & Result Types

- [x] T005 [P] Create `Raggio.Tabular.Error` struct in `lib/raggio/tabular/error.ex` with fields: row, path, message, value, constraint (per research.md Decision 3)
- [x] T006 [P] Create `Raggio.Tabular.Result` struct in `lib/raggio/tabular/result.ex` with fields: valid_rows, invalid_rows, total_rows, matched_schema, metadata (per data-model.md ParseResult)

### Adapter Behaviour

- [x] T007 Create `Raggio.Tabular.Adapter` behaviour in `lib/raggio/tabular/adapter.ex` defining callbacks: sniff/1, list_sheets/2, stream_rows/2 (per contracts/adapter_contract.md)
- [x] T008 Create `Raggio.Tabular.SheetInfo` struct in `lib/raggio/tabular/sheet_info.ex` with fields: name, index (per contracts/adapter_contract.md)

### Source Types

- [x] T009 [P] Create `Raggio.Tabular.Source` struct in `lib/raggio/tabular/source.ex` with fields: type, location, hints (per data-model.md SheetSource)
- [x] T010 [P] Create `Raggio.Tabular.WorksheetSelector` module in `lib/raggio/tabular/worksheet_selector.ex` with by_name/by_index selectors (per data-model.md)

### SheetSchema Core Types (required by all user stories)

- [x] T011 Create `Raggio.Tabular.SheetSchema` struct in `lib/raggio/tabular/sheet_schema.ex` with fields: columns, header_mode, header_variants, row_filters (per data-model.md)
- [x] T012 Create `Raggio.Tabular.ColumnDef` struct in `lib/raggio/tabular/column_def.ex` with fields: field_name, header, at, required, type_schema (per data-model.md ColumnDefinition)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Developer parses tabular files into typed data (Priority: P1)

**Goal**: Parse CSV and XLSX files into typed rows using a SheetSchema mapping, cleanly separating valid and invalid rows with row-numbered errors

**Independent Test**: Provide small CSV and XLSX with same data, define SheetSchema, verify both produce equivalent typed output and row-level errors

### CSV Adapter Implementation

- [x] T013 [P] [US1] Create `Raggio.Tabular.Adapters.CSV` module in `lib/raggio/tabular/adapters/csv.ex` implementing Adapter behaviour
- [x] T014 [US1] Implement `sniff/1` in CSV adapter to detect CSV format by extension and content heuristics in `lib/raggio/tabular/adapters/csv.ex`
- [x] T015 [US1] Implement `list_sheets/2` in CSV adapter returning single synthetic sheet in `lib/raggio/tabular/adapters/csv.ex`
- [x] T016 [US1] Implement `stream_rows/2` in CSV adapter using `nimble_csv` for streaming parse in `lib/raggio/tabular/adapters/csv.ex`
- [x] T017 [US1] Add delimiter option support (comma, tab, semicolon) to CSV adapter in `lib/raggio/tabular/adapters/csv.ex` (FR-014, edge case: TSV support)
- [x] T018 [US1] Add encoding detection and BOM handling to CSV adapter in `lib/raggio/tabular/adapters/csv.ex` (FR-015)

### XLSX Adapter Implementation

- [x] T019 [P] [US1] Create `Raggio.Tabular.Adapters.XLSX` module in `lib/raggio/tabular/adapters/xlsx.ex` implementing Adapter behaviour
- [x] T020 [US1] Implement `sniff/1` in XLSX adapter to detect XLSX format by extension in `lib/raggio/tabular/adapters/xlsx.ex`
- [x] T021 [US1] Implement `list_sheets/2` in XLSX adapter returning worksheet list in `lib/raggio/tabular/adapters/xlsx.ex`
- [x] T022 [US1] Implement `stream_rows/2` in XLSX adapter using `xlsx_reader` for streaming in `lib/raggio/tabular/adapters/xlsx.ex`
- [x] T023 [US1] Add worksheet selector support (by name, by index) to XLSX adapter in `lib/raggio/tabular/adapters/xlsx.ex` (FR-005)
- [x] T024 [US1] Handle formula cells by reading computed values in XLSX adapter in `lib/raggio/tabular/adapters/xlsx.ex` (FR-017)

### SheetSchema Definition API

- [x] T025 [US1] Implement `define/1` function in `lib/raggio/tabular/sheet_schema.ex` for creating schema from field list (per contracts/tabular_api.md)
- [x] T026 [US1] Implement column resolution logic (by header name, by position, or both) in `lib/raggio/tabular/sheet_schema.ex` (FR-006)
- [x] T027 [US1] Implement required vs optional column handling in `lib/raggio/tabular/sheet_schema.ex` (FR-009)

### Header Detection & Row Parsing

- [x] T028 [US1] Create `Raggio.Tabular.Parser` module in `lib/raggio/tabular/parser.ex` for header detection and row parsing pipeline
- [x] T029 [US1] Implement header row detection (auto, present, absent modes) in `lib/raggio/tabular/parser.ex` (per legacy old/data_schema/sheet_schema/parser.ex)
- [x] T030 [US1] Implement column-to-field mapping after header resolution in `lib/raggio/tabular/parser.ex`
- [x] T031 [US1] Implement row parsing using `Raggio.Schema` validation for each cell in `lib/raggio/tabular/parser.ex`
- [x] T032 [US1] Implement row-numbered error accumulation in `lib/raggio/tabular/parser.ex` (FR-011, FR-012)

### Adapter Registry & Format Detection

- [x] T033 [US1] Create `Raggio.Tabular.Registry` module in `lib/raggio/tabular/registry.ex` for adapter registration and lookup
- [x] T034 [US1] Implement format detection by extension with adapter sniffing fallback in `lib/raggio/tabular/registry.ex`

### Public API Implementation

- [x] T035 [US1] Implement `parse_file/2` in `lib/raggio/tabular.ex` delegating to parser with auto-detected adapter (contracts/tabular_api.md)
- [x] T036 [US1] Implement `parse_file/3` with options (format, delimiter, encoding, worksheet, header) in `lib/raggio/tabular.ex` (contracts/tabular_api.md)
- [x] T037 [US1] Implement `list_sheets/1` in `lib/raggio/tabular.ex` for workbook introspection (contracts/tabular_api.md)

### Error Handling for Format Issues

- [x] T038 [US1] Implement actionable error messages for empty file, malformed CSV in `lib/raggio/tabular/adapters/csv.ex` (FR-013)
- [x] T039 [US1] Implement actionable error messages for unknown sheet, invalid XLSX in `lib/raggio/tabular/adapters/xlsx.ex` (FR-013)
- [x] T040 [US1] Implement duplicate header detection with actionable error in `lib/raggio/tabular/parser.ex` (edge case)
- [x] T041 [US1] Implement missing required header error with field list in `lib/raggio/tabular/parser.ex` (edge case)

### Blank/Ragged Row Handling

- [x] T042 [US1] Implement blank row skipping in row stream processing in `lib/raggio/tabular/parser.ex` (FR-016)
- [x] T043 [US1] Implement ragged row handling (pad short, ignore extra trailing) in `lib/raggio/tabular/parser.ex` (FR-016)

**Checkpoint**: User Story 1 complete - CSV and XLSX parsing works with typed results and row-numbered errors

---

## Phase 4: User Story 2 - Developer supports multiple input formats and header variants (Priority: P2)

**Goal**: Support header variants for alternate spellings and union schemas for multiple file format versions

**Independent Test**: Provide two CSV files with different headers but equivalent meaning, configure variants and union schema, verify both parse successfully

### Header Variants

- [x] T044 [US2] Implement `with_header_variants/2` in `lib/raggio/tabular/sheet_schema.ex` for header synonym configuration (contracts/tabular_api.md)
- [x] T045 [US2] Update header resolution in `lib/raggio/tabular/parser.ex` to check variants when primary header not found (FR-007)
- [x] T046 [US2] Support case-insensitive header matching option in `lib/raggio/tabular/parser.ex`

### Union Schema

- [x] T047 [US2] Create `Raggio.Tabular.Union` struct in `lib/raggio/tabular/union.ex` with fields: schemas, strategy (per data-model.md SchemaUnion)
- [x] T048 [US2] Implement `union/2` function in `lib/raggio/tabular/sheet_schema.ex` for creating union schemas (contracts/tabular_api.md)
- [x] T049 [US2] Implement `:first_match` strategy in union matching in `lib/raggio/tabular/parser.ex` (FR-008)
- [x] T050 [US2] Implement `:exact_one` strategy with ambiguous-match error in `lib/raggio/tabular/parser.ex` (FR-008, acceptance scenario 3)
- [x] T051 [US2] Track which schema variant matched in parse result in `lib/raggio/tabular/parser.ex`

**Checkpoint**: User Story 2 complete - header variants and union schemas work independently

---

## Phase 5: User Story 3 - Developer filters relevant rows and handles spreadsheet messiness (Priority: P2)

**Goal**: Support row range filtering, skip settings, and spreadsheet-oriented value transforms

**Independent Test**: Provide file with leading junk rows and messy values, configure filtering and transforms, verify only relevant rows processed with normalized values

### Row Filtering

- [x] T052 [US3] Add row_filters field support to SheetSchema in `lib/raggio/tabular/sheet_schema.ex` (skip_rows, row_range)
- [x] T053 [US3] Implement `skip_rows` option for skipping leading N rows in `lib/raggio/tabular/parser.ex` (FR-010)
- [x] T054 [US3] Implement `row_range` option for parsing only specified row range in `lib/raggio/tabular/parser.ex` (FR-010)
- [x] T055 [US3] Ensure row numbers in errors align to original file positions after filtering in `lib/raggio/tabular/parser.ex` (acceptance scenario 1)

### Value Transforms (Spreadsheet Normalization)

- [x] T056 [US3] Create `Raggio.Tabular.Transform` module in `lib/raggio/tabular/transform.ex` for opt-in value normalization (FR-018)
- [x] T057 [US3] Implement currency symbol stripping transform in `lib/raggio/tabular/transform.ex`
- [x] T058 [US3] Implement thousand separator removal transform in `lib/raggio/tabular/transform.ex`
- [x] T059 [US3] Implement whitespace trimming transform in `lib/raggio/tabular/transform.ex`
- [x] T060 [US3] Implement Excel date serial to Date conversion transform in `lib/raggio/tabular/transform.ex`
- [x] T061 [US3] Implement float-to-integer ID coercion transform in `lib/raggio/tabular/transform.ex`
- [x] T062 [US3] Integrate transform pipeline with parser in `lib/raggio/tabular/parser.ex`

**Checkpoint**: User Story 3 complete - row filtering and transforms work independently

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Performance, documentation, and final validation

### Performance & Streaming

- [x] T063 [P] Verify streaming behavior for 100k row file stays within memory bounds in CSV adapter (SC-003)
- [x] T064 [P] Verify streaming behavior for 100k row file stays within memory bounds in XLSX adapter (SC-003)
- [x] T065 Apply `:binary.copy/1` for cell values in CSV adapter to prevent binary reference leaks (research.md note)

### Legacy Parity Validation

- [x] T066 Review `old/data_schema/sheet_schema.ex` and validate API parity in `lib/raggio/tabular/sheet_schema.ex` (FR-020)
- [x] T067 Review `old/data_schema/sheet_schema/parser.ex` and validate parser behavior parity in `lib/raggio/tabular/parser.ex` (FR-020)
- [x] T068 Review `old/data_schema/adapters/tabular.ex` and validate error reporting parity in `lib/raggio/tabular/` (FR-020)

### Documentation

- [x] T069 [P] Add module docs to `lib/raggio/tabular.ex` with usage examples
- [x] T070 [P] Add module docs to `lib/raggio/tabular/sheet_schema.ex` with schema definition examples
- [x] T071 [P] Add typespecs to all public functions in `lib/raggio/tabular/` modules

### Quickstart Validation

- [x] T072 Create example script `examples/raggio_tabular/basic_csv_parse.exs` demonstrating CSV parsing
- [x] T073 Create example script `examples/raggio_tabular/xlsx_with_schema.exs` demonstrating XLSX parsing
- [x] T074 Validate quickstart scenarios from `specs/003-sheet-adapter/quickstart.md` work as documented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - core parsing capability
- **User Story 2 (Phase 4)**: Depends on Foundational - can run parallel to US1 if desired
- **User Story 3 (Phase 5)**: Depends on Foundational - can run parallel to US1/US2 if desired
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: MVP - basic CSV/XLSX parsing with typed results
- **User Story 2 (P2)**: Independent of US1 at code level, but builds on same foundation
- **User Story 3 (P2)**: Independent of US1/US2 at code level, but builds on same foundation

### Within Each User Story

- Adapters can be developed in parallel (CSV and XLSX are independent)
- SheetSchema API must precede Parser implementation
- Parser must precede public API implementation
- Error handling integrates throughout

### Parallel Opportunities

**Phase 2 Parallel Group**:
```
T005 (Error struct) || T006 (Result struct) || T009 (Source) || T010 (WorksheetSelector)
```

**Phase 3 Adapter Parallel Group**:
```
T013-T018 (CSV adapter) || T019-T024 (XLSX adapter)
```

**Phase 6 Parallel Group**:
```
T063 (CSV perf) || T064 (XLSX perf) || T069-T071 (docs)
```

---

## Parallel Example: User Story 1 Adapters

```bash
# Launch both adapter implementations in parallel:
Task: "Create Raggio.Tabular.Adapters.CSV module in lib/raggio/tabular/adapters/csv.ex"
Task: "Create Raggio.Tabular.Adapters.XLSX module in lib/raggio/tabular/adapters/xlsx.ex"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T012)
3. Complete Phase 3: User Story 1 (T013-T043)
4. **STOP and VALIDATE**: Test CSV and XLSX parsing independently
5. Deploy/demo if ready - core value delivered

### Incremental Delivery

1. Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Test CSV/XLSX -> Demo (MVP!)
3. Add User Story 2 -> Test header variants/unions -> Demo
4. Add User Story 3 -> Test filtering/transforms -> Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: CSV adapter (T013-T018) + CSV-specific error handling (T038)
   - Developer B: XLSX adapter (T019-T024) + XLSX-specific error handling (T039)
   - Developer C: SheetSchema API + Parser (T025-T032)
3. Integrate and complete public API (T033-T043)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Legacy code in `old/` is reference for behavioral parity, not copy-paste source
- `nimble_csv` requires explicit `:binary.copy/1` for values that outlive parse
- `xlsx_reader` chosen for pure-Elixir; can swap to `spreadsheet` if performance insufficient
