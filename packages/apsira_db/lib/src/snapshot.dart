// From relay lib/data/db/backup_snapshot.dart @ 09b28810, with viaticum
// lib/data/db/backup_snapshot.dart @ 78d38e0's `readSnapshot` and
// `SnapshotInfo`, app-neutral; the `.tmp`, flush, rename and directory sync
// are new (D-APK-018, kill point KP-S1). Plain Dart: no Flutter import
// (AC-13.5).
/// The database snapshot of a backup or an export: one self-contained,
/// consistent copy of the database file, taken with `VACUUM INTO` on the
/// connection the app already uses, while the app keeps reading and writing.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fsync.dart';
import 'step_hook.dart';

/// The steps of [snapshot], in order; each is named to `onStep` once done.
enum SnapshotStep {
  /// The target's stale files and an earlier `.tmp` are gone; `VACUUM INTO`
  /// runs next.
  started,

  /// `<path>.tmp` is whole, its left-out tables emptied, and flushed.
  tmpWritten,

  /// The `.tmp` is renamed to the snapshot's path.
  renamed,

  /// The rename is durable (the directory synced).
  synced,
}

/// Copies [db] into the file [path] with `VACUUM INTO`.
///
/// `VACUUM INTO` reads in one read transaction, so the copy is the
/// database at one commit: a write that commits meanwhile, on this
/// connection's isolate or any other, is in it entirely or not at all,
/// and an open write transaction is not in it. The copy is in rollback
/// journal mode (no `-wal` beside it), compacted, and its `user_version`
/// is the source's. It cannot run inside a transaction (SQLite's rule for
/// `VACUUM`); the error says so.
///
/// The copy is written to `<path>.tmp`, the [leavesOut] tables emptied in
/// it, flushed, renamed to [path], and the directory synced
/// ([syncDirectory]): a crash at any point leaves either no file at [path]
/// or a whole snapshot, never a partial one under its name. A `.tmp` an
/// earlier run left, and a file at [path] with any `-journal`, `-wal` or
/// `-shm` beside it, are deleted first: SQLite refuses a target that exists
/// and would treat a stale hot journal as the new file's own. The parent
/// directory is created when missing.
///
/// Before anything is deleted, [path] is checked against every file
/// `PRAGMA database_list` reports for [db]: when [path], its `.tmp`, or a
/// `-journal`, `-wal` or `-shm` beside either, is one of those files or one
/// beside them, compared by canonical path (symbolic links and `..`
/// resolved), it throws [SnapshotTargetIsLive] and touches nothing. A
/// snapshot's base name is often the live one's, so a wrong directory would
/// otherwise delete the live database under its open connection. That is a
/// caller's bug, so it is thrown, not returned.
///
/// [leavesOut] (RELAY's `snapshotLeavesOut`, the VIATICUM copy: a
/// disposable cache of another app's data, never backed up or exported)
/// names tables emptied in the copy alone, in one transaction with
/// `secure_delete` on, so no row of theirs stays in the file's free pages;
/// the live database is never written, and a copy whose schema lacks them
/// is left as it is.
Future<void> snapshot(
  GeneratedDatabase db,
  String path, {
  Iterable<String> leavesOut = const [],
  SyncDirectory syncDirectory = fsyncDirectory,
  StepHook? onStep,
}) async {
  final live = {
    for (final row in await db.customSelect('PRAGMA database_list').get())
      if (row.read<String?>('file') case final file? when file.isNotEmpty)
        ..._family(_canonical(file)),
  };
  final tmp = '$path.tmp';
  for (final target in [path, tmp]) {
    if (_family(_canonical(target)).any(live.contains)) {
      throw const SnapshotTargetIsLive();
    }
  }
  for (final stale in [..._family(path), ..._family(tmp)]) {
    final file = File(stale);
    if (file.existsSync()) file.deleteSync();
  }
  File(path).parent.createSync(recursive: true);
  onStep?.call(SnapshotStep.started);
  await db.customStatement('VACUUM INTO ?', [tmp]);
  final tables = leavesOut.toList();
  if (tables.isNotEmpty) _leaveOut(tmp, tables);
  flushFile(File(tmp));
  onStep?.call(SnapshotStep.tmpWritten);
  File(tmp).renameSync(path);
  onStep?.call(SnapshotStep.renamed);
  syncDirectory(File(path).parent);
  onStep?.call(SnapshotStep.synced);
}

