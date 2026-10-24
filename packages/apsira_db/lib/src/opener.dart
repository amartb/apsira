// From relay lib/data/db/opener.dart @ 09b28810, generic over the app's
// database, its name and its layout, with the step hook of D-APK-018 and the
// recovery of a LYCEUM 1.0.x restore marker (lyceum
// lib/data/db/restore_swap.dart @ 9f4ff27). VIATICUM's copy @ 78d38e0 is an
// older RELAY: it gains the migrating marker.
/// Opening the database file safely: a snapshot before every migration, the
/// restore when a migration fails, and the read-only safe mode that follows
/// a failure.
///
/// The files, all in the directory the caller passes (app-private storage,
/// never the cache the OS may purge), named by the [DatabaseLayout]:
///
/// - the database with its `-wal` and `-shm`;
/// - `snapshots/<name>.pre-v<N>.db`: a `VACUUM INTO` copy taken before
///   migrating from version N; the one just taken and the newest others
///   by write order are kept, `keepSnapshots` in all;
/// - the restore marker: present while a restore is under way, so a
///   restore cut short is finished by the next open before anything reads
///   the file or its stale WAL. It names the copy it restores (its base
///   name: a snapshot, or a backup restore's safety copy) and is written as
///   `<marker>.tmp`, flushed and renamed, so it is never seen half-written.
///   A LYCEUM 1.0.x marker holds `swap` or `rollback` instead and is
///   recovered by LYCEUM's rules;
/// - the safety copy: a backup restore's copy of the database it replaced
///   (`swap.dart`), never rotated. From the swap until the restore has
///   passed its integrity check, the restore marker names it, so a restore
///   cut short is rolled back by the next open;
/// - the migrating marker: present from the pre-migration snapshot until
///   the migration has succeeded, naming that snapshot, written like the
///   restore marker. A background open that finds it backs off, whatever
///   the file's header says (a migration commit over 1,000 WAL pages
///   checkpoints itself, so the header can carry the target before the
///   migration has succeeded). An open that finds it left by a launch cut
///   short restores its snapshot first.
///
/// Every rename and removal of a marker, and the snapshot's rename, is
/// followed by an fsync of its directory ([SyncDirectory]), so it is
/// durable before the open goes on: no commit of the session that follows
/// precedes it, and a power loss cannot bring a removed marker back to
/// restore over those commits.
///
/// Only the UI's open ([openWithSnapshot]) creates, snapshots, migrates or
/// restores. A background open ([openForBackground]) does none of these: it
/// opens a file that is already at the build's version, or reports why not.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:apsira_core/apsira_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftIsolate, DriftRemoteException;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqlite3/sqlite3.dart' show Database, OpenMode, sqlite3;

import 'connection.dart';
import 'fsync.dart';
import 'layout.dart';
import 'step_hook.dart';
import 'swap.dart';

/// How many pre-migration snapshots are kept by default (RELAY's D-044).
const int defaultKeepSnapshots = 2;

/// The steps of [openWithSnapshot]'s migration, in order; each is named to
/// `onStep` once done.
enum OpenStep {
  /// A migration is due; the pre-migration snapshot is written next.
  snapshotStarting,

  /// The pre-migration snapshot is whole and durable.
  snapshotTaken,

  /// The migrating marker, naming the snapshot, is down, durably.
  markerDown,

  /// The migration has committed and the WAL is checkpointed.
  migrated,

  /// The migrating marker is removed, durably: the migration succeeded.
  markerRemoved,
}

/// Why the database opened in safe mode. The names are the log codes.
enum SafeModeReason {
  /// A migration failed; the file was restored from its snapshot.
  migrationFailed,

  /// The pre-migration snapshot, or the migrating marker after it, could
  /// not be written; nothing was migrated and the file is untouched.
  snapshotFailed,

  /// A migration failed and the snapshot could not be put back; the
  /// snapshot itself is what safe mode reads. The next open retries the
  /// restore.
  restoreFailed,

  /// The file could not be opened, and no migration was due: it is not a
  /// database, it is newer than this build, or its creation failed.
  openFailed,
}

/// What [openWithSnapshot] produced.
sealed class DatabaseOpening<D extends GeneratedDatabase> {
  const DatabaseOpening();
}

