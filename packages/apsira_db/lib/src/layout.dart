// From relay lib/data/db/opener.dart @ 09b28810 (`DatabaseFiles`), with
// lyceum lib/data/db/restore_swap.dart @ 9f4ff27's names (`RestoreFiles`) as
// a layout (D-APK-018). Plain Dart.
/// Where a database's files live: the names, as a [DatabaseLayout], and the
/// files themselves in one directory, as [DatabaseFiles].
library;

import 'dart:io';

/// The on-disk names of an app's database, relative to its directory.
///
/// [DatabaseLayout.standard] is RELAY's and VIATICUM's. LYCEUM passes its own
/// names (`lyceum.sqlite`, `lyceum.sqlite.restoring`,
/// `lyceum.sqlite.migrating`, `restore/lyceum.staged.sqlite`,
/// `snapshots/lyceum.safety.db`), so no file an installed version wrote is
/// renamed. Every marker is written as `<marker>.tmp`, flushed and renamed.
final class DatabaseLayout {
  const DatabaseLayout({
    required this.database,
    required this.restoringMarker,
    required this.migratingMarker,
    required this.staged,
    required this.safetyCopy,
    this.snapshotsDir = 'snapshots',
  });

  /// RELAY's and VIATICUM's names: `<name>.db`, `<name>.db.restoring`,
  /// `<name>.db.migrating`, `restore/<name>.staged.db`,
  /// `snapshots/<name>.safety.db`.
  DatabaseLayout.standard(String name)
    : this(
        database: '$name.db',
        restoringMarker: '$name.db.restoring',
        migratingMarker: '$name.db.migrating',
        staged: 'restore/$name.staged.db',
        safetyCopy: 'snapshots/$name.safety.db',
      );

  /// The database file; SQLite keeps its `-wal`, `-shm` and `-journal`
  /// beside it.
  final String database;

  /// Present while a restore (or a migration's restore) is under way; it
  /// names the copy it puts back.
  final String restoringMarker;

  /// Present from the pre-migration snapshot until the migration has
  /// succeeded; it names that snapshot.
  final String migratingMarker;

  /// Where a backup restore stages the database it validates, on the same
  /// file system as the live one.
  final String staged;

  /// A backup restore's safety copy of the database it replaces. Never
  /// rotated with the pre-migration snapshots.
  final String safetyCopy;

  /// The directory of the pre-migration snapshots (and of the safety copy).
  final String snapshotsDir;

  /// The files that belong to this install and not to its data: the
  /// markers and their `.tmp`. An app excludes them from Android's cloud
  /// backup and device transfer (adoption .6), so another phone never
  /// restores over its own database because of a marker it did not write.
  List<String> get perInstallPaths => [
    restoringMarker,
    '$restoringMarker.tmp',
    migratingMarker,
    '$migratingMarker.tmp',
  ];
}

/// The database's files in [directory], named by [layout]
/// ([DatabaseLayout.standard] of [name] when none is given).
///
/// [name] is the base of the snapshots' names: `<name>.pre-v<N>.db` for the
/// pre-migration snapshot of version N, `<name>.safety-<n>.db` for an
/// earlier restore's safety copy.
final class DatabaseFiles {
  DatabaseFiles(
    Directory directory, {
    required this.name,
    DatabaseLayout? layout,
  }) : layout = layout ?? DatabaseLayout.standard(name),
       _dir = directory.path;

  final String _dir;

  final String name;

  final DatabaseLayout layout;

  /// The directory that holds the database and its markers.
  Directory get directory => Directory(_dir);

  File _at(String relative) => File('$_dir/$relative');

  File get database => _at(layout.database);

  Directory get snapshots => Directory('$_dir/${layout.snapshotsDir}');

  /// The pre-migration snapshot of [version].
  File snapshot(int version) =>
      File('${snapshots.path}/$name.pre-v$version.db');

  File get restoreMarker => _at(layout.restoringMarker);

  /// Where the restore marker is written and flushed before it is renamed
  /// to [restoreMarker]. Alone, it is a restore that never began.
  File get restoreMarkerTmp => File('${restoreMarker.path}.tmp');

  File get migratingMarker => _at(layout.migratingMarker);

  /// Where the migrating marker is written and flushed before it is renamed
  /// to [migratingMarker]. Alone, it is a migration that never began.
  File get migratingMarkerTmp => File('${migratingMarker.path}.tmp');

  /// Where a restore copies a snapshot or the staged database before
  /// renaming it into place.
  File get restoreCopy => File('${database.path}.restore');

  File get safetyCopy => _at(layout.safetyCopy);

  /// The safety copy's base name, as the restore marker names it.
  String get safetyCopyName => safetyCopy.uri.pathSegments.last;

  /// Where a backup restore stages the database it validates.
  Directory get staging => stagedDatabase.parent;

  File get stagedDatabase => _at(layout.staged);

  /// The name a pre-migration snapshot of this database has.
  RegExp get snapshotName =>
      RegExp('^${RegExp.escape(name)}\\.pre-v(\\d+)\\.db\$');

  /// The name an earlier restore's kept safety copy has.
  RegExp get keptSafetyCopyName =>
      RegExp('^${RegExp.escape(name)}\\.safety-(\\d{1,9})\\.db\$');
}
