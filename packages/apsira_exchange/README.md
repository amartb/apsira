# apsira_exchange

One export envelope for every Apsira app (ruling C2, D-APK-019): LYCEUM's envelope and its
reader, the older shapes each released app wrote, the `sqlite_master` dump with each app's
table list, redactions and layout, LYCEUM's loader, and one `tool/validate_examples.py`.
Pure Dart; depends on `apsira_core`, `drift: ^2.35.2` and `sqlite3: ^3.7.1`; `sdk: ^3.13.0`.
Its consumers are **RELAY, VIATICUM and LYCEUM**.

| Library | Holds |
|---|---|
| `package:apsira_exchange/apsira_exchange.dart` | `ExportEnvelope` (`format`, `formatVersion` `1.0`, `producedAt`, `producer`, `schemaVersion`, `extra`; `toJson`, `writeHead`, `tail`, `encode`), `Producer`, `formatInstant`; `checkEnvelope` / `checkEnvelopeUtf8` → `EnvelopeOk(envelope, readAs)` · `NotABundle(reason)` · `FormatUnsupported(found)` · `SchemaTooNew(found, supported)`, `EnvelopeInfo`, `LegacyShape`; `exportedTables`, `JsonDump` (`DumpLayout`, `RowRedaction`, `jsonFieldRedaction`), `writeExport`, `formatExportReal`; `buildDatabaseFrom` → `Result<LoadSummary, LoadRefused>` (`LoadRefusal`), `loadOrderOf`, `LoadStepHook`. |
| `package:apsira_exchange/envelope.dart` | The envelope alone: `ExportEnvelope`, `Producer`, `formatInstant`, `exportFormatVersion`, `envelopeKeys`; `checkEnvelope` / `checkEnvelopeUtf8` with their outcomes, `EnvelopeInfo`, `LegacyShape`, `isReadableFormatVersion`. It reaches only `apsira_core` and the SDK's core libraries, never drift, sqlite3, `dart:io` or Flutter (`test/envelope_library_test.dart` runs it in a plain Dart program). |

## The envelope

Required keys: `format`, `format_version` (written `"1.0"`; read: major 1, any minor),
`produced_at` (UTC `YYYY-MM-DDTHH:MM:SSZ`; read with an optional fraction), `producer {app,
app_version}`, `schema_version` (an integer ≥ 1). The document is canonical JSON (`apsira_core`'s
`writeSortedJson`) with `tables` last, so a dump streams it between `writeHead` and `tail`. An
app adds its own keys through `extra` (none may be an envelope key or sort after `tables`);
readers ignore the keys they do not know. Backup manifests are not envelopes.