/// The database, open and at the target version.
final class Opened<D extends GeneratedDatabase> extends DatabaseOpening<D> {
  const Opened(this.database);

  final D database;
}

/// Safe mode: [reason], and a read-only connection to the data when one
/// could be opened ([reader] is null when there is nothing to read).
final class SafeMode<D extends GeneratedDatabase> extends DatabaseOpening<D> {
  const SafeMode(this.reason, this.reader);

  final SafeModeReason reason;

  final ReadOnlyDatabase? reader;
}

/// The safe-mode connection: the file as it is, `query_only`, and never a
/// migration, because its schema version is the file's own.
final class ReadOnlyDatabase extends GeneratedDatabase {
  ReadOnlyDatabase._(super.executor, this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => throw StateError('safe mode never creates a schema'),
    onUpgrade: (_, _, _) => throw StateError('safe mode never migrates'),
  );
}

/// Opens the database [name] in [directory] with [open], migrating it to
/// [targetVersion] behind a snapshot:
///
/// 1. a restore an earlier open left unfinished is finished first, and so
///    is a migration it left unfinished, by restoring its snapshot;
/// 2. a file whose `user_version` is above 0 and below [targetVersion] is
///    copied with `VACUUM INTO`, and the migrating marker written, before
///    [open] runs the migration; a copy or a marker that fails stops there
///    ([SafeModeReason.snapshotFailed]);
/// 3. a migration that fails, or whose marker cannot be removed, is undone
///    by putting the snapshot back ([SafeModeReason.migrationFailed]), or,
///    when that fails too, safe mode reads the snapshot
///    ([SafeModeReason.restoreFailed]).
///
/// Safe mode never runs the migration again; the next launch does. Only
/// counts, durations and codes are logged.
///
/// [connect] makes the connection [open] receives: a background isolate
/// unless the caller passes another (the app passes its `DatabaseServer`).
/// After a creation or a migration the WAL is checkpointed, so the file's
/// header carries the new version for [openForBackground].
///
/// [restoring] is a backup restore's own reopen of the file it swapped in:
/// the restore marker is its own, naming the safety copy, and is left in
/// place, and so is a migration that fails, whose snapshot is not put back
/// ([SafeModeReason.migrationFailed], with no reader): the restore rolls
/// back to its safety copy instead.
///
/// [keepSnapshots] counts pre-migration snapshots only, never a safety copy.
/// [onStep] is the kill-point seam ([OpenStep], and [RollBackStep] for a
/// restore); null in the app.
Future<DatabaseOpening<D>> openWithSnapshot<D extends GeneratedDatabase>({
  required Directory directory,
  required String name,
  required int targetVersion,
  required D Function(QueryExecutor executor) open,
  required Log log,
  DatabaseLayout? layout,
  Connect connect = openDatabaseFile,
  SyncDirectory syncDirectory = fsyncDirectory,
  bool restoring = false,
  int keepSnapshots = defaultKeepSnapshots,
  @visibleForTesting StepHook? onStep,
}) async {
  final files = DatabaseFiles(directory, name: name, layout: layout);
  final dbPath = files.database.path;
  final timer = Stopwatch()..start();

  // A marker's temporary file goes whatever else is there: it is a marker
  // that never went down, so the marker that remains, if any, governs.
  // With none, nothing restores: a restore `.tmp` is only written while
  // the migrating or the restore marker is down, and a lone migrating
  // `.tmp` is a migration that never began.
  for (final (tmp, code) in [
    (files.restoreMarkerTmp, 'db.restoreMarkerTmpKept'),
    (files.migratingMarkerTmp, 'db.migratingMarkerTmpKept'),
  ]) {
    if (!tmp.existsSync()) continue;
    try {
      tmp.deleteSync();
    } on FileSystemException catch (e, s) {
      log.warning(code, error: e, stack: s);
    }
  }

  // A restore cut short is finished; a migration cut short (the migrating
  // marker, with no restore marker) is undone the same way, because the
  // file may hold part of it and nothing else has written since its
  // snapshot. The restore removes both markers.
  final (File, String)? pending;
  if (restoring) {
    // The restore's own marker: it stays until the restore has passed its
    // integrity check, or has been rolled back.
    pending = null;
  } else if (files.restoreMarker.existsSync()) {
    pending = (files.restoreMarker, 'restoring');
  } else if (files.migratingMarker.existsSync()) {
    pending = (files.migratingMarker, 'migrating');
    log.warning('db.migrationInterrupted');
  } else {
    pending = null;
  }
  if (pending case (final marker, final kind)) {
    // Nothing to restore from: read the file as it is, and leave the
    // marker, so no launch migrates over a restore that never ran.
    Future<SafeMode<D>> readAsItIs() async {
      int? fileVersion;
      try {
        fileVersion = await Isolate.run(() => _userVersion(dbPath));
      } catch (e, s) {
        log.error('db.probeFailed', error: e, stack: s);
      }
      return _safeMode(
        SafeModeReason.restoreFailed,
        files.database,
        fileVersion,
        log,
      );
    }

    final legacy = kind == 'restoring' ? legacyMarkerWord(files) : null;
    if (legacy != null) {
      // A LYCEUM 1.0.x swap cut short before this build was installed.
      final RecoveryOutcome outcome;
      try {
        outcome = recoverLegacySwap(
          files,
          legacy,
          syncDirectory: syncDirectory,
        );
      } catch (e, s) {
        passSimulatedCrash(e, s);
        log.error('db.restoreFailed', error: e, stack: s);
        return readAsItIs();
      }
      log.info(
        'db.restoreRecovered',
        fields: {'code': LogValue.code(outcome.name)},
      );
      if (outcome == RecoveryOutcome.nothingToRecover) return readAsItIs();
    } else {
      // The marker names its snapshot, or a backup restore's safety copy.
      // One that is neither (empty, another database's, a path) is
      // unreadable, and the restore takes the newest snapshot by write
      // order. One that names a copy not on disk restores nothing: never a
      // copy it did not name.
      var source = markedSource(files, marker);
      if (source == null) {
        final newest = snapshotsNewestFirst(files).firstOrNull;
        log.warning(
          'db.restoreMarkerUnreadable',
          fields: {
            'marker': LogValue.code(kind),
            'snapshotFound': LogValue.flag(newest != null),
          },
        );
        if (newest == null) return readAsItIs();
        source = (file: newest.$2, version: newest.$1);
      } else if (!source.file.existsSync()) {
        log.error(
          'db.restoreSnapshotMissing',
          fields: {'marker': LogValue.code(kind), ..._sourceFields(source)},
        );
        return readAsItIs();
      }
      if (!await _restore(files, source, log, syncDirectory, onStep)) {
        final copy = source.file.path;
        int? version = source.version;
        if (version == null) {
          try {
            version = await Isolate.run(() => _userVersion(copy));
          } catch (e, s) {
            log.error('db.probeFailed', error: e, stack: s);
          }
        }
        return _safeMode(
          SafeModeReason.restoreFailed,
          source.file,
          version,
          log,
        );
      }
    }
  }

  int? onDisk;
  try {
    onDisk = await Isolate.run(() => _userVersion(dbPath));
  } catch (e, s) {
    log.error('db.probeFailed', error: e, stack: s);
    return _safeMode(SafeModeReason.openFailed, null, null, log);
  }

  if (onDisk != null && onDisk > targetVersion) {
    // Newer than this build: nothing here may migrate it, in either
    // direction, so it is only read.
    log.error(
      'db.newerThanBuild',
      fields: {
        'from': LogValue.count(onDisk),
        'to': LogValue.count(targetVersion),
      },
    );
    return _safeMode(SafeModeReason.openFailed, files.database, onDisk, log);
  }

  final migrates = onDisk != null && onDisk > 0 && onDisk < targetVersion;
  if (migrates) {
    final from = onDisk;
    final snapshot = files.snapshot(from).path;
    final snapshots = files.snapshots.path;
    final pattern = files.snapshotName.pattern;
    final snapshotTimer = Stopwatch()..start();
    try {
      onStep?.call(OpenStep.snapshotStarting);
      final kept = await Isolate.run(
        () =>
            _takeSnapshot(dbPath, snapshots, snapshot, pattern, keepSnapshots),
      );
      syncDirectory(files.snapshots);
      onStep?.call(OpenStep.snapshotTaken);
      // The marker goes down once the snapshot is whole and durable, and
      // before the migration begins: a background open never sees the
      // file's new version without it.
      writeMarker(
        files.migratingMarker.path,
        files.snapshot(from).uri.pathSegments.last,
      );
      syncDirectory(files.migratingMarker.parent);
      onStep?.call(OpenStep.markerDown);
      log.info(
        'db.snapshot',
        fields: {
          'from': LogValue.count(from),
          'kept': LogValue.count(kept),
          'took': LogValue.duration(snapshotTimer.elapsed),
        },
      );
    } catch (e, s) {
      passSimulatedCrash(e, s);
      log.error('db.snapshotFailed', error: e, stack: s);
      if (files.migratingMarkerTmp.existsSync()) {
        try {
          files.migratingMarkerTmp.deleteSync();
        } on FileSystemException {
          // A lone `.tmp`: the next open deletes it.
        }
      }
      return _safeMode(
        SafeModeReason.snapshotFailed,
        files.database,
        from,
        log,
      );
    }
  }

  D? db;
  try {
    db = open(connect(files.database));
    // The first statement opens the connection, which runs the migration.
    await db.customSelect('SELECT 1').get();
    if (onDisk != targetVersion) await _checkpoint(db, log);
    if (migrates) onStep?.call(OpenStep.migrated);
    // Only now has the migration succeeded. A marker that cannot be
    // removed, durably, fails it: left in place, or brought back by a power
    // loss, it would restore the snapshot over the session's writes.
    if (migrates) {
      files.migratingMarker.deleteSync();
      syncDirectory(files.migratingMarker.parent);
      onStep?.call(OpenStep.markerRemoved);
    }
    log.info(
      'db.opened',
      fields: {
        'from': LogValue.count(onDisk ?? 0),
        'to': LogValue.count(targetVersion),
        'took': LogValue.duration(timer.elapsed),
      },
    );
    return Opened(db);
  } catch (e, s) {
    passSimulatedCrash(e, s);
    await _closeQuietly(db, log);
    if (!migrates) {
      log.error('db.openFailed', error: e, stack: s);
      return _safeMode(SafeModeReason.openFailed, files.database, onDisk, log);
    }
    log.error(
      'db.migrationFailed',
      error: e,
      stack: s,
      fields: {
        'from': LogValue.count(onDisk),
        'to': LogValue.count(targetVersion),
      },
    );
    // A restore's file: the restore rolls back to its safety copy, which
    // its marker names; the migrating marker goes with that rollback.
    if (restoring) {
      return _safeMode(SafeModeReason.migrationFailed, null, null, log);
    }
    final snapshot = (file: files.snapshot(onDisk), version: onDisk);
    if (!await _restore(files, snapshot, log, syncDirectory, onStep)) {
      return _safeMode(
        SafeModeReason.restoreFailed,
        files.snapshot(onDisk),
        onDisk,
        log,
      );
    }
    return _safeMode(
      SafeModeReason.migrationFailed,
      files.database,
      onDisk,
      log,
    );
  }
}