/// Empties the [tables] the copy at [path] has, with `secure_delete` on.
void _leaveOut(String path, List<String> tables) {
  final copy = sqlite3.open(path);
  try {
    final present = {
      for (final r in copy.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        r['name']! as String,
    };
    final emptied = tables.where(present.contains).toList();
    if (emptied.isEmpty) return;
    copy
      ..execute('PRAGMA secure_delete = ON')
      ..execute('BEGIN IMMEDIATE');
    try {
      for (final table in emptied) {
        copy.execute('DELETE FROM "${table.replaceAll('"', '""')}"');
      }
      copy.execute('COMMIT');
    } catch (_) {
      copy.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    copy.close();
  }
}

/// [snapshot] was given a path that is the live database, or a file
/// beside it. It carries no path, so it can be logged as it is.
final class SnapshotTargetIsLive implements Exception {
  const SnapshotTargetIsLive();

  @override
  String toString() =>
      'SnapshotTargetIsLive: the snapshot path is a file of the open database';
}

/// What a manifest needs from a snapshot file: its `user_version`, the rows
/// of each table, and the schema version the app records in a table of its
/// own when it asked for it.
final class SnapshotInfo {
  const SnapshotInfo({
    required this.userVersion,
    required this.counts,
    this.schemaVersion,
  });

  final int userVersion;

  final Map<String, int> counts;

  /// The answer to `readSnapshot`'s `schemaVersionQuery` (VIATICUM's
  /// `app_meta.schema_version`); null when none was asked.
  final int? schemaVersion;
}

/// Reads the snapshot file at [path], read-only, on a background isolate,
/// never through the app's connection: the `user_version`, the rows in each
/// of [tables], and [schemaVersionQuery]'s single integer when given, all in
/// one read transaction. Throws when the file is not a database of this
/// schema (a bug at this point: it was just made).
Future<SnapshotInfo> readSnapshot(
  String path, {
  required List<String> tables,
  String? schemaVersionQuery,
}) => Isolate.run(() {
  if (!File(path).existsSync()) {
    throw FileSystemException('no snapshot', path);
  }
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    db.execute('BEGIN');
    final user = db.select('PRAGMA user_version').single.columnAt(0) as int;
    final schema = schemaVersionQuery == null
        ? null
        : db.select(schemaVersionQuery).single.columnAt(0) as int;
    final counts = {
      for (final table in tables)
        table:
            db
                    .select(
                      'SELECT COUNT(*) FROM "${table.replaceAll('"', '""')}"',
                    )
                    .single
                    .columnAt(0)
                as int,
    };
    db.execute('COMMIT');
    return SnapshotInfo(
      userVersion: user,
      counts: counts,
      schemaVersion: schema,
    );
  } finally {
    db.close();
  }
});

/// The number of rows in each of [tables] of [db], by table name, from one
/// `SELECT`, so they describe one commit (RELAY's `entityCounts` over the
/// tables the app names: its `allTables`, an FTS index, never FTS5's shadow
/// tables). For a manifest, count the snapshot ([openSnapshot]), not the
/// live database: the live one may have moved since the snapshot was taken.
Future<Map<String, int>> tableCounts(
  GeneratedDatabase db,
  Iterable<String> tables,
) async {
  final names = tables.toList()..sort();
  if (names.isEmpty) return const {};
  final sql = [
    for (final (i, name) in names.indexed)
      'SELECT $i AS i, COUNT(*) AS n FROM "${name.replaceAll('"', '""')}"',
  ].join(' UNION ALL ');
  final rows = await db.customSelect(sql).get();
  return {
    for (final row in rows) names[row.read<int>('i')]: row.read<int>('n'),
  };
}

/// Opens the snapshot at [path] for reading only (`PRAGMA query_only`), on
/// a background isolate, through the app's [open], to count it
/// ([tableCounts]) or check it. A snapshot is read as it is: `query_only`
/// refuses the writes of a creation or a migration, so a file at another
/// version fails on open. Close it before the snapshot is zipped or
/// deleted.
D openSnapshot<D extends GeneratedDatabase>(
  String path,
  D Function(QueryExecutor executor) open,
) => open(NativeDatabase.createInBackground(File(path), setup: _readOnly));

void _readOnly(Database db) => db.execute('PRAGMA query_only = ON');

/// [path] and the journal, WAL and shared-memory files SQLite keeps beside
/// it.
List<String> _family(String path) => [
  path,
  '$path-journal',
  '$path-wal',
  '$path-shm',
];

/// [path] made absolute and normalised, with the symbolic links of its
/// longest existing prefix resolved, so two spellings of one file compare
/// equal whether or not the file exists yet.
String _canonical(String path) {
  final absolute = File(path).absolute.uri.normalizePath().toFilePath();
  final file = File(absolute);
  if (FileSystemEntity.typeSync(absolute) != FileSystemEntityType.notFound) {
    return file.resolveSymbolicLinksSync();
  }
  final parent = file.parent;
  if (parent.path == absolute) return absolute;
  final name = absolute.substring(parent.path.length);
  return '${_canonical(parent.path)}$name';
}
