// From viaticum lib/app/services/first_open_service.dart @ 78d38e0 (the
// file logic of FirstOpenService), for any per-install flag (D-APK-010 C1).
import 'dart:convert' show jsonEncode;
import 'dart:io';

/// A per-install flag: a file at [path] under app storage, never in the
/// database or a backup. A restore therefore neither sets nor clears it, and
/// a reinstall (app storage cleared) reads it as unset.
///
/// [path] is used verbatim, so an app keeps the file its installs already
/// have (VIATICUM: `first_open/done.json`).
final class InstallFlag {
  /// [directory] is app storage: the app's private support directory.
  InstallFlag({required this._directory, required this.path});

  /// The flag's path under app storage.
  final String path;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$path');

  /// Whether the flag is set: the file exists. A leftover `<path>.tmp`
  /// alone is not a flag.
  Future<bool> isSet() async => (await _file()).exists();

  /// Sets the flag. A file already there is kept as it is. Written to a
  /// `.tmp` first, flushed and renamed, so a crash leaves either no flag or
  /// a whole one.
  Future<void> set() async {
    final file = await _file();
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode({'done': true}), flush: true);
    await temp.rename(file.path);
  }
}
