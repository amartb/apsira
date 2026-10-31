# Changelog

## 0.6.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.6.0`.

## 0.5.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.5.0`.

## 0.4.0 — 2026-10-24

First release (D-APK-020): RELAY's streaming ZIP for RELAY and LYCEUM.

- `ZipWriter`: RELAY `lib/data/files/backup_zip_writer.dart` @ `09b28810`
  (`BackupZipWriter`, renamed; LYCEUM's `BundleZipWriter` is the same code), with
  `ZipEntry`, `ZipEntryInfo`, `ZipSummary`, `ZipProfile`, `zipNameProblem` and
  `RunningSha256`. `write` takes any `Iterable<ZipEntry>`.
- `Crc32` and `crc32(bytes)`: RELAY `lib/data/files/crc32.dart` @ `09b28810`.
- `verifyZip`: RELAY `lib/data/files/backup_zip_reader.dart` @ `09b28810`, with
  `keepLimit` required and the apps' parts as hooks: `nameAllowed`, `sha256Where`,
  `onEntry` (`rejected`), `extractWhere` with an `ExtractSink` (`FileExtractSink`).
  `ENOSPC` while extracting is `storageFull` (LYCEUM's). Refusals are `ZipRefusal`, carried
  by `ZipRefused` with RELAY's codes (`zipTruncated`…).
- Migration, RELAY: `verifyBackupZip` → `verifyZip(…, keepLimit: 1 << 20)`; `sha256Of`
  → `sha256Where`; the `extract` map and `extractWhere` → `extractWhere` with a
  `FileExtractSink`; map `storageFull` to the restore's storage failure (it was a thrown
  `FileSystemException`).
- Migration, LYCEUM: `verifyBundleZip` → `verifyZip(…, keepLimit: 16 << 20,
  nameAllowed: isSafeEntryName, …)` with the media rule as `onEntry`;
  `BundleZipRefused` → `ZipRefused`, mapped to the import codes (`mediaHashMismatch` is
  `rejected`).
