# Changelog

## 0.5.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.5.0`.

## 0.4.0 — 2026-10-24

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.4.0`.

## 0.3.0 — 2026-10-24

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.3.0`.

## 0.2.0 — 2026-10-24

The pieces the three apps copied or diverged on (D-APK-011). First dependency:
`crypto: ^3.0.7` (N2-a); dev dependency `sqlite3` for the FTS5 tests.

- `MonotonicIdGen(Clock, {Random?})`: RELAY `lib/data/platform/uuid_id_gen.dart` @
  `09b28810`, RFC 9562 §6.2 method 1 (a 12-bit counter seeded below `0x800` each
  millisecond; a clock that steps back keeps the last timestamp; overflow borrows the next
  millisecond), with the bytes laid out here instead of by `package:uuid`. A seeded
  `Random` gives RELAY's exact IDs.
- `ftsMatch`: RELAY `lib/data/db/query_sql/fts_match.dart` @ `09b28810`, unchanged
  (ruling R-2): a word with no letter or digit stays a quoted phrase that matches nothing.
- `encodeSortedJson`, `writeSortedJson`: LYCEUM `lib/domain/export/canonical_json.dart` @
  `9f4ff27`, unchanged.
- `LogRecord.stackHash`: VIATICUM `lib/core/log.dart` @ `78d38e0`, the first 16 hex digits
  of the SHA-256 of `stackFrames.join('\n')`, `null` without frames; `renderFields()`
  ends with `stackHash=<hash>` when there is one.
- `LogValue.id` accepts UUIDs only (VIATICUM's rule: a short lowercase word could be
  content). `LogValue.blockId` accepts RELAY's six-character `a–z0–9` block IDs.
- Tests: RELAY's `uuid_id_gen` (uuid group), `fts_match` (property test included) and
  property engine (`test/support/prop/`); LYCEUM's `canonical_json` and `fts_query` cases;
  VIATICUM's `log_test` ID and stack-hash cases.

Migration for RELAY:

- `UuidIdGen.uuid()` → `MonotonicIdGen` (RELAY keeps its own `blockId()` beside it, in
  its `IdGen` shim); `package:uuid` is no longer needed for IDs.
- `LogValue.id(blockId)` → `LogValue.blockId(blockId)`: `LogValue.id` now redacts a
  block ID.
- Log lines with a stack gain `stackHash=<16 hex>` after the fields.
- `lib/data/db/query_sql/fts_match.dart` → the barrel's `ftsMatch` (same rule).

Migration for VIATICUM:

- `UuidIdGen` → `MonotonicIdGen`.
- `lib/core/log.dart` → the barrel: the same `stackHash`, ID rule and rendering.

Migration for LYCEUM:

- `UuidIdGen` → `MonotonicIdGen`: the defect fix, IDs strictly increasing within one
  millisecond (D-APK-005).
- `lib/domain/search/fts_query.dart` → `ftsMatch`, RELAY's rule: a query with no letter
  or digit gives a never-matching phrase instead of `null`. Neutral for
  `search_service.dart`, which maps both to `[]`.
- `lib/domain/export/canonical_json.dart` → the barrel (same names).

## 0.1.0 — 2026-10-21

First release, extracted from RELAY `5f606e9` (`v1.0.0`) with RELAY's behaviour.

- `Failure`, `Result`, `Ok`, `Err` from `lib/core/result.dart`.
- `Log`, `LogRecord`, `LogValue`, `LogSink`, `LogLevel`, `redacted`, `maxStackFrames` from
  `lib/core/log.dart`. `LogValue.id` still accepts RELAY's six-character block IDs as
  well as UUIDs.
- `Clock` (full surface) and `utcForWallTime` from `lib/core/ports/clock.dart`.
- `IdGen` from `lib/core/ports/id_gen.dart` with `uuid()` only.
- `FakeClock` and `FakeIdGen` (`uuid()` only) in `package:apsira_core/testing.dart`, from
  RELAY's `test/fakes/`.
- Tests carried unchanged: `result_test`, `log_test`, `fake_clock_test`,
  `clock_utc_for_test`. New: `fake_id_gen_test`.

Migration for RELAY (and any app adopting by typedef shims):

- `IdGen.blockId()`, `IdGen.blockIdAlphabet`, `blockIdLength` and `blockIdPattern`, and
  `FakeIdGen.blockId()` / `queueBlockIds()` are not here: block IDs are RELAY's note
  model and stay in RELAY, beside its shim for `IdGen`.

Not carried from RELAY's tests: `test/core/ports_inventory_test.dart` checks RELAY's
whole port set against its platform implementations and fakes, which are app code.