/// Moves the WAL into the file, so the header's `user_version` is the one
/// just written. A checkpoint that fails is logged and costs only a later
/// background open, which reads the header and is not ready until the next
/// checkpoint.
Future<void> _checkpoint(GeneratedDatabase db, Log log) async {
  try {
    await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
  } catch (e, s) {
    log.warning('db.checkpointFailed', error: e, stack: s);
  }
}

/// Why a background open did not open the database. The names are the log
/// codes.
enum NotReadyReason {
  /// There is no database file; only the UI's open creates one.
  noDatabase,

  /// A restore is pending (the restore marker, or its `.tmp` while it is
  /// written); only the UI's open finishes it.
  restorePending,

  /// A migration is under way, or was cut short (the migrating marker, or
  /// its `.tmp` while it is written); only the UI's open finishes or undoes
  /// it. The file's header may already carry the target.
  migrationPending,

  /// The file's `user_version` is not this build's: an older file waits for
  /// the UI's open to migrate it behind its snapshot, and a newer one is
  /// never touched.
  versionMismatch,

  /// The file is not a database, or the connection failed.
  openFailed,
}

/// What [openForBackground] produced.
sealed class BackgroundOpening<D extends GeneratedDatabase> {
  const BackgroundOpening();
}

/// The database, open at the target version on its own connection.
final class OpenedInBackground<D extends GeneratedDatabase>
    extends BackgroundOpening<D> {
  const OpenedInBackground(this.database);

  final D database;
}

