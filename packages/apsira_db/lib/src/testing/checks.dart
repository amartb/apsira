// The crash matrices' assertions (task-specs T13): what "exactly one whole
// database" means, and the kill of every migration step an app runs. New in
// D-APK-018, over relay test/critical/migration_chain_test.dart @
// 09b28810's `_state` and `_integrity`.
import 'dart:io';
import 'dart:isolate';

import 'package:apsira_core/apsira_core.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

import '../connection.dart';
import '../layout.dart';
import '../opener.dart';
import '../step_hook.dart';
import 'crash.dart';

/// A check of this library failed; the message says which. A test that
/// awaits the check fails with it.
final class DatabaseCheckFailed implements Exception {
  const DatabaseCheckFailed(this.message);

  final String message;

  @override
  String toString() => 'DatabaseCheckFailed: $message';
}

/// Throws [DatabaseCheckFailed] unless [files] hold exactly one whole
/// database: the file is there, no restore or migrating marker (nor its
/// `.tmp`) is left, `PRAGMA integrity_check` is `ok`, and its
/// `user_version` is one of [versions].
Future<void> expectOneWholeDatabase(
  DatabaseFiles files, {
  required Set<int> versions,
}) async {
  if (!files.database.existsSync()) {
    throw DatabaseCheckFailed('no database at ${files.layout.database}');
  }
  for (final marker in [
    files.restoreMarker,
    files.restoreMarkerTmp,
    files.migratingMarker,
    files.migratingMarkerTmp,
  ]) {
    if (FileSystemEntity.typeSync(marker.path) !=
        FileSystemEntityType.notFound) {
      throw DatabaseCheckFailed('a marker is left: ${marker.path}');
    }
  }
  final path = files.database.path;
  final (integrity, version) = await Isolate.run(() {
    final raw = sqlite3.open(path, mode: OpenMode.readWrite);
    try {
      final check = raw.select('PRAGMA integrity_check');
      return (
        check.map((r) => '${r.values.single}').join('; '),
        raw.userVersion,
      );
    } finally {
      raw.close();
    }
  });
  if (integrity != 'ok') {
    throw DatabaseCheckFailed('integrity_check: $integrity');
  }
  if (!versions.contains(version)) {
    throw DatabaseCheckFailed('user_version $version, not one of $versions');
  }
}

/// Runs an app's upgrade with a crash after each of its [steps] and checks
/// that the next open finishes it, or comes back from the pre-migration
/// snapshot and migrates again: an [Opened] database at [targetVersion],
/// and [expectOneWholeDatabase].
///
/// For each step, [directory] is emptied and [createOld] writes the old
/// database into it; [open] builds the app's database over an executor
/// with the step hook its migration calls (null for the reopen). Throws
/// [DatabaseCheckFailed] when a step is never reached or the reopen is not
/// ready.
Future<void> killEveryMigrationStep<D extends GeneratedDatabase>({
  required Directory directory,
  required String name,
  required int targetVersion,
  required Iterable<Object> steps,
  required Future<void> Function() createOld,
  required D Function(QueryExecutor executor, StepHook? onStep) open,
  required Log log,
  DatabaseLayout? layout,
}) async {
  final files = DatabaseFiles(directory, name: name, layout: layout);
  for (final step in steps) {
    for (final entry in directory.listSync()) {
      entry.deleteSync(recursive: true);
    }
    await createOld();
    final executors = <QueryExecutor>[];
    QueryExecutor recording(File file) {
      final executor = openDatabaseFile(file);
      executors.add(executor);
      return executor;
    }

    var crashed = false;
    try {
      final opening = await openWithSnapshot(
        directory: directory,
        name: name,
        layout: layout,
        targetVersion: targetVersion,
        open: (executor) => open(executor, crashAfter(step)),
        log: log,
        connect: recording,
      );
      if (opening case Opened(:final database)) await database.close();
      if (opening case SafeMode(:final reader?)) await reader.close();
    } on SimulatedCrash {
      crashed = true;
    }
    // The process died there: its connections go with it.
    for (final executor in executors) {
      try {
        await executor.close();
      } on Object {
        // Already closed.
      }
    }
    if (!crashed) {
      throw DatabaseCheckFailed('the upgrade never reached step $step');
    }

    final reopened = await openWithSnapshot(
      directory: directory,
      name: name,
      layout: layout,
      targetVersion: targetVersion,
      open: (executor) => open(executor, null),
      log: log,
    );
    switch (reopened) {
      case Opened(:final database):
        await database.close();
      case SafeMode(:final reason, :final reader):
        await reader?.close();
        throw DatabaseCheckFailed(
          'after a crash at step $step the next open is safe mode '
          '(${reason.name})',
        );
    }
    await expectOneWholeDatabase(files, versions: {targetVersion});
  }
}
