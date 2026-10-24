/// RELAY's streaming ZIP, shared by RELAY's backups and LYCEUM's export
/// bundles (D-APK-020): [ZipWriter] writes entries from their streams with
/// back-pressure and ZIP64 where needed, [Crc32] sums them, and [verifyZip]
/// checks a zip in one pass and refuses anything outside the profile with a
/// [ZipRefusal], the apps' parts passed in as hooks.
library;

export 'src/crc32.dart';
export 'src/zip_reader.dart';
export 'src/zip_writer.dart';