/// Not opened, for [reason]; the caller retries later.
final class NotReady<D extends GeneratedDatabase> extends BackgroundOpening<D> {
  const NotReady(this.reason);

  final NotReadyReason reason;
}

/// Opens the database [name] in [directory] for background work: never a
/// snapshot, a migration, a restore or a creation.
///
/// It reads the restore and migrating markers (and their `.tmp`) and the
/// file's header first, without opening the database, so a file that is
/// missing, pending a restore or a migration, or whose header
/// `user_version` is not [targetVersion] is left exactly as it was (bytes,
/// size and modification time of the database, its `-wal`, `-shm` and
/// `snapshots/`). Otherwise it opens a connection on a background isolate
/// that never creates the file, reads the `user_version` through the WAL
/// and checks the markers again after it, sets the four pragmas and has
/// drift's migrations turned off. Anything else reports [NotReady].
///
/// Test seams, null in the app: [beforeConnect] runs after the early checks
/// and before the connection is opened; [afterVersionRead] runs on the
/// connection's isolate, with the database's path, after it has read the
/// version and before it checks the markers again. It must be sendable to
/// that isolate (a top-level function).
Future<BackgroundOpening<D>> openForBackground<D extends GeneratedDatabase>({
  required Directory directory,
  required String name,
  required int targetVersion,
  required D Function(QueryExecutor executor) open,
  required Log log,
  DatabaseLayout? layout,
  @visibleForTesting void Function()? beforeConnect,
  @visibleForTesting void Function(String databasePath)? afterVersionRead,
}) async {
  final files = DatabaseFiles(directory, name: name, layout: layout);
  final markers = _Markers.of(files);
  final NotReadyReason? early;
  int? headerVersion;
  final pending = markers.pending();
  if (pending != null) {
    early = pending;
  } else if (!files.database.existsSync()) {
    early = NotReadyReason.noDatabase;
  } else {
    try {
      headerVersion = _headerVersion(files.database);
    } on FileSystemException catch (e, s) {
      log.error('db.probeFailed', error: e, stack: s);
    }
    early = switch (headerVersion) {
      null => NotReadyReason.openFailed,
      final v when v != targetVersion => NotReadyReason.versionMismatch,
      _ => null,
    };
  }
  if (early != null) {
    return _notReady(early, headerVersion, targetVersion, log);
  }

  beforeConnect?.call();
  D? db;
  try {
    db = open(
      _backgroundConnection(
        files.database.path,
        markers,
        targetVersion,
        afterVersionRead,
      ),
    );
    await db.customSelect('SELECT 1').get();
    log.info(
      'db.backgroundOpened',
      fields: {'version': LogValue.count(targetVersion)},
    );
    return OpenedInBackground(db);
  } catch (e, s) {
    await _closeQuietly(db, log);
    final refused = switch (e) {
      DriftRemoteException(remoteCause: _Refused(:final reason)) => reason,
      _Refused(:final reason) => reason,
      _ => null,
    };
    if (refused == null) log.error('db.openFailed', error: e, stack: s);
    return _notReady(
      refused ?? NotReadyReason.openFailed,
      headerVersion,
      targetVersion,
      log,
    );
  }
}

