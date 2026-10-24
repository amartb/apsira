# apsira_core

The pure-Dart core every Apsira app shares, extracted from RELAY at `5f606e9` with its
behaviour unchanged (D-APK-001), plus the pieces the apps had copied or diverged on
(D-APK-011). One dependency, `crypto: ^3.0.7` (the stack hash); `sdk: ^3.13.0`.

| Library | Holds |
|---|---|
| `package:apsira_core/apsira_core.dart` | `Failure`, `Result<T, F>` (`Ok`, `Err`): expected failures as values. `Log`, `LogRecord`, `LogValue`, `LogSink`, `LogLevel`, `redacted`, `maxStackFrames`: content-free logging; `LogValue.id` takes UUIDs only, `LogValue.blockId` RELAY's six-character block IDs, and `LogRecord.stackHash` (16 hex of the SHA-256 of the frames, `null` without frames) ends `renderFields()`, so RELAY's log lines with a stack gain a `stackHash=<16 hex>` suffix (D-APK-011). `Clock` and `utcForWallTime`: the only source of time. `IdGen` (`String uuid()`): the only source of identifiers. `MonotonicIdGen(Clock, {Random?})`: UUIDv7s strictly increasing within a process (RFC 9562 §6.2 method 1, RELAY's algorithm, no `uuid` package). `ftsMatch(String) → String?`: RELAY's FTS5 MATCH string, every word a quoted prefix, `null` for no word. `encodeSortedJson` / `writeSortedJson`: LYCEUM's canonical JSON (keys sorted, no whitespace, BLOBs as base64). |
| `package:apsira_core/testing.dart` | `FakeClock` (time travel, fixed offsets or the Madrid daylight-saving timeline) and `FakeIdGen` (the n-th UUID is `00000000-0000-7000-8000-<n in 12 hex digits>`, from 1), for consumers' tests. |

The `src/` libraries are private: import the barrel. An app's typedef shims name what they
re-export, for example `export 'package:apsira_core/apsira_core.dart' show Clock;`.

```dart
import 'package:apsira_core/apsira_core.dart';

Result<int, Failure> parse(String s) => int.tryParse(s) == null
    ? const Err(Failure('notANumber'))
    : Ok(int.parse(s));
```

```dart
// test/…_test.dart
import 'package:apsira_core/testing.dart';

final clock = FakeClock.madrid(DateTime.utc(2026, 3, 29));
final ids = FakeIdGen();
```

```dart
final ids = MonotonicIdGen(clock); // Random.secure() unless a test seeds one
final match = ftsMatch(query);     // bind as a variable: … WHERE t MATCH ?
```

The platform implementations (a system clock, a file log sink) are not here; they
belong to the app layer.

## Provenance

Every extracted file starts with `// From <app> <path> @ <commit>`: RELAY at `5f606e9`
(v0.1) and `09b28810` (the UUIDv7 generator, `ftsMatch`), VIATICUM at `78d38e0` (the
stack hash), LYCEUM at `9f4ff27` (canonical JSON). Each carried test keeps its body
unchanged; only its imports moved from `flutter_test` and `package:<app>/…` to
`package:test` and this package's libraries. The exceptions are named in their file's
header: two `log_test` bodies (D-APK-011) and LYCEUM's three token-less `ftsMatch` cases,
restated to RELAY's rule (ruling R-2).

RELAY's `fts_match` test runs against SQLite FTS5 through `test/support/fts_db.dart`, a
stand-in for the drift surface it uses over the dev dependency `sqlite3`, with RELAY's
property engine in `test/support/prop/`.

## Checks

From this directory: `dart analyze --fatal-infos` and `dart test`. From the repository
root, `tool/check.sh` runs them for every package. The FTS tests load the host's SQLite
(`libsqlite3.so`, else `libsqlite3.so.0`; FTS5 with `remove_diacritics 2`, 3.27+).
