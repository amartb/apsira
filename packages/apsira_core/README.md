# apsira_core

The pure-Dart core every Apsira app shares, extracted from RELAY at `5f606e9` with its
behaviour unchanged (D-APK-001). No dependencies; `sdk: ^3.13.0`.

| Library | Holds |
|---|---|
| `package:apsira_core/apsira_core.dart` | `Failure`, `Result<T, F>` (`Ok`, `Err`): expected failures as values. `Log`, `LogRecord`, `LogValue`, `LogSink`, `LogLevel`, `redacted`, `maxStackFrames`: content-free logging. `Clock` and `utcForWallTime`: the only source of time. `IdGen` (`String uuid()`): the only source of identifiers. |
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

The real implementations (a system clock, a UUIDv7 generator, a file log sink) are
platform code and stay in each app.

## Provenance

Every extracted file starts with `// From relay <path> @ 5f606e9`. Each test of RELAY's
that the package carries keeps its body unchanged; only its imports moved from
`flutter_test` and `package:relay/…` to `package:test` and this package's libraries.

## Checks

From this directory: `dart analyze --fatal-infos` and `dart test`. From the repository
root, `tool/check.sh` runs them for every package.