NotReady<D> _notReady<D extends GeneratedDatabase>(
  NotReadyReason reason,
  int? version,
  int targetVersion,
  Log log,
) {
  log.info(
    'db.backgroundNotReady',
    fields: {
      'code': LogValue.code(reason.name),
      if (version != null) 'from': LogValue.count(version),
      'to': LogValue.count(targetVersion),
    },
  );
  return NotReady(reason);
}

/// The `user_version` in the file's header, read as plain bytes: no SQLite
/// connection, so no `-wal` or `-shm` is created or written. 0 for an empty
/// file; null when the file is not a SQLite database. The header can lag the
/// WAL until a checkpoint, which the UI's opener runs after creating or
/// migrating.
int? _headerVersion(File file) {
  final handle = file.openSync();
  try {
    final header = handle.readSync(100);
    if (header.isEmpty) return 0;
    const magic = 'SQLite format 3\u0000';
    if (header.length < 100 ||
        String.fromCharCodes(header, 0, magic.length) != magic) {
      return null;
    }
    return header.buffer.asByteData(header.offsetInBytes).getUint32(60);
  } finally {
    handle.closeSync();
  }
}

/// A background open that its own connection refused; [reason] says why.
final class _Refused implements Exception {
  const _Refused(this.reason);

  final NotReadyReason reason;

