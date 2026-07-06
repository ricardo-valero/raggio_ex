# Changelog

## 0.2.0 (2026-07-06)

### Changed — encode presence semantics (D18, breaking)

Struct encode no longer silently drops every `nil`/absent field. Presence is now
driven by the field's context, matching effect-smol:

- `optional()` or defaulted field holding `nil` (or absent) → key **omitted**
  (unchanged — the common nil-omission convention still holds)
- `nullable()` field holding `nil` → **emits `key => nil`** (previously omitted);
  nullable wins when combined with `optional()`
- plain required field holding `nil` → **error** (previously silently omitted)
- required key absent on plain-map input → **`MissingKey` error** (previously omitted)
- `any()` fields pass `nil` through (unknown admits null)

This makes encoder output consistent with the JSON Schema the adapter publishes
(`required` + `type: [..., "null"]`). Migration: where a `nil` is intentional,
declare the field `optional()` (omit) or `nullable()` (emit null).

Also removed: the root-level "defaulted slot encodes nil" special case — defaults
are decode-side only (effect's `withDecodingDefault`).

## 0.1.1 and earlier

See git history.
