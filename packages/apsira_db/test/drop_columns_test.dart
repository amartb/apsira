// Ruling R-6 Q5-a (RELAY's schema v12 drops `app_meta.reminder_late_count`
// and `late_card_shown_at`, and this install's values move once to files of
// its own, never from a restored database): what the package gives that
// step. The migration drops the columns inside `migrateWithForeignKeysOff`,
// every kill point of it comes back whole, the pre-migration snapshot keeps
// the old columns, and the app's `open` knows whether it migrates its own
// file or a restore's, because the restore's reopen is its own call
// (`restoring: true`).
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/memory_log.dart';

/// v1: `app_meta (id, schema_version, late_count, late_shown_at)`; v2 drops
/// the two late-card columns. [moveOut] receives their values before the
/// drop; the app passes it only for its own file.
final class _Meta extends GeneratedDatabase {
  _Meta(super.executor, this.schemaVersion, {this.moveOut, this.onStep});

  @override
  final int schemaVersion;

  final void Function(int lateCount, int? shownAt)? moveOut;

  final StepHook? onStep;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE app_meta (id INTEGER PRIMARY KEY, '
        'schema_version INTEGER NOT NULL'
        '${schemaVersion == 1 ? ', late_count INTEGER NOT NULL DEFAULT 0, '
                  'late_shown_at INTEGER' : ''})',
      );
      await customStatement(
        'INSERT INTO app_meta (id, schema_version) VALUES (1, $schemaVersion)',
      );
    },
    onUpgrade: (m, from, to) => migrateWithForeignKeysOff(this, () async {
      final row = await customSelect(
        'SELECT late_count, late_shown_at FROM app_meta WHERE id = 1',
      ).getSingle();
      onStep?.call('read');
      moveOut?.call(
        row.read<int>('late_count'),
        row.read<int?>('late_shown_at'),
      );
      await customStatement('ALTER TABLE app_meta DROP COLUMN late_count');
      onStep?.call('dropped one');
      await customStatement('ALTER TABLE app_meta DROP COLUMN late_shown_at');
      await customStatement('UPDATE app_meta SET schema_version = 2');
      onStep?.call('dropped both');
      await customStatement('PRAGMA user_version = 2');
    }),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('apsira_db_drop_'));

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> createV1() async {
    final db = _Meta(
      NativeDatabase(File('${dir.path}/relay.db'), setup: applyPragmas),
      1,
    );
    await db.customStatement(
      'UPDATE app_meta SET late_count = 3, late_shown_at = 1700000000000',
    );
    await db.close();
  }

  List<String> columns(String path) {
    final raw = sqlite3.open(path);
    try {
      return [
        for (final r in raw.select('PRAGMA table_info(app_meta)'))
          r['name']! as String,
      ];
    } finally {
      raw.close();
    }
  }

  test('the drop runs behind the snapshot, which keeps the old columns, '
      "and the values reach the app's own file only", () async {
    await createV1();
    final moved = <(int, int?)>[];

    final opening = await openWithSnapshot(
      directory: dir,
      name: 'relay',
      targetVersion: 2,
      open: (e) => _Meta(e, 2, moveOut: (n, at) => moved.add((n, at))),
      log: MemoryLog().log,
    );
    await (opening as Opened<_Meta>).database.close();

    expect(moved, [(3, 1700000000000)]);
    expect(columns('${dir.path}/relay.db'), ['id', 'schema_version']);
    expect(columns('${dir.path}/snapshots/relay.pre-v1.db'), [
      'id',
      'schema_version',
      'late_count',
      'late_shown_at',
    ]);
  });

  test(
    "a restore's reopen migrates a restored v1 file with no move out",
    () async {
      await createV1();
      final files = DatabaseFiles(dir, name: 'relay');
      // The live file at v2, and a v1 backup staged and swapped in.
      files.stagedDatabase.parent.createSync(recursive: true);
      File('${dir.path}/relay.db').copySync(files.stagedDatabase.path);
      final first = await openWithSnapshot(
        directory: dir,
        name: 'relay',
        targetVersion: 2,
        open: (e) => _Meta(e, 2, moveOut: (_, _) {}),
        log: MemoryLog().log,
      );
      await (first as Opened<_Meta>).database.close();
      beginRestore(files);
      await writeSafetyCopy(files);
      armRestore(files);
      await swapIn(files);
      final moved = <(int, int?)>[];

      final reopened = await openWithSnapshot(
        directory: dir,
        name: 'relay',
        targetVersion: 2,
        // The restore's own reopen: the app passes no move out.
        open: (e) => _Meta(e, 2),
        log: MemoryLog().log,
        restoring: true,
      );
      await (reopened as Opened<_Meta>).database.close();
      finishRestore(files);

      expect(moved, isEmpty);
      expect(columns('${dir.path}/relay.db'), ['id', 'schema_version']);
    },
  );

  test('a crash at each step of the drop comes back whole', () async {
    await killEveryMigrationStep(
      directory: dir,
      name: 'relay',
      targetVersion: 2,
      steps: ['read', 'dropped one', 'dropped both'],
      createOld: createV1,
      open: (e, onStep) => _Meta(e, 2, onStep: onStep),
      log: MemoryLog().log,
    );
    expect(columns('${dir.path}/relay.db'), ['id', 'schema_version']);
  });
}