  @override
  String toString() => 'background open refused: ${reason.name}';
}

/// The marker paths a background open checks, sendable to its isolate.
final class _Markers {
  const _Markers(this.restoring, this.migrating);

  _Markers.of(DatabaseFiles files)
    : this(files.restoreMarker.path, files.migratingMarker.path);

  final String restoring;
  final String migrating;

  /// Why the markers stop a background open, or null when there are none.
  /// Anything at a marker's name counts, a file or not.
  NotReadyReason? pending() {
    bool present(String path) =>
        FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.notFound;
    if (present(restoring) || present('$restoring.tmp')) {
      return NotReadyReason.restorePending;
    }
    if (present(migrating) || present('$migrating.tmp')) {
      return NotReadyReason.migrationPending;
    }
    return null;
  }
}

/// The background open's connection: a drift isolate for one client,
/// stopped when that client closes.
QueryExecutor _backgroundConnection(
  String path,
  _Markers markers,
  int target,
  void Function(String path)? afterVersionRead,
) => DatabaseConnection.delayed(
  DriftIsolate.spawn(_checkedOpener(path, markers, target, afterVersionRead))
      .then((isolate) => isolate.connect(singleClientMode: true)),
);

/// Opens [path] only as it is, on the isolate as it starts:
///
/// - the markers are checked before the file is opened, so a restore under
///   way is never opened;
/// - `OpenMode.readWrite` never creates the file;
/// - the `user_version` is read through the WAL, and the markers are
///   checked again after it: the migrating marker is down from before a
///   migration writes until after it has succeeded, so a target version
///   read with no marker after it is never a migration's under way;
/// - the four pragmas are set, and drift's migrations are off, so it can
///   neither create nor upgrade.
///
/// A refusal or a failure becomes an empty in-memory executor whose opening
/// fails with it, so the client receives the cause and closing still stops
/// the isolate. Top level, so the closure sent to the isolate holds only
/// its arguments.
QueryExecutor Function() _checkedOpener(
  String path,
  _Markers markers,
  int target,
  void Function(String path)? afterVersionRead,
) => () {
  final Object cause;
  try {
    if (markers.pending() case final pending?) throw _Refused(pending);
    final raw = sqlite3.open(path, mode: OpenMode.readWrite);
    try {
      if (raw.userVersion != target) {
        throw const _Refused(NotReadyReason.versionMismatch);
      }
      afterVersionRead?.call(path);
      if (markers.pending() case final pending?) throw _Refused(pending);
      applyPragmas(raw);
    } catch (_) {
      raw.close();
      rethrow;
    }
    return NativeDatabase.opened(raw, enableMigrations: false);
  } catch (e) {
    cause = e;
  }
  return NativeDatabase.memory(setup: (_) => throw cause);
};

/// The file's `user_version`, or null when there is no file.
int? _userVersion(String path) {
  if (!File(path).existsSync()) return null;
  final raw = sqlite3.open(path, mode: OpenMode.readWrite);
  try {
    return raw.userVersion;
  } finally {
    raw.close();
  }
}

