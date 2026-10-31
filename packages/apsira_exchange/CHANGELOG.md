# Changelog

## 0.5.0 — 2026-10-31

- test-only: the sqlite3 hook names Fedora's `/usr/lib64/libsqlite3.so.0`; consumers unaffected
  (hooks read `user_defines` from the root package only). No migration.

## 0.4.0 — 2026-10-24

First release (D-APK-019): LYCEUM's envelope for every app's export (ruling C2).

- `ExportEnvelope`, `Producer`, `formatInstant`: LYCEUM `lib/domain/export/envelope.dart` @
  `9f4ff27`, with `format`, `producer` and `extra` as parameters (LYCEUM's top-level
  `app_version` is an `extra` key).
- `checkEnvelope`, `checkEnvelopeUtf8`: LYCEUM's `checkEnvelope`, returning a sealed
  `EnvelopeCheck` instead of LYCEUM's failures, and reading `LegacyShape.relayExportV1` and
  `LegacyShape.viaticumExchangeV1` when the app passes them.
- `exportedTables`, `JsonDump`, `writeExport`: LYCEUM `lib/data/db/json_dump.dart` @
  `9f4ff27`, with `exclude`, `only`, `redactions` and `DumpLayout.rowPerLine` (RELAY's
  layout and `formatExportReal`, `lib/data/db/json_dump.dart` @ `09b28810`).
- `buildDatabaseFrom`, `loadOrderOf`: LYCEUM `lib/data/db/json_load.dart` @ `9f4ff27`, with
  the app's database, upgrade steps, `afterLoad`, load order and pragmas passed in; refusals
  as `LoadRefused` (`loadNotABundle`, `loadSchemaTooNew`, `loadStorageFull`).
- `package:apsira_exchange/envelope.dart` (ruling R-11): the envelope and its reader alone, with
  no drift, sqlite3, `dart:io` or Flutter, for an app's pure-Dart domain layer; the barrel's
  exports are unchanged.
- `tool/validate_examples.py`: VIATICUM's and LYCEUM's validators as one, with its unittest.
- Migration, LYCEUM: `ExportEnvelope(appVersion:, …)` → `ExportEnvelope(format: 'lyceum-export',
  producer: Producer('lyceum', v), extra: {'app_version': v}, …)`; map `NotABundle`,
  `FormatUnsupported`, `SchemaTooNew` and the three `LoadRefusal`s to the import codes, and
  refuse an empty top-level `app_version` itself; `JsonDump.writeTables(db, out)` →
  `JsonDump(db).writeTables(out, await exportedTables(db))`.
- Migration, RELAY: `JsonDump.write` → `writeExport` with the envelope, `only:
  jsonExportTables`, its `settings` redactions through `jsonFieldRedaction` and
  `DumpLayout.rowPerLine`; the reader passes `LegacyShape.relayExportV1`.
- Migration, VIATICUM: results gain `schema_version`; the readers pass
  `LegacyShape.viaticumExchangeV1`, the domain's through `envelope.dart`;
  `validate_examples.py --schemas … --examples … --check`, and `--schema` mode now exits 1 on an
  invalid file.
