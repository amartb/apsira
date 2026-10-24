// From relay lib/core/ports/backup_target.dart @ 09b28810.
import 'package:apsira_core/apsira_core.dart';

/// The user's backup folder (RELAY architecture §3.1 and §10), picked through the
/// system folder picker with a persisted permission.
///
/// The target keeps no state of its own: the app stores the folder in its
/// own setting and passes it to every call. Names are plain file names,
/// never paths. The target deletes whatever name it is given, so callers
/// delete only the names they recognise as their app's.
abstract interface class BackupTarget {
  /// Failure: the folder was moved, deleted or its permission revoked.
  static const folderUnavailable = Failure(
    'backupFolderUnavailable',
    nextStep: 'chooseBackupFolder',
  );

  /// Failure: the folder's storage is full.
  static const storageFull = Failure('backupStorageFull');

  /// Failure: a file of that name is already in the folder. Writes and
  /// renames never replace a file.
  static const exists = Failure('backupFileExists');

  /// Failure: no file of that name is in the folder.
  static const missing = Failure('backupFileMissing');

  /// Asks the user for a folder and persists the permission. `null` when the
  /// user cancels.
  Future<BackupFolder?> pickFolder();

  /// Whether [folder] can still be listed and written.
  Future<bool> hasAccess(BackupFolder folder);

  /// The bytes free on the storage that holds [folder], or null when they
  /// cannot be measured (a provider that is not a local volume, a folder
  /// that is gone). Never throws.
  Future<int?> freeBytes(BackupFolder folder);

  /// Streams [bytes] into a new file [name] in [folder].
  ///
  /// Refuses with [exists] when [name] is taken, without listening to
  /// [bytes]. A failure part-way may leave a partial file, which the caller
  /// removes; an error from [bytes] is rethrown, likewise.
  Future<Result<BackupFile, Failure>> write(
    BackupFolder folder,
    String name,
    Stream<List<int>> bytes,
  );

  /// Renames the file [from] to [to]; [exists] when [to] is taken, [missing]
  /// when [from] is not there.
  Future<Result<BackupFile, Failure>> rename(
    BackupFolder folder,
    String from,
    String to,
  );

  /// Deletes the file [name]; a name that is not there is already deleted.
  Future<Result<void, Failure>> delete(BackupFolder folder, String name);

  /// The files in [folder], by name.
  Future<Result<List<BackupFile>, Failure>> list(BackupFolder folder);

  /// Streams the file [name] from [folder]. Failures, before or part-way,
  /// end the stream with a [BackupTargetException] carrying [missing],
  /// [folderUnavailable] or the target's own failure.
  Stream<List<int>> read(BackupFolder folder, String name);
}

/// The error a [BackupTarget.read] stream ends with on an expected failure.
final class BackupTargetException implements Exception {
  const BackupTargetException(this.failure);

  final Failure failure;

  @override
  String toString() => 'BackupTargetException($failure)';
}

/// A folder the user picked; [uri] is opaque to everything but the target.
final class BackupFolder {
  const BackupFolder({required this.uri, required this.displayName});

  final String uri;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is BackupFolder &&
      other.uri == uri &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uri, displayName);
}

/// A file in the backup folder.
final class BackupFile {
  const BackupFile({
    required this.name,
    required this.sizeBytes,
    required this.modifiedUtc,
  });

  final String name;
  final int sizeBytes;
  final DateTime modifiedUtc;
}