/// Writes the `VACUUM INTO` copy of [dbPath] to [snapshot] through a
/// temporary file, so a half-written copy never carries a snapshot's name,
/// then keeps it and the [keep] − 1 newest others by write order. Returns
/// how many are kept. Only names matching [pattern] (pre-migration
/// snapshots) are counted or removed: a safety copy never is.
int _takeSnapshot(
  String dbPath,
  String snapshots,
  String snapshot,
  String pattern,
  int keep,
) {
  Directory(snapshots).createSync(recursive: true);
  final partial = File('$snapshot.partial');
  if (partial.existsSync()) partial.deleteSync();
  final raw = sqlite3.open(dbPath, mode: OpenMode.readWrite);
  try {
    raw.execute('VACUUM INTO ?', [partial.path]);
  } finally {
    raw.close();
  }
  flushFile(partial);
  partial.renameSync(snapshot);

  // The snapshot just written always stays, plus the newest others by
  // write order: a file older than every snapshot on disk (an old backup
  // restored) still keeps its own. A snapshot that cannot be deleted stays;
  // it never fails the snapshot just taken.
  final name = RegExp(pattern);
  final found = [
    for (final entry in Directory(snapshots).listSync())
      if (entry is File && entry.path != snapshot)
        if (name.firstMatch(entry.uri.pathSegments.last) case final m?)
          (int.tryParse(m[1]!) ?? 0, entry, entry.lastModifiedSync()),
  ];
  found.sort((a, b) {
    final byTime = b.$3.compareTo(a.$3);
    return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
  });
  final others = [for (final (_, file, _) in found) file];
  final keepOthers = keep < 1 ? 0 : keep - 1;
  for (final file in others.skip(keepOthers)) {
    for (final path in [file.path, '${file.path}-wal', '${file.path}-shm']) {
      try {
        if (File(path).existsSync()) File(path).deleteSync();
      } on FileSystemException {
        // Kept until a later rotation manages it.
      }
    }
  }
  return 1 + others.take(keepOthers).length;
}

Map<String, LogValue> _sourceFields(RestoreSource source) =>
    switch (source.version) {
      final v? => {'version': LogValue.count(v)},
      null => {'source': LogValue.code('safetyCopy')},
    };

/// [restoreFrom] with the opener's log codes: `db.restored` when it
/// completed, `db.restoreFailed` when it did not. Returns whether it
/// completed.
Future<bool> _restore(
  DatabaseFiles files,
  RestoreSource source,
  Log log,
  SyncDirectory syncDirectory,
  StepHook? onStep,
) async {
  final timer = Stopwatch()..start();
  try {
    await restoreFrom(
      files,
      source,
      syncDirectory: syncDirectory,
      onStep: onStep,
    );
  } catch (e, s) {
    passSimulatedCrash(e, s);
    log.error('db.restoreFailed', error: e, stack: s);
    return false;
  }
  log.info(
    'db.restored',
    fields: {
      ..._sourceFields(source),
      'took': LogValue.duration(timer.elapsed),
    },
  );
  return true;
}

/// A backup restore's roll back with the opener's log codes: puts the
/// safety copy back as the database ([rollBack]). The database must be
/// closed. Returns whether it completed; when it did not, the marker stays
/// for the next open. The safety copy stays (until a backup covers it).
Future<bool> restoreSafetyCopy({
  required Directory directory,
  required String name,
  required Log log,
  DatabaseLayout? layout,
  SyncDirectory syncDirectory = fsyncDirectory,
}) async {
  final files = DatabaseFiles(directory, name: name, layout: layout);
  if (!files.safetyCopy.existsSync()) {
    log.error('db.safetyCopyMissing');
    return false;
  }
  return _restore(
    files,
    (file: files.safetyCopy, version: null),
    log,
    syncDirectory,
    null,
  );
}

/// Whether [directory] holds a pre-migration snapshot that
/// [resetFromSnapshot] can put back.
bool hasSnapshot(
  Directory directory, {
  required String name,
  DatabaseLayout? layout,
}) =>
    snapshotsNewestFirst(DatabaseFiles(directory, name: name, layout: layout))
        .isNotEmpty;

