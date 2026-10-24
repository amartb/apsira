# apsira_zip

RELAY's streaming ZIP, shared by RELAY's backups and LYCEUM's export bundles (D-APK-020).
Pure Dart; depends on `apsira_core` (`Result`, `Failure`) and `crypto: ^3.0.7`;
`sdk: ^3.13.0`. Its consumers are **RELAY and LYCEUM**: VIATICUM's backups and results are
folders.

| Library | Holds |
|---|---|
| `package:apsira_zip/apsira_zip.dart` | `ZipWriter` (`write(entries)` → a byte stream with back-pressure; `done` → `ZipSummary`), `ZipEntry` (name, byte stream, declared `size`, `sha256`, `written`), `ZipEntryInfo`, `ZipProfile`, `zipNameProblem`, `zip32Limit`, `RunningSha256`; `Crc32` and `crc32(bytes)`; `verifyZip(bytes, {required keepLimit, keep, expectedSha256, sha256Where, nameAllowed, onEntry, extractWhere, extract})` → `Result<ZipContents, ZipRefused>`, `ZipRefusal`, `ExtractSink`, `ExtractTarget`, `FileExtractSink`, `ZipEntryCheck`. |

The profile is RELAY's: raw deflate with data descriptors and UTF-8 names, one
modification time, no directories, comments or attributes, ZIP64 where a size or an offset
needs it. `verifyZip` accepts exactly that, in one pass over a stream, and ends every
damaged, foreign or unsafe zip with a `ZipRefusal`, never an exception: `truncated`,
`corrupt`, `crcMismatch`, `sizeMismatch`, `directoryMismatch`, `unsafeName`,
`entryTooLarge`, `digestMismatch`, `storageFull` (`ENOSPC` while extracting) and
`rejected` (the caller's `onEntry`). `ZipRefused.code` is `zip` + the refusal
(`zipTruncated`), RELAY's codes; another write failure, or an error of the stream itself,
is rethrown.

```dart
import 'package:apsira_zip/apsira_zip.dart';

final writer = ZipWriter(modified: wallTime);
await target.write(writer.write([
  ZipEntry('relay.db', dbFile.openRead(), size: dbLength, sha256: true),
  ZipEntry('manifest.json', manifestBytes()),
]));
final summary = await writer.done; // length, sha256, entries

// RELAY: its codes as they are, ENOSPC its own storage failure.
final verified = await verifyZip(target.read(name),
    keepLimit: 1 << 20, keep: {'manifest.json'}, expectedSha256: summary.sha256,
    extractWhere: (n) => n == 'relay.db', extract: FileExtractSink(stagingFile));

// LYCEUM: its entry names, every media entry checked against its name.
final bundle = await verifyZip(bytes, keepLimit: 16 << 20,
    nameAllowed: isSafeEntryName,
    sha256Where: (n) => storePathOfEntry(n) != null,
    onEntry: (e) => storePathOfEntry(e.name) == null ||
        e.sha256 == e.name.substring(e.name.length - 64));
final result = bundle.mapFailure((f) => Failure(importCodeOf(f.refusal)));
```

Each app maps the refusals to its own messages; the tables, in `test/support/apps.dart`,
are proved by `test/app_codes_test.dart`. LYCEUM's: `truncated`, `crcMismatch`,
`sizeMismatch`, `digestMismatch`, `rejected` → `importChecksumMismatch`; `corrupt`,
`directoryMismatch`, `unsafeName`, `entryTooLarge` → `importNotABundle`; `storageFull` →
`importStorageFull`.

## Provenance

`lib/src/` is RELAY `lib/data/files/{backup_zip_writer,backup_zip_reader,crc32}.dart` @
`09b28810`, each naming its source in its first line; the reader gains LYCEUM's `ENOSPC`
refusal (`bundle_zip_reader.dart` @ `9f4ff27`) and the hooks. The tests are RELAY's writer
and reader tests and LYCEUM's reader, writer and CRC tests (LYCEUM's reader cases in
`zip_reader_lyceum_test.dart`, through the hooks as LYCEUM passes them), with `archive` as
the independent decoder where LYCEUM used Python's `zipfile`.

## Checks

From this directory: `dart analyze --fatal-infos` and `dart test` (the `zip` gate). The
crash matrix KP-Z1…Z6 is `test/crash_matrix_test.dart`. `dart_test.yaml` runs one suite at
a time, because the writer's 256 MiB streaming test measures the process's memory.
