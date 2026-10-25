// A plain Dart child, as RELAY's database child processes are: it opens a
// database file through package:apsira_db/plain.dart alone (the connection
// and its pragmas), upgrades it in one migrateWithForeignKeysOff, snapshots
// it; under the Dart VM a library that reaches Flutter (dart:ui) does not
// compile, so the program's exit code is plain_library_test.dart's check.
//
//   dart run test/plain_dart/plain_main.dart <dir>
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:apsira_db/plain.dart';
import 'package:drift/drift.dart';

/// A hand-written database (D-APK-001): v1 `notes`, v2 adds `body`.
final class _Notes extends GeneratedDatabase {
  _Notes(super.executor, this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) =>
        customStatement('CREATE TABLE notes (id INTEGER PRIMARY KEY)'),
    onUpgrade: (_, from, to) => migrateWithForeignKeysOff(
      this,
      () => customStatement('ALTER TABLE notes ADD COLUMN body TEXT'),
    ),
  );
}

Future<void> main(List<String> args) async {
  final dir = args.single;
  final file = File('$dir/plain.db');
  final v1 = _Notes(openDatabaseFile(file), 1);
  await v1.customStatement('INSERT INTO notes (id) VALUES (1)');
  await v1.close();
  final v2 = _Notes(openDatabaseFile(file), 2);
  await v2.customStatement("UPDATE notes SET body = 'b' WHERE id = 1");
  final mode = await v2.customSelect('PRAGMA journal_mode').getSingle();
  await snapshot(v2, '$dir/snapshots/plain.snap.db');
  await v2.close();
  final info = await readSnapshot(
    '$dir/snapshots/plain.snap.db',
    tables: const ['notes'],
  );
  print(
    'journal=${mode.read<String>('journal_mode')} '
    'snapshot=v${info.userVersion}:${info.counts['notes']}',
  );
}