/// Safe mode's "Reset from the safety copy": puts the newest snapshot by
/// write order back as the database, the way a failed migration's restore
/// does (the marker, the synced copy renamed over the file, the stale
/// `-wal` and `-shm` removed, the markers removed, each step synced), so a
/// reset cut short is finished by the next open. Whatever the file held
/// after the snapshot is lost: the caller has confirmed that.
///
/// [reader], safe mode's connection, is closed first, before any file is
/// touched; [beforeFiles] (a test seam, null in the app) runs then. Returns
/// whether the snapshot is back; with no snapshot, or when the restore
/// fails, the file is left as it was (a restore cut short keeps its marker
/// for the next open). The snapshots stay. The next [openWithSnapshot]
/// migrates the file when the snapshot is older than the build.
Future<bool> resetFromSnapshot({
  required Directory directory,
  required String name,
  required Log log,
  DatabaseLayout? layout,
  ReadOnlyDatabase? reader,
  SyncDirectory syncDirectory = fsyncDirectory,
  @visibleForTesting Future<void> Function()? beforeFiles,
}) async {
  await _closeQuietly(reader, log);
  await beforeFiles?.call();
  final files = DatabaseFiles(directory, name: name, layout: layout);
  final newest = snapshotsNewestFirst(files).firstOrNull;
  if (newest == null) {
    log.warning('db.resetNoSnapshot');
    return false;
  }
  final snapshot = (file: newest.$2, version: newest.$1);
  if (!await _restore(files, snapshot, log, syncDirectory, null)) {
    return false;
  }
  log.info('db.reset', fields: {'version': LogValue.count(newest.$1)});
  return true;
}

/// Safe mode's "Erase and start again": removes the database, so the next
/// [openWithSnapshot] creates an empty one. Every row on the device goes:
/// the caller has confirmed that.
///
/// [reader] is closed first, before any file is touched; [beforeFiles] (a
/// test seam) runs then. The `-wal`, `-shm` and `-journal` go before the
/// file, so a stale WAL can never be replayed onto the new database; then
/// the file and a restore's copy; then the restore and migrating markers
/// with their `.tmp`, so no open restores over the new database; then the
/// directory is synced. The snapshots stay: they are the last copy of the
/// data, and a later reset can still use them. Returns whether everything
/// went; a file that cannot be removed stops there (logged).
Future<bool> eraseDatabase({
  required Directory directory,
  required String name,
  required Log log,
  DatabaseLayout? layout,
  ReadOnlyDatabase? reader,
  SyncDirectory syncDirectory = fsyncDirectory,
  @visibleForTesting Future<void> Function()? beforeFiles,
}) async {
  await _closeQuietly(reader, log);
  await beforeFiles?.call();
  final files = DatabaseFiles(directory, name: name, layout: layout);
  final db = files.database.path;
  try {
    for (final file in [
      File('$db-wal'),
      File('$db-shm'),
      File('$db-journal'),
      files.database,
      files.restoreCopy,
      files.restoreMarker,
      files.restoreMarkerTmp,
      files.migratingMarker,
      files.migratingMarkerTmp,
    ]) {
      if (file.existsSync()) file.deleteSync();
    }
    syncDirectory(files.directory);
  } catch (e, s) {
    log.error('db.recreateFailed', error: e, stack: s);
    return false;
  }
  log.info('db.recreated');
  return true;
}

/// Logs safe mode and opens [file] read-only at [version], when there is
/// one to read.
Future<SafeMode<D>> _safeMode<D extends GeneratedDatabase>(
  SafeModeReason reason,
  File? file,
  int? version,
  Log log,
) async {
  ReadOnlyDatabase? reader;
  if (file != null && version != null && version > 0 && file.existsSync()) {
    reader = ReadOnlyDatabase._(
      NativeDatabase.createInBackground(file, setup: _readOnlyPragmas),
      version,
    );
    try {
      await reader.customSelect('SELECT 1').get();
    } catch (e, s) {
      log.error('db.safeModeOpenFailed', error: e, stack: s);
      await _closeQuietly(reader, log);
      reader = null;
    }
  }
  log.warning(
    'db.safeMode',
    fields: {
      'code': LogValue.code(reason.name),
      'readable': LogValue.flag(reader != null),
    },
  );
  return SafeMode(reason, reader);
}

void _readOnlyPragmas(Database db) {
  db
    ..execute('PRAGMA busy_timeout = 5000')
    ..execute('PRAGMA query_only = ON');
}

Future<void> _closeQuietly(GeneratedDatabase? db, Log log) async {
  if (db == null) return;
  try {
    await db.close();
  } catch (e, s) {
    log.warning('db.closeFailed', error: e, stack: s);
  }
}
