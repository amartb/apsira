// From relay lib/data/db/restore_swap.dart @ 09b28810 and the restore half of
// relay lib/data/db/opener.dart @ 09b28810 (`_restore`, `_markedSource`,
// `_snapshotsNewestFirst`, `_writeMarker`), with viaticum
// lib/data/db/restore_swap.dart @ 78d38e0's `integrityCheckPasses` and lyceum
// lib/data/db/restore_swap.dart @ 9f4ff27's step seam, refusals and recovery
// of its own markers (D-APK-018). Plain Dart: no Flutter import (AC-13.5).
/// The file side of a backup restore: the safety copy, the swap of the
/// staged database into place, and the marker that covers it.
///
/// In order, each step durable before the next:
///
/// 1. [beginRestore], while the database is still open: the restore
///    marker's `.tmp`, naming the safety copy, flushed. Background opens
///    back off from it at once. A launch that finds it alone deletes it and
///    opens the file untouched: the restore never began.
/// 2. [writeSafetyCopy], once the database is closed: the file, byte for
///    byte, into the safety copy through a synced `.partial`. An earlier
///    restore's copy found there is first renamed to a kept name of its own
///    (`<name>.safety-<n>.db`), never overwritten.
/// 3. [armRestore]: the `.tmp` renamed into the marker. From here a launch
///    that finds the marker puts the safety copy back (the rollback).
/// 4. [swapIn]: the staged database copied beside the file, synced and
///    renamed over it, and the old file's `-wal`, `-shm` and `-journal`
///    removed, so none of them is replayed onto it.
/// 5. Then the restore reopens the file (`openWithSnapshot(restoring:
///    true)`, which migrates it behind its snapshot), rebuilds the derived
///    data and checks its integrity; [finishRestore] removes the marker only
///    after all of that has passed. A failure rolls back with [rollBack].
///
/// [abandonRestore] undoes steps 1 and 2 when the restore stops before the
/// marker is down. Every rename and removal is followed by an fsync of its
/// directory. Each step calls `onStep` with its [SwapStep] once it is done:
/// the kill-point seam (null in the app).
///
/// Each restore's safety copy holds data no backup may hold, so none is
/// overwritten or removed until a successful backup has covered it
/// ([dropCoveredSafetyCopies]). Only the newest is the marker's safety copy,
/// the one a roll back puts back.
///
/// [recoverInterruptedRestore] also reads the marker a LYCEUM 1.0.x swap
/// left (the word `swap` or `rollback`) by LYCEUM's own rules.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

import 'fsync.dart';
import 'layout.dart';
import 'step_hook.dart';

/// The steps of a restore swap, in order; each is named to `onStep` once it
/// is done.
enum SwapStep {
  /// [beginRestore]: the marker's `.tmp` is written.
  begun,

  /// [writeSafetyCopy]: the safety copy is whole and durable.
  safetyCopyWritten,

  /// [armRestore]: the marker is down.
  armed,

  /// [swapIn]: the staged database is copied beside the file and synced.
  stagedWritten,

  /// [swapIn]: the copy is renamed over the file.
  renamedIn,

  /// [swapIn]: the old file's `-wal`, `-shm` and `-journal` are gone, durably.
  staleCleared,

  /// [finishRestore]: the marker is removed, durably.
  finished,
}

/// The steps of putting a copy back as the database ([rollBack], and the
/// opener's restore of a pre-migration snapshot), in order.
enum RollBackStep {
  /// The restore marker, naming the copy, is down.
  markerDown,

  /// The copy is written beside the file and synced.
  copyWritten,

  /// The copy is renamed over the file.
  renamedIn,

  /// The failed attempt's `-wal`, `-shm` and `-journal` are gone, durably.
  staleCleared,

  /// The migrating and the restore markers are removed, durably.
  markersRemoved,
}

/// What [recoverInterruptedRestore] found and did.
enum RecoveryOutcome {
  /// No marker: nothing was under way (a lone `.tmp` is removed).
  none,

  /// A LYCEUM swap that had not moved the live file: it stays as it was.
  notBegun,

  /// A LYCEUM swap that had renamed the staged file in: the restored data
  /// stays.
  restored,

  /// The safety copy is the live file again.
  rolledBack,

  /// A pre-migration snapshot (a migration cut short, or a marker that
  /// named one) is the live file again.
  snapshotRestored,

  /// The marker names a copy that is not on disk, or there is nothing to
  /// put back: nothing was changed and the marker is left.
  nothingToRecover,
}

