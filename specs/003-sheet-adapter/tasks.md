# Tasks: Sheet Adapter (Parser-Agnostic)

**Input**: Design documents from `/specs/003-sheet-adapter/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/  

**Architecture**: Parser-agnostic - library defines behaviours, users provide implementations. No bundled parsing dependencies.

**Tests**: Not explicitly requested in spec - test tasks omitted (add if needed)

**Organization**: Tasks grouped by user story for independent implementation/testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Library**: `lib/raggio/tabular/` for core implementation (behaviours + parsing logic)
- **Examples**: `examples/tabular/` for reference parser implementations
- **Tests**: `test/raggio/tabular/` for tests
- **Legacy reference**: `old/data_schema/` for behavioral parity

---

## Phase 1: Setup (Refactor to Parser-Agnostic)

**Purpose**: Restructure for parser-agnostic architecture - remove bundled parsers, establish behaviour-based extension

- [x] T001 Move `nimble_csv` dependency to `:dev` only in `mix.exs` (was production dep)
- [x] T002 Move `xlsx_reader` dependency to `:dev` only in `mix.exs` (was production dep)
- [x] T003 Create `examples/tabular/` directory for reference parser implementations
- [x] T004 Move `lib/raggio/tabular/adapters/csv.ex` to `examples/tabular/csv_parser.ex` (preserve as example)
- [x] T005 Move `lib/raggio/tabular/adapters/xlsx.ex` to `examples/tabular/xlsx_parser.ex` (preserve as example)
- [x] T006 Delete `lib/raggio/tabular/adapters/` directory after migration
- [x] T007 Delete `lib/raggio/tabular/registry.ex` (no longer needed with explicit parser selection)

---

## Phase 2: Foundational (Core Behaviour & Types)

**Purpose**: Define the `Raggio.Tabular.Parser` behaviour and core types that MUST be complete before ANY user story

**CRITICAL**: No user story work can begin until this phase is complete

### Parser Behaviour (NEW)

- [x] T008 Create `Raggio.Tabular.Parser` behaviour in `lib/raggio/tabular/parser.ex` with callbacks: `stream_rows/2`, `sheet_names/1` (per contracts/adapter_contract.md)
- [x] T009 Add @callback typespecs to `lib/raggio/tabular/parser.ex`: `stream_rows(source, opts) :: {:ok, Enumerable.t({pos_integer(), [term()]})} | {:error, map()}`
- [x] T010 Add @callback typespecs to `lib/raggio/tabular/parser.ex`: `sheet_names(source) :: {:ok, [String.t()]} | {:error, map()}`
- [x] T011 Add module documentation to `lib/raggio/tabular/parser.ex` explaining behaviour contract and implementation requirements

### Row Parsing Logic (Renamed)

- [x] T012 Rename `lib/raggio/tabular/parser.ex` (existing parsing logic) to `lib/raggio/tabular/row_parser.ex` to avoid conflict with behaviour module
- [x] T013 Update all internal references from `Raggio.Tabular.Parser` (old) to `Raggio.Tabular.RowParser` in `lib/raggio/tabular/`

### Error & Result Types (Existing - Verify)

- [x] T014 [P] Verify `Raggio.Tabular.Error` struct in `lib/raggio/tabular/error.ex` has fields: row, path, message, value, constraint
- [x] T015 [P] Verify `Raggio.Tabular.Result` struct in `lib/raggio/tabular/result.ex` has fields: valid_rows, invalid_rows, row_count, matched_schema

### SheetSchema Core Types (Existing - Verify)

- [x] T016 [P] Verify `Raggio.Tabular.SheetSchema` struct in `lib/raggio/tabular/sheet_schema.ex` has fields: columns, header_mode, header_variants, row_filters, transforms
- [x] T017 [P] Verify `Raggio.Tabular.ColumnDef` struct in `lib/raggio/tabular/column_def.ex` has fields: field_name, header, at, required, type_schema

**Checkpoint**: Foundation ready - Parser behaviour defined, row parsing logic renamed, core types verified

---

## Phase 3: User Story 1 - Developer parses tabular files into typed data (Priority: P1)

**Goal**: Parse CSV and XLSX files into typed rows using a SheetSchema mapping, cleanly separating valid and invalid rows with row-numbered errors. **Users provide parser implementations via the behaviour.**

**Independent Test**: Provide small CSV and XLSX with same data, define SheetSchema, implement example parsers, verify both produce equivalent typed output and row-level errors

### Public API Update (Explicit Parser Selection)

- [x] T018 [US1] Update `Raggio.Tabular.parse/3` in `lib/raggio/tabular.ex` to REQUIRE `parser:` option (no auto-detection)
- [x] T019 [US1] Add validation in `lib/raggio/tabular.ex` that returns `{:error, %{type: :missing_parser}}` if `parser:` option not provided
- [x] T020 [US1] Update `Raggio.Tabular.list_sheets/2` in `lib/raggio/tabular.ex` to REQUIRE `parser:` option
- [x] T021 [US1] Remove `parse_file/2` (without opts) from `lib/raggio/tabular.ex` - all calls must specify parser

### Integration with Parser Behaviour

- [x] T022 [US1] Update `lib/raggio/tabular.ex` to call `parser.stream_rows(source, opts)` from provided parser module
- [x] T023 [US1] Update `lib/raggio/tabular.ex` to call `parser.sheet_names(source)` from provided parser module
- [x] T024 [US1] Pass `sheet:` option through to parser's `stream_rows/2` in `lib/raggio/tabular.ex`
- [x] T025 [US1] Handle parser errors gracefully in `lib/raggio/tabular.ex` - wrap in consistent error format

### Row Parsing Pipeline (Using Behaviour Output)

- [x] T026 [US1] Update `lib/raggio/tabular/row_parser.ex` to accept stream from any Parser behaviour implementation
- [x] T027 [US1] Ensure row_parser correctly handles `{row_number, cells}` tuple format from parsers in `lib/raggio/tabular/row_parser.ex`
- [x] T028 [US1] Verify header detection (auto, present, absent modes) works with behaviour-provided streams in `lib/raggio/tabular/row_parser.ex`
- [x] T029 [US1] Verify row-numbered error accumulation uses original row numbers from parser in `lib/raggio/tabular/row_parser.ex`

### Example CSV Parser (Reference Implementation)

- [x] T030 [P] [US1] Update `examples/tabular/csv_parser.ex` to implement `Raggio.Tabular.Parser` behaviour
- [x] T031 [US1] Implement `sheet_names/1` in `examples/tabular/csv_parser.ex` returning `{:ok, ["default"]}`
- [x] T032 [US1] Implement `stream_rows/2` in `examples/tabular/csv_parser.ex` using NimbleCSV with streaming
- [x] T033 [US1] Add delimiter option support (comma, tab, semicolon) to `examples/tabular/csv_parser.ex`
- [x] T034 [US1] Add error handling for file not found, read errors in `examples/tabular/csv_parser.ex`

### Example XLSX Parser (Reference Implementation)

- [x] T035 [P] [US1] Update `examples/tabular/xlsx_parser.ex` to implement `Raggio.Tabular.Parser` behaviour
- [x] T036 [US1] Implement `sheet_names/1` in `examples/tabular/xlsx_parser.ex` using XlsxReader
- [x] T037 [US1] Implement `stream_rows/2` in `examples/tabular/xlsx_parser.ex` using XlsxReader
- [x] T038 [US1] Add sheet selection support (by name via `sheet:` option) in `examples/tabular/xlsx_parser.ex`
- [x] T039 [US1] Add error handling for file not found, invalid format, sheet not found in `examples/tabular/xlsx_parser.ex`

### Example Documentation

- [x] T040 [P] [US1] Create `examples/tabular/README.md` with setup instructions (adding deps, implementing behaviour)
- [x] T041 [US1] Add usage examples to `examples/tabular/README.md` showing explicit parser selection

### Error Handling for Format Issues

- [x] T042 [US1] Verify actionable error messages for missing required headers in `lib/raggio/tabular/row_parser.ex` (FR-013)
- [x] T043 [US1] Verify duplicate header detection with actionable error in `lib/raggio/tabular/row_parser.ex`
- [x] T044 [US1] Verify blank row skipping works with any parser output in `lib/raggio/tabular/row_parser.ex` (FR-016)
- [x] T045 [US1] Verify ragged row handling (pad short, ignore extra trailing) in `lib/raggio/tabular/row_parser.ex` (FR-016)

**Checkpoint**: User Story 1 complete - Users can implement Parser behaviour and parse CSV/XLSX to typed results with row-numbered errors

---

## Phase 4: User Story 2 - Developer supports multiple input formats and header variants (Priority: P2)

**Goal**: Support header variants for alternate spellings and union schemas for multiple file format versions

**Independent Test**: Provide two CSV files with different headers but equivalent meaning, configure variants and union schema, verify both parse successfully

### Header Variants

- [x] T046 [US2] Verify `with_header_variants/2` exists in `lib/raggio/tabular/sheet_schema.ex` for header synonym configuration
- [x] T047 [US2] Verify header resolution in `lib/raggio/tabular/row_parser.ex` checks variants when primary header not found (FR-007)
- [x] T048 [US2] Verify case-insensitive header matching in `lib/raggio/tabular/row_parser.ex`

### Union Schema

- [x] T049 [US2] Verify `Raggio.Tabular.Union` struct in `lib/raggio/tabular/union.ex` has fields: schemas, strategy
- [x] T050 [US2] Verify `Union.new/2` function in `lib/raggio/tabular/union.ex` creates union schemas
- [x] T051 [US2] Verify `:first_match` strategy in union matching in `lib/raggio/tabular/row_parser.ex` (FR-008)
- [x] T052 [US2] Verify `:exact_one` strategy with ambiguous-match error in `lib/raggio/tabular/row_parser.ex` (FR-008)
- [x] T053 [US2] Verify matched schema variant tracked in parse result in `lib/raggio/tabular/row_parser.ex`

**Checkpoint**: User Story 2 complete - header variants and union schemas work independently

---

## Phase 5: User Story 3 - Developer filters relevant rows and handles spreadsheet messiness (Priority: P2)

**Goal**: Support row range filtering, skip settings, and spreadsheet-oriented value transforms

**Independent Test**: Provide file with leading junk rows and messy values, configure filtering and transforms, verify only relevant rows processed with normalized values

### Row Filtering

- [x] T054 [US3] Verify row_filters field support in SheetSchema in `lib/raggio/tabular/sheet_schema.ex` (skip_rows, row_range)
- [x] T055 [US3] Verify `skip_rows` option skips leading N rows in `lib/raggio/tabular/row_parser.ex` (FR-010)
- [x] T056 [US3] Verify `row_range` option parses only specified row range in `lib/raggio/tabular/row_parser.ex` (FR-010)
- [x] T057 [US3] Verify row numbers in errors align to original file positions after filtering in `lib/raggio/tabular/row_parser.ex`

### Value Transforms

- [x] T058 [US3] Verify `Raggio.Tabular.Transform` module exists in `lib/raggio/tabular/transform.ex` (FR-018)
- [x] T059 [US3] Verify currency symbol stripping transform in `lib/raggio/tabular/transform.ex`
- [x] T060 [US3] Verify thousand separator removal transform in `lib/raggio/tabular/transform.ex`
- [x] T061 [US3] Verify whitespace trimming transform in `lib/raggio/tabular/transform.ex`
- [x] T062 [US3] Verify Excel date serial to Date conversion transform in `lib/raggio/tabular/transform.ex`
- [x] T063 [US3] Verify float-to-integer ID coercion transform in `lib/raggio/tabular/transform.ex`
- [x] T064 [US3] Verify transform pipeline integration with row_parser in `lib/raggio/tabular/row_parser.ex`

**Checkpoint**: User Story 3 complete - row filtering and transforms work independently

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Performance, documentation, and final validation

### Performance & Streaming

- [ ] T065 [P] Verify streaming behavior with example CSV parser for 100k row file stays within memory bounds (SC-003)
- [ ] T066 [P] Verify streaming behavior with example XLSX parser for 100k row file stays within memory bounds (SC-003)

### Legacy Parity Validation

- [ ] T067 Review `old/data_schema/sheet_schema.ex` and validate API parity in `lib/raggio/tabular/sheet_schema.ex` (FR-020)
- [ ] T068 Review `old/data_schema/sheet_schema/parser.ex` and validate behavior parity in `lib/raggio/tabular/row_parser.ex` (FR-020)
- [ ] T069 Review `old/data_schema/adapters/tabular.ex` and validate error reporting parity in `lib/raggio/tabular/` (FR-020)

### Documentation

- [x] T070 [P] Update module docs in `lib/raggio/tabular.ex` to explain parser-agnostic architecture and `parser:` option requirement
- [x] T071 [P] Update module docs in `lib/raggio/tabular/parser.ex` with behaviour implementation guide
- [x] T072 [P] Update module docs in `lib/raggio/tabular/sheet_schema.ex` with schema definition examples
- [x] T073 [P] Add typespecs to all public functions in `lib/raggio/tabular/` modules (already present)

### Quickstart Validation

- [x] T074 Update example script `examples/raggio_tabular/csv_parsing/basic_csv.exs` to use explicit parser option
- [x] T075 Update example scripts in `examples/raggio_tabular/` to use explicit parser option
- [x] T076 Validate quickstart scenarios from `specs/003-sheet-adapter/quickstart.md` work as documented with new API (API corrected in quickstart)

### Cleanup

- [x] T077 Remove any dead code references to old Adapter behaviour in `lib/raggio/tabular/` (adapter.ex deleted in prior session)
- [x] T078 No test files in `test/raggio/tabular/` exist - tests not explicitly requested in spec
- [x] T079 Run `mix compile --warnings-as-errors` to verify no compilation warnings (PASSED)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately - refactors existing code
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - core parsing with explicit parser
- **User Story 2 (Phase 4)**: Depends on Foundational - can run parallel to US1
- **User Story 3 (Phase 5)**: Depends on Foundational - can run parallel to US1/US2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: MVP - explicit parser selection with example implementations
- **User Story 2 (P2)**: Independent of US1 at code level, but builds on same foundation
- **User Story 3 (P2)**: Independent of US1/US2 at code level, but builds on same foundation

### Within Each User Story

- Public API changes before parser integration
- Row parsing updates before example implementations
- Example implementations can be developed in parallel (CSV and XLSX are independent)

### Parallel Opportunities

**Phase 1 Parallel Group (after dependency moves)**:
```
T004 (move CSV) || T005 (move XLSX)
```

**Phase 2 Parallel Group**:
```
T014 (verify Error) || T015 (verify Result) || T016 (verify SheetSchema) || T017 (verify ColumnDef)
```

**Phase 3 Example Parser Parallel Group**:
```
T030-T034 (CSV example parser) || T035-T039 (XLSX example parser) || T040-T041 (example docs)
```

**Phase 6 Parallel Group**:
```
T065 (CSV perf) || T066 (XLSX perf) || T070-T073 (docs)
```

---

## Parallel Example: User Story 1 Example Parsers

```bash
# Launch both example parser updates in parallel:
Task: "Update examples/tabular/csv_parser.ex to implement Raggio.Tabular.Parser behaviour"
Task: "Update examples/tabular/xlsx_parser.ex to implement Raggio.Tabular.Parser behaviour"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T007) - Refactor to parser-agnostic
2. Complete Phase 2: Foundational (T008-T017) - Define Parser behaviour
3. Complete Phase 3: User Story 1 (T018-T045) - Explicit parser selection works
4. **STOP and VALIDATE**: Test with example CSV/XLSX parsers
5. Deploy/demo if ready - core value delivered with new architecture

### Incremental Delivery

1. Setup + Foundational -> Parser-agnostic foundation ready
2. Add User Story 1 -> Test explicit parser -> Demo (MVP!)
3. Add User Story 2 -> Test header variants/unions -> Demo
4. Add User Story 3 -> Test filtering/transforms -> Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: Public API updates (T018-T025)
   - Developer B: Example CSV parser (T030-T034)
   - Developer C: Example XLSX parser (T035-T039)
3. Integrate and complete row parsing updates (T026-T029, T042-T045)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- **NEW**: Parser implementations are in `examples/`, not `lib/`
- **NEW**: All `Raggio.Tabular` calls REQUIRE explicit `parser:` option
- **NEW**: `lib/raggio/tabular/parser.ex` is the BEHAVIOUR, `row_parser.ex` is the parsing LOGIC
- Legacy code in `old/` is reference for behavioral parity, not copy-paste source
- Example parsers use `nimble_csv` and `xlsx_reader` as `:dev` dependencies
