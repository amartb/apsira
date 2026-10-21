# Changelog

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