/// Step 1: the restore marker's `.tmp`, naming the safety copy, written and
/// flushed while the database is still open, so no background open starts
/// once it closes. It is not renamed yet: alone, it is a restore that never
/// began.
void beginRestore(DatabaseFiles files, {StepHook? onStep}) {
  files.restoreMarkerTmp.parent.createSync(recursive: true);
  files.restoreMarkerTmp.writeAsStringSync(files.safetyCopyName, flush: true);
  onStep?.call(SwapStep.begun);
}

/// Step 2: copies the closed database file into the safety copy through
/// `<safety copy>.partial`, synced and renamed, then syncs the snapshots'
/// directory. An earlier restore's copy at that name is kept first: it is
/// renamed to the next free `<name>.safety-<n>.db` (its modification time,
/// the one the backup log is compared with, unchanged) and the directory
/// synced. Throws a [FileSystemException] when it cannot, and when the
/// file's `-wal` is not empty: its commits would be missing from a copy of
/// the file alone.
Future<void> writeSafetyCopy(
  DatabaseFiles files, {
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) async {
  final wal = File('${files.database.path}-wal');
  if (wal.existsSync() && wal.lengthSync() > 0) {
    throw FileSystemException('the database has a WAL to checkpoint', wal.path);
  }
  final source = files.database.path;
  final target = files.safetyCopy.path;
  files.safetyCopy.parent.createSync(recursive: true);
  if (files.safetyCopy.existsSync()) {
    files.safetyCopy.renameSync(_nextKeptSafetyCopy(files).path);
    syncDirectory(files.safetyCopy.parent);
  }
  // The copy, which can be large, runs off this isolate.
  await Isolate.run(() {
    final partial = File('$target.partial');
    if (partial.existsSync()) partial.deleteSync();
    File(source).copySync(partial.path);
    flushFile(partial);
    partial.renameSync(target);
  });
  syncDirectory(files.safetyCopy.parent);
  onStep?.call(SwapStep.safetyCopyWritten);
}

/// Step 3: the marker goes down, naming the safety copy: its `.tmp` is
/// renamed into place and the directory synced.
void armRestore(
  DatabaseFiles files, {
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) {
  files.restoreMarkerTmp.renameSync(files.restoreMarker.path);
  syncDirectory(files.restoreMarker.parent);
  onStep?.call(SwapStep.armed);
}

/// Step 4: the [staged] database ([DatabaseFiles.stagedDatabase] by
/// default) copied beside the file, synced, renamed over it, and the old
/// file's `-wal`, `-shm` and `-journal` removed; then the directory is
/// synced. The database must be closed and the marker down ([armRestore]).
///
/// Throws a [FileSystemException], touching nothing, when [staged] is not a
/// SQLite database or its `-wal` holds commits (LYCEUM's refusals).
Future<void> swapIn(
  DatabaseFiles files, {
  File? staged,
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) async {
  final from = (staged ?? files.stagedDatabase).path;
  if (databaseHeaderVersion(File(from)) == null) {
    throw FileSystemException('the staged file is not a database', from);
  }
  final stagedWal = File('$from-wal');
  if (stagedWal.existsSync() && stagedWal.lengthSync() > 0) {
    throw FileSystemException('a WAL to checkpoint first', stagedWal.path);
  }
  final copy = files.restoreCopy.path;
  await Isolate.run(() {
    if (File(copy).existsSync()) File(copy).deleteSync();
    File(from).copySync(copy);
    flushFile(File(copy));
  });
  onStep?.call(SwapStep.stagedWritten);
  File(copy).renameSync(files.database.path);
  onStep?.call(SwapStep.renamedIn);
  _removeStale(files.database.path);
  syncDirectory(files.database.parent);
  onStep?.call(SwapStep.staleCleared);
}

/// The end of a restore that passed: the marker is removed and the
/// directory synced, so the restored file stands.
void finishRestore(
  DatabaseFiles files, {
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) {
  files.restoreMarker.deleteSync();
  syncDirectory(files.restoreMarker.parent);
  onStep?.call(SwapStep.finished);
}

/// Undoes [beginRestore] and a partial [writeSafetyCopy] when the restore
/// stops before [armRestore]: the file was never touched. A safety copy
/// already written stays; it is the newest copy of the data.
void abandonRestore(
  DatabaseFiles files, {
  SyncDirectory syncDirectory = fsyncDirectory,
}) {
  for (final file in [
    files.restoreMarkerTmp,
    File('${files.safetyCopy.path}.partial'),
  ]) {
    if (file.existsSync()) file.deleteSync();
  }
  syncDirectory(files.directory);
}

/// A backup restore's roll back: puts the safety copy back as the database,
/// the way a failed migration's restore does (the marker naming it, the
/// synced copy renamed over the file, the stale `-wal` and `-shm` removed,
/// the migrating and the restore markers removed, each step synced), so a
/// roll back cut short is finished by the next open. The database must be
/// closed. Throws [StateError] when there is no safety copy, touching
/// nothing; any other failure leaves the marker for the next open. The
/// safety copy stays (until a backup covers it).
Future<void> rollBack(
  DatabaseFiles files, {
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) async {
  if (!files.safetyCopy.existsSync()) {
    throw StateError('no safety copy to roll back to');
  }
  await restoreFrom(
    files,
    (file: files.safetyCopy, version: null),
    syncDirectory: syncDirectory,
    onStep: onStep,
  );
}

/// Finishes a restore, a roll back or a migration an earlier run cut short,
/// before anything opens the database, without logging (the opener does
/// the same with its log codes). A lone marker `.tmp` goes; a restore
/// marker puts back the copy it names (the newest snapshot when it names
/// none); a migrating marker puts back its snapshot; a LYCEUM marker
/// (`swap`, `rollback`) is recovered by LYCEUM's rules, and its staging
/// directory goes. Run it only when no restore is under way in this
/// process.
Future<RecoveryOutcome> recoverInterruptedRestore(
  DatabaseFiles files, {
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) async {
  var removed = false;
  for (final tmp in [files.restoreMarkerTmp, files.migratingMarkerTmp]) {
    if (tmp.existsSync()) {
      tmp.deleteSync();
      removed = true;
    }
  }
  if (removed) syncDirectory(files.directory);

  final File marker;
  if (files.restoreMarker.existsSync()) {
    marker = files.restoreMarker;
    if (legacyMarkerWord(files) case final word?) {
      return recoverLegacySwap(files, word, syncDirectory: syncDirectory);
    }
  } else if (files.migratingMarker.existsSync()) {
    marker = files.migratingMarker;
  } else {
    return RecoveryOutcome.none;
  }
  var source = markedSource(files, marker);
  if (source == null) {
    final newest = snapshotsNewestFirst(files).firstOrNull;
    if (newest == null) return RecoveryOutcome.nothingToRecover;
    source = (file: newest.$2, version: newest.$1);
  } else if (!source.file.existsSync()) {
    return RecoveryOutcome.nothingToRecover;
  }
  await restoreFrom(
    files,
    source,
    syncDirectory: syncDirectory,
    onStep: onStep,
  );
  return source.version == null
      ? RecoveryOutcome.rolledBack
      : RecoveryOutcome.snapshotRestored;
}

/// Every safety copy on disk, newest first: the marker's (`<name>.safety.db`,
/// or the layout's), then the kept copies of earlier restores
/// (`<name>.safety-<n>.db`) by number, highest first.
List<File> safetyCopies(DatabaseFiles files) {
  final dir = files.safetyCopy.parent;
  if (!dir.existsSync()) return const [];
  final kept = <(int, File)>[];
  File? newest;
  for (final entry in dir.listSync(followLinks: false)) {
    if (entry is! File) continue;
    if (entry.path == files.safetyCopy.path) {
      newest = entry;
    } else if (files.keptSafetyCopyName.firstMatch(_baseName(entry))
        case final match?) {
      kept.add((int.parse(match[1]!), entry));
    }
  }
  kept.sort((a, b) => b.$1.compareTo(a.$1));
  return [?newest, for (final (_, file) in kept) file];
}

/// Removes every safety copy a successful backup has covered: written (its
/// modification time, which the restore sets from its clock) before
/// [latestOkBackupStart], the start of the newest successful backup, in
/// milliseconds since the epoch. A copy no backup has covered stays, and so
/// does the newest while a restore marker, or its `.tmp`, names it. The
/// directory is synced after a removal. Returns how many went.
int dropCoveredSafetyCopies(
  DatabaseFiles files, {
  required int latestOkBackupStart,
  SyncDirectory syncDirectory = fsyncDirectory,
}) {
  final named =
      files.restoreMarker.existsSync() || files.restoreMarkerTmp.existsSync();
  var dropped = 0;
  for (final copy in safetyCopies(files)) {
    if (named && copy.path == files.safetyCopy.path) continue;
    final written = copy.lastModifiedSync().millisecondsSinceEpoch;
    if (latestOkBackupStart <= written) continue;
    copy.deleteSync();
    dropped++;
  }
  if (dropped > 0) syncDirectory(files.safetyCopy.parent);
  return dropped;
}

/// Removes the staged database and its directory, whatever the outcome.
void discardStaging(DatabaseFiles files) {
  if (files.staging.existsSync()) files.staging.deleteSync(recursive: true);
}

/// The `user_version` in [file]'s header (bytes 60 to 63, big-endian),
/// read as plain bytes, no SQLite connection: what a staged database says
/// its schema is. Null when the file is missing or not a SQLite database.
int? databaseHeaderVersion(File file) {
  if (!file.existsSync()) return null;
  final handle = file.openSync();
  try {
    final header = handle.readSync(100);
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

/// Whether SQLite's `PRAGMA integrity_check` finds [file] sound, read-only
/// on a background isolate. A file SQLite cannot open or read is not.
Future<bool> integrityCheckPasses(File file) {
  final path = file.path;
  return Isolate.run(() {
    try {
      final raw = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        final rows = raw.select('PRAGMA integrity_check');
        return rows.length == 1 && rows.single.values.single == 'ok';
      } finally {
        raw.close();
      }
    } on Object {
      return false;
    }
  });
}

// ---------------------------------------------------------------------------
// Shared with the opener (`opener.dart`), not exported.

/// What a restore puts back: a pre-migration snapshot, by its [version],
/// or a backup restore's safety copy, whose version is null.
typedef RestoreSource = ({File file, int? version});

/// The snapshots of [files], as (version, file), newest written first; a
/// tie goes to the higher version. Only pre-migration snapshots: never a
/// safety copy, which has a name of its own.
List<(int, File)> snapshotsNewestFirst(DatabaseFiles files) {
  final dir = files.snapshots;
  if (!dir.existsSync()) return const [];
  final name = files.snapshotName;
  final found = [
    for (final entry in dir.listSync())
      if (entry is File)
        if (name.firstMatch(_baseName(entry)) case final m?)
          if (int.tryParse(m[1]!) case final version?)
            (version, entry, entry.lastModifiedSync()),
  ];
  found.sort((a, b) {
    final byTime = b.$3.compareTo(a.$3);
    return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
  });
  return [for (final (version, file, _) in found) (version, file)];
}

/// The copy [marker] (the restore or the migrating marker) names: a
/// snapshot's base name (`<name>.pre-v<N>.db`), a bare version number (the
/// P0 form), or the safety copy's base name. Null when it names none
/// (empty, another name, a path) or cannot be read.
RestoreSource? markedSource(DatabaseFiles files, File marker) {
  final String content;
  try {
    content = String.fromCharCodes(marker.readAsBytesSync()).trim();
  } on FileSystemException {
    return null;
  }
  if (content == files.safetyCopyName) {
    return (file: files.safetyCopy, version: null);
  }
  int? version;
  if (files.snapshotName.firstMatch(content) case final m?) {
    // Too many digits for an int is not a snapshot's name either.
    version = int.tryParse(m[1]!);
  } else if (RegExp(r'^\d{1,9}$').hasMatch(content)) {
    version = int.parse(content);
  }
  return version == null
      ? null
      : (file: files.snapshot(version), version: version);
}

/// Writes [content] to [marker] through `<marker>.tmp`, flushed (an
/// fsync) and renamed, so the marker is whole or absent.
File writeMarker(String marker, String content) {
  final tmp = File('$marker.tmp')..writeAsStringSync(content, flush: true);
  return tmp.renameSync(marker);
}

/// Puts [source] (a snapshot, or a restore's safety copy) back as the
/// database: the marker first, naming it, written to its temporary name,
/// flushed and renamed, so it is whole or absent; then a synced copy
/// renamed over the file; then the failed attempt's `-wal` and `-shm` go,
/// so none of it is ever replayed onto the restored file; then the
/// migrating marker, and the restore marker last. The directory is synced
/// after the marker's rename, after the file's rename and the stale files'
/// removal, and after the markers' removal, so each step is durable before
/// the next. Throws when a step fails; the marker then stays for the next
/// open.
Future<void> restoreFrom(
  DatabaseFiles files,
  RestoreSource source, {
  required SyncDirectory syncDirectory,
  StepHook? onStep,
}) async {
  final snapshot = source.file.path;
  final copy = files.restoreCopy.path;
  final dbPath = files.database.path;
  final markerFile = writeMarker(
    files.restoreMarker.path,
    _baseName(source.file),
  );
  syncDirectory(files.directory);
  onStep?.call(RollBackStep.markerDown);
  // The copy, which can be large, runs off this isolate.
  await Isolate.run(() {
    if (File(copy).existsSync()) File(copy).deleteSync();
    File(snapshot).copySync(copy);
    flushFile(File(copy));
  });
  onStep?.call(RollBackStep.copyWritten);
  File(copy).renameSync(dbPath);
  onStep?.call(RollBackStep.renamedIn);
  _removeStale(dbPath);
  syncDirectory(files.directory);
  onStep?.call(RollBackStep.staleCleared);
  if (files.migratingMarker.existsSync()) files.migratingMarker.deleteSync();
  markerFile.deleteSync();
  syncDirectory(files.directory);
  onStep?.call(RollBackStep.markersRemoved);
}

/// The word of a LYCEUM 1.0.x restore marker (`swap` or `rollback`), or null
/// when the marker is not one.
String? legacyMarkerWord(DatabaseFiles files) {
  try {
    final word = files.restoreMarker.readAsStringSync().trim();
    return word == _swap || word == _rollback ? word : null;
  } on FileSystemException {
    return null;
  }
}

const String _swap = 'swap';
const String _rollback = 'rollback';

/// LYCEUM's recovery of its own swap (`restore_swap.dart` @ 9f4ff27), which
/// renamed the live file into the safety copy and the staged file in: before
/// the live file moved it stays; between the two renames the safety copy is
/// put back; after them the restored file stays; a roll back puts the safety
/// copy back. Then the marker goes, and so does the staging directory
/// unless there was nothing to recover.
RecoveryOutcome recoverLegacySwap(
  DatabaseFiles files,
  String word, {
  required SyncDirectory syncDirectory,
}) {
  final outcome = _recoverLegacy(files, word, syncDirectory);
  if (outcome != RecoveryOutcome.nothingToRecover &&
      files.staging.existsSync()) {
    files.staging.deleteSync(recursive: true);
    syncDirectory(files.directory);
  }
  return outcome;
}

RecoveryOutcome _recoverLegacy(
  DatabaseFiles files,
  String word,
  SyncDirectory syncDirectory,
) {
  final live = files.database.existsSync();
  final safety = files.safetyCopy.existsSync();
  void safetyCopyIn() {
    _removeStale(files.database.path);
    syncDirectory(files.directory);
    files.safetyCopy.renameSync(files.database.path);
    syncDirectory(files.safetyCopy.parent);
    syncDirectory(files.directory);
  }

  final RecoveryOutcome outcome;
  if (word == _rollback) {
    if (safety) {
      safetyCopyIn();
    } else if (!live) {
      return RecoveryOutcome.nothingToRecover;
    }
    outcome = RecoveryOutcome.rolledBack;
  } else if (live) {
    // The staged file's rename in consumes it: with it still there, the
    // live file was never moved.
    outcome = files.stagedDatabase.existsSync()
        ? RecoveryOutcome.notBegun
        : RecoveryOutcome.restored;
  } else if (safety) {
    safetyCopyIn();
    outcome = RecoveryOutcome.rolledBack;
  } else if (files.stagedDatabase.existsSync()) {
    // A fresh install's swap: there was no live file to keep.
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final stale = File('${files.stagedDatabase.path}$suffix');
      if (stale.existsSync()) stale.deleteSync();
    }
    files.stagedDatabase.renameSync(files.database.path);
    syncDirectory(files.staging);
    syncDirectory(files.directory);
    outcome = RecoveryOutcome.restored;
  } else {
    return RecoveryOutcome.nothingToRecover;
  }
  files.restoreMarker.deleteSync();
  syncDirectory(files.directory);
  return outcome;
}

/// Removes the `-wal`, `-shm` and `-journal` beside the file at [dbPath].
void _removeStale(String dbPath) {
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final stale = File('$dbPath$suffix');
    if (stale.existsSync()) stale.deleteSync();
  }
}

/// Where [writeSafetyCopy] keeps an earlier restore's copy: the kept name
/// one above the highest on disk, so none is ever reused while it stands.
File _nextKeptSafetyCopy(DatabaseFiles files) {
  var highest = 0;
  for (final copy in safetyCopies(files)) {
    final n = int.tryParse(
      files.keptSafetyCopyName.firstMatch(_baseName(copy))?[1] ?? '',
    );
    if (n != null && n > highest) highest = n;
  }
  return File(
    '${files.safetyCopy.parent.path}/${files.name}.safety-${highest + 1}.db',
  );
}

String _baseName(File file) => file.uri.pathSegments.last;
