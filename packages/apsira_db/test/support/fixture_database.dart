// The tests' app database: hand-written, no generated code (D-APK-001), after
// RELAY's test schemas in test/critical/migration_chain_test.dart @ 09b28810
// (`_Versioned`, `_ParentChild`). Plain Dart: the hard-kill child runs it too.
import 'dart:io';

import 'package:apsira_db/src/connection.dart';
import 'package:apsira_db/src/migrate.dart';
import 'package:apsira_db/src/step_hook.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

/// The newest version of [FixtureDatabase].
const fixtureVersion = 4;

/// Two tables whose schema grows one step per version:
///
/// - v1: `notes (id, title)` and `tags (id, note_id → notes ON DELETE
///   CASCADE, name)`;
/// - v2: `notes` rebuilt with a `body` column (copy, drop, rename: the
///   rebuild that cascades unless foreign keys are off);
/// - v3: `tags` gains `color`;
/// - v4: the index `tags_by_note`.
///
/// Every upgrade runs in one [migrateWithForeignKeysOff] transaction, as
/// RELAY's does. Each step is recorded in [steps] as `from->to`, and
/// [onStep] is called with the step's target version after its DDL: the
/// place a test kills it. [failAt] throws in that step; [danglingAt] leaves a
/// tag whose note is gone, which the closing `foreign_key_check` refuses.
final class FixtureDatabase extends GeneratedDatabase {
  FixtureDatabase(
    super.executor, {
    this.schemaVersion = fixtureVersion,
    List<String>? steps,
    this.onStep,
    this.failAt,
    this.danglingAt,
  }) : steps = steps ?? [];

  @override
  final int schemaVersion;

  final List<String> steps;

  final StepHook? onStep;

  final int? failAt;

  final int? danglingAt;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE IF NOT EXISTS notes '
        '(id INTEGER PRIMARY KEY, title TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE IF NOT EXISTS tags (id INTEGER PRIMARY KEY, '
        'note_id INTEGER NOT NULL REFERENCES notes (id) ON DELETE CASCADE, '
        'name TEXT NOT NULL)',
      );
      for (var v = 2; v <= schemaVersion; v++) {
        await _step(v);
      }
    },
    onUpgrade: (m, from, to) => migrateWithForeignKeysOff(this, () async {
      for (var v = from + 1; v <= to; v++) {
        steps.add('${v - 1}->$v');
        await _step(v);
        if (v == danglingAt) {
          await customStatement(
            "INSERT INTO tags (note_id, name) VALUES (999999, 'dangling')",
          );
        }
        onStep?.call(v);
        if (v == failAt) throw StateError('injected failure in step $v');
        await customStatement('PRAGMA user_version = $v');
      }
    }),
  );

  Future<void> _step(int version) async {
    switch (version) {
      case 2:
        await customStatement(
          'CREATE TABLE notes_new '
          '(id INTEGER PRIMARY KEY, title TEXT NOT NULL, body TEXT)',
        );
        await customStatement(
          'INSERT INTO notes_new (id, title) SELECT id, title FROM notes',
        );
        await customStatement('DROP TABLE notes');
        await customStatement('ALTER TABLE notes_new RENAME TO notes');
      case 3:
        await customStatement('ALTER TABLE tags ADD COLUMN color TEXT');
      case 4:
        await customStatement(
          'CREATE INDEX IF NOT EXISTS tags_by_note ON tags (note_id)',
        );
    }
  }
}

/// Writes a closed fixture database at [version] to [file] holding the notes
/// [titles], each with one tag, as a launch of that build leaves it
/// (checkpointed, no `-wal`).
Future<void> createFixture(
  File file, {
  int version = fixtureVersion,
  List<String> titles = const ['one', 'two', 'three'],
}) async {
  file.parent.createSync(recursive: true);
  final db = FixtureDatabase(
    NativeDatabase(file, setup: applyPragmas),
    schemaVersion: version,
  );
  for (final title in titles) {
    await db.customStatement('INSERT INTO notes (title) VALUES (?)', [title]);
    await db.customStatement(
      "INSERT INTO tags (note_id, name) VALUES (last_insert_rowid(), 'tag')",
    );
  }
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await db.close();
}

/// The note titles in the database at [path], in id order, read without
/// drift (and without creating anything).
List<String> noteTitles(String path) {
  final raw = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return [
      for (final r in raw.select('SELECT title FROM notes ORDER BY id'))
        r['title']! as String,
    ];
  } finally {
    raw.close();
  }
}

/// The `user_version` of the database at [path].
int userVersionOf(String path) {
  final raw = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return raw.userVersion;
  } finally {
    raw.close();
  }
}