A pure-Dart domain layer (VIATICUM's exchange readers, which may not import drift or `dart:io`)
imports `envelope.dart`; the data layer, which dumps and loads, imports the barrel. Both export the
same envelope types, so a value passes from one to the other.

`checkEnvelope` never throws. The app passes its formats, its schema version and the legacy
shapes it still reads, and maps the four outcomes to its own codes:

| App | Writes | Reads |
|---|---|---|
| LYCEUM | `lyceum-export`, `extra: {'app_version': …}`, unchanged byte for byte | the envelope; requires its `app_version` itself |
| RELAY | `relay-export` in the envelope; `tables` unchanged (`DumpLayout.rowPerLine`, its list, its `settings` redactions) | the envelope and `LegacyShape.relayExportV1` (v1.0.0…v2.0.x) |
| VIATICUM | results with `schema_version`, `extra: {'artifact_id': …}` | the envelope and `LegacyShape.viaticumExchangeV1` (VELLUM's seed and package; its results up to v1.0.x) |

```dart
import 'package:apsira_exchange/apsira_exchange.dart';

// RELAY's export into its zip entry; RELAY keeps its table list.
final counts = await writeExport(sink,
    envelope: ExportEnvelope(format: 'relay-export', producedAt: clock.nowUtc(),
        producer: Producer('relay', appVersion), schemaVersion: 12),
    dump: JsonDump(snapshot, layout: DumpLayout.rowPerLine, redactions: {
      'settings': jsonFieldRedaction(keyColumn: 'key', valueColumn: 'value',
          fields: {'backup': [['folderUri']]}),
    }),
    tables: await exportedTables(snapshot, only: jsonExportTables));

// LYCEUM's restore: the envelope, then the load beside the live database.
final read = checkEnvelopeUtf8(bytes, formats: {'lyceum-export'},
    currentSchemaVersion: LyceumDatabase.currentVersion);
final built = await buildDatabaseFrom(stagedFile, tables,
    bundleSchema: schema, currentSchema: LyceumDatabase.currentVersion,
    open: LyceumDatabase.forTesting, setup: applyPragmas,
    upgrade: (db, from) async => upgradeSteps[from]?.call(db),
    afterLoad: rebuildDerivedIndexes);
```

## The dump and the loader

`exportedTables` lists every base table of `sqlite_master` but SQLite's own, virtual tables
and their shadow tables, and the app's `exclude` (device state); `only` takes an app's own list
and refuses a name that is not such a table. `JsonDump.writeTables` streams each table page by
page in primary-key order (a table without one, by every column), values as stored, BLOBs as
base64, and returns the counts. `writeExport` lets every sink or database error through, so
the caller's `.part` is never renamed.

`buildDatabaseFrom` builds a fresh file at the app's schema in one transaction (parents first,
foreign keys deferred), runs `upgrade` for each version from the document's, then `afterLoad`,
and checks foreign keys, integrity and counts. A refusal (`notABundle`, `schemaTooNew`,
`storageFull`, codes `loadNotABundle`…) or any other error leaves nothing at the target, and a
file a killed run left there is removed before the next build starts.

## validate_examples.py

```sh
python3 -I tool/validate_examples.py --schemas exchange/schemas --examples exchange/examples --check [--pairs]
python3 -I tool/validate_examples.py --schemas exchange/schemas --schema KIND FILE...
```

The profile follows the schemas: `<app>-export` with `export-manifest` is the envelope profile
(LYCEUM's rules 1–5, `valid/` and `invalid/<rule>-<kind>-<what>.json`, `--pairs` checks that each
manifest describes its export through `<app>_json`); `seed`, `package` and `results` is
VIATICUM's (its 05 §4.5 rules for packages, `invalid/<kind>-<rule>-<what>.json`). `--schema`
mode exits 1 when any file is invalid (LYCEUM's; VIATICUM's exited 0). Needs `jsonschema >= 4`.

## Provenance

`lib/src/envelope.dart`, `envelope_check.dart`, `json_dump.dart` and `json_load.dart` are
LYCEUM `lib/domain/export/envelope.dart`, `lib/data/db/json_dump.dart` and `json_load.dart` @
`9f4ff27`, each naming its source in its first line; `formatExportReal`, the row-per-line
layout and `jsonFieldRedaction` are RELAY `lib/data/db/json_dump.dart` and
`lib/domain/export/json_export_format.dart` @ `09b28810`. The validator is VIATICUM's
`tool/exchange/validate_examples.py` @ `78d38e0` joined with LYCEUM's @ `9f4ff27`.

The fixtures are each released tag's own (`test/fixtures/README.md`): RELAY v2.0.1's database
and the `relay.json` its own `JsonDump` wrote from it, VIATICUM v0.2.0's and v1.0.0's examples,
and LYCEUM v1.0.0's and VIATICUM v1.0.0's `exchange/` folders.

## Checks

From this directory: `dart analyze --fatal-infos`, `dart test` and
`python3 -m unittest discover -s tool -p 'test_*.py'` (the `exchange` gate). The crash matrix
KP-E1…E6 is `test/crash_matrix_test.dart`. The tests use the host's `libsqlite3`
(`hooks: user_defines` in `pubspec.yaml`); the apps keep sqlite3's own library.
