// From lyceum lib/domain/export/entry_names.dart, format.dart and
// import_failures.dart @ 9f4ff27 (LYCEUM's bundle entry names and import
// codes) and relay lib/data/files/backup_zip_reader.dart @ 09b28810
// (RELAY's ZipCode names): the two consumers' values, so the tests prove the
// hooks and the refusal tables reproduce each app's reader (D-APK-020).
import 'package:apsira_zip/apsira_zip.dart';

// ---- RELAY ---------------------------------------------------------------

/// RELAY's `ZipCode` names, in its order.
const relayZipCodes = [
  'zipTruncated',
  'zipCorrupt',
  'zipCrcMismatch',
  'zipSizeMismatch',
  'zipDirectoryMismatch',
  'zipUnsafeName',
  'zipEntryTooLarge',
  'zipDigestMismatch',
];

/// RELAY's storage failure while a restore stages its files.
const relayRestoreStorageFull = 'restoreStorageFull';

/// The code RELAY reports for [refusal]: its own `ZipCode` name; `ENOSPC`
/// is its storage failure. RELAY passes no `onEntry`, so `rejected` cannot
/// occur; were it to, the zip is outside RELAY's profile.
String relayCode(ZipRefusal refusal) => switch (refusal) {
  ZipRefusal.storageFull => relayRestoreStorageFull,
  ZipRefusal.rejected => 'zipCorrupt',
  _ => refusal.code,
};

// ---- LYCEUM --------------------------------------------------------------

const lyceumJsonEntry = 'lyceum.json';
const manifestEntry = 'export-manifest.json';
const mediaEntryPrefix = 'media/';

const importNotABundle = 'importNotABundle';
const importChecksumMismatch = 'importChecksumMismatch';
const importStorageFull = 'importStorageFull';

/// Every LYCEUM import code, in its order.
const importCodes = [
  importNotABundle,
  'importFormatUnsupported',
  'importSchemaTooNew',
  'importManifestInvalid',
  'importChecksumInvalid',
  importChecksumMismatch,
  importStorageFull,
];

/// LYCEUM's `ZipRefusal.importCode` table, by its refusal names
/// (`mediaHashMismatch` is the package's `rejected`).
const lyceumTable = {
  'truncated': importChecksumMismatch,
  'corrupt': importNotABundle,
  'crcMismatch': importChecksumMismatch,
  'sizeMismatch': importChecksumMismatch,
  'mediaHashMismatch': importChecksumMismatch,
  'directoryMismatch': importNotABundle,
  'unsafeName': importNotABundle,
  'entryTooLarge': importNotABundle,
  'digestMismatch': importChecksumMismatch,
  'storageFull': importStorageFull,
};

/// The import code LYCEUM shows for [refusal].
String lyceumImportCode(ZipRefusal refusal) => switch (refusal) {
  ZipRefusal.truncated ||
  ZipRefusal.crcMismatch ||
  ZipRefusal.sizeMismatch ||
  ZipRefusal.digestMismatch ||
  ZipRefusal.rejected => importChecksumMismatch,
  ZipRefusal.corrupt ||
  ZipRefusal.directoryMismatch ||
  ZipRefusal.unsafeName ||
  ZipRefusal.entryTooLarge => importNotABundle,
  ZipRefusal.storageFull => importStorageFull,
};

final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');

final RegExp _mediaEntry = RegExp(
  r'^media/([0-9a-f]{2})/([0-9a-f]{2})/([0-9a-f]{64})$',
);

/// Whether [name] is one of the bundle's three entry shapes.
bool isSafeEntryName(String name) =>
    name == lyceumJsonEntry ||
    name == manifestEntry ||
    storePathOfEntry(name) != null;

/// The entry name of the media file whose content hashes to [sha256].
String mediaEntryName(String sha256) {
  if (!_sha256.hasMatch(sha256)) {
    throw ArgumentError.value(sha256, 'sha256', 'not 64 lower-case hex');
  }
  return '$mediaEntryPrefix${sha256.substring(0, 2)}/'
      '${sha256.substring(2, 4)}/$sha256';
}

/// The media store path of the media entry [name], or null.
String? storePathOfEntry(String name) {
  final m = _mediaEntry.firstMatch(name);
  if (m == null) return null;
  final sha = m.group(3)!;
  if (m.group(1) != sha.substring(0, 2) || m.group(2) != sha.substring(2, 4)) {
    return null;
  }
  return name.substring(mediaEntryPrefix.length);
}

/// LYCEUM's media-hash rule as an `onEntry` check: a media entry's sha256
/// is the last 64 characters of its name.
bool lyceumMediaHash(ZipEntryInfo e) =>
    storePathOfEntry(e.name) == null ||
    e.sha256 == e.name.substring(e.name.length - 64);

/// LYCEUM's hashing rule: every media entry, and the entries it names.
bool Function(String) lyceumSha256Where([Set<String> also = const {}]) =>
    (name) => storePathOfEntry(name) != null || also.contains(name);
