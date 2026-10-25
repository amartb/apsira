// From relay test/critical/migration_chain_test.dart @ 09b28810, its opener
// half (D-APK-018, AC-13.3): migrateWithForeignKeysOff, fsyncDirectory, and
// the pre-migration snapshot, restore and safe mode on both connections (the
// background isolate and the drift server), then V-3 (background opens never
// migrate). RELAY's cases on its test schemas; only the names move
// (`relay.db` → `fixture.db`, `openRelayDatabase` → `openDatabaseFile`).
import 'dart:io';
import 'dart:isolate';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('migrateWithForeignKeysOff (architecture §8)', () {
    late _Bare db;

    // A parent with a cascading child, as a later schema will have.
    setUp(() async {
      db = _Bare(NativeDatabase.memory(setup: applyPragmas));
      await db.customStatement(
        'CREATE TABLE parent (id INTEGER PRIMARY KEY, name TEXT)',
      );
      await db.customStatement(
        'CREATE TABLE child (id INTEGER PRIMARY KEY, parent_id INTEGER '
        'NOT NULL REFERENCES parent (id) ON DELETE CASCADE)',
      );
      await db.customStatement("INSERT INTO parent VALUES (1, 'a'), (2, 'b')");
      await db.customStatement('INSERT INTO child VALUES (10, 1), (20, 2)');
    });

    tearDown(() => db.close());

    // The copy-drop-rename rebuild drift's alterTable also does.
    Future<void> rebuildParent() async {
      await db.customStatement(
        'CREATE TABLE parent_new (id INTEGER PRIMARY KEY, name TEXT, '
        'extra INTEGER)',
      );
      await db.customStatement(
        'INSERT INTO parent_new (id, name) SELECT id, name FROM parent',
      );
      await db.customStatement('DROP TABLE parent');
      await db.customStatement('ALTER TABLE parent_new RENAME TO parent');
    }

    Future<int> count(String table) async =>
        (await db.customSelect('SELECT count(*) AS n FROM $table').getSingle())
            .read<int>('n');

    Future<int> foreignKeys() async =>
        (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
          'foreign_keys',
        );

    test('a rebuilt parent table keeps its child rows', () async {
      await migrateWithForeignKeysOff(db, rebuildParent);

      expect(await count('child'), 2);
      expect(await count('parent'), 2);
      expect(await foreignKeys(), 1);
    });

    test(
      'the probe catches the cascade: a plain transaction loses them',
      () async {
        // The control: inside a transaction `PRAGMA foreign_keys = OFF` is a
        // no-op, so the DROP cascades. Without this the test above could
        // pass for the wrong reason.
        await db.transaction(() async {
          await db.customStatement('PRAGMA foreign_keys = OFF');
          await rebuildParent();
        });

        expect(await count('child'), 0);
      },
    );

    test('a step that leaves a dangling reference rolls back whole', () async {
      await expectLater(
        migrateWithForeignKeysOff(db, () async {
          await db.customStatement('CREATE TABLE added (x INTEGER)');
          await db.customStatement('DELETE FROM parent WHERE id = 1');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await count('parent'), 2);
      expect(
        await db
            .customSelect("SELECT name FROM sqlite_master WHERE name = 'added'")
            .get(),
        isEmpty,
      );
      expect(await foreignKeys(), 1);
    });
  });

  // The opener's connection: the background isolate the opener defaults to,
  // and the drift server isolate the app's UI open uses.
  final connections = <String, QueryExecutor Function(File)>{
    'background isolate': openDatabaseFile,
    'server isolate': (file) => DatabaseServer(
      registry: FakePortRegistry(),
      portName: databasePortName('fixture'),
    ).connect(file),
  };
  test('fsyncDirectory syncs a directory, and throws for one that is not '
      'there (P1-01a)', () {
    final dir = Directory.systemTemp.createTempSync('apsira_db_fsync_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/f').writeAsStringSync('x');

    fsyncDirectory(dir);
    expect(
      () => fsyncDirectory(Directory('${dir.path}/missing')),
      throwsA(isA<FileSystemException>()),
    );
  });

  for (final MapEntry(key: via, value: connect) in connections.entries) {
    group('pre-migration snapshot, restore and safe mode (D-044), on the $via', () {
      late Directory dir;
      late List<LogRecord> records;
      late Log log;
      // Each step the test schema runs, as `from->to`, across every open.
      late List<String> steps;

      setUp(() {
        dir = Directory.systemTemp.createTempSync('apsira_db_snapshot_');
        records = [];
        log = Log([_MemorySink(records)], debugEnabled: false);
        steps = [];
      });

      tearDown(() => dir.deleteSync(recursive: true));

      String path(String name) => '${dir.path}/$name';

      Future<DatabaseOpening<_Versioned>> openAt(
        int version, {
        int? failAt,
        void Function(int step)? duringStep,
        SyncDirectory? sync,
      }) => openWithSnapshot(
        directory: dir,
        name: 'fixture',
        targetVersion: version,
        open: (executor) => _Versioned(
          executor,
          version,
          failAt: failAt,
          steps: steps,
          duringStep: duringStep,
        ),
        log: log,
        connect: connect,
        syncDirectory: sync ?? fsyncDirectory,
      );

      Future<void> openAndClose(int version) async {
        final opening = await openAt(version);
        expect(opening, isA<Opened<_Versioned>>());
        await (opening as Opened<_Versioned>).database.close();
      }

      /// The test schema at [version] with the sample rows of [_seedRows].
      Future<void> createAt(int version) async {
        await openAndClose(version);
        final raw = sqlite3.open(path('fixture.db'));
        raw.execute('INSERT INTO t1 (x) VALUES (1), (2), (3)');
        raw.close();
      }

      List<String> snapshots() =>
          Directory(path('snapshots')).existsSync()
                ? [
                    for (final f in Directory(path('snapshots')).listSync())
                      f.uri.pathSegments.last,
                  ]
                : <String>[]
            ..sort();

      test('three upgrades keep the two newest snapshots, each at its '
          'pre-migration version', () async {
        await createAt(1);
        await openAndClose(2);
        await openAndClose(3);
        await openAndClose(4);

        expect(snapshots(), ['fixture.pre-v2.db', 'fixture.pre-v3.db']);
        for (final version in [2, 3]) {
          final raw = sqlite3.open(path('snapshots/fixture.pre-v$version.db'));
          addTearDown(raw.close);
          expect(_state(raw), [
            version,
            _tablesUpTo(version),
            [1, 2, 3],
          ]);
          expect(_integrity(raw), 'ok');
        }
        expect(steps, ['1->2', '2->3', '3->4']);
        expect(
          records.where((r) => r.event == 'db.snapshot').map(_fields),
          everyElement(containsPair('kept', anything)),
        );
      });

      test(
        'a fresh install and an up-to-date database take no snapshot',
        () async {
          await openAndClose(3);
          expect(snapshots(), isEmpty);
          await openAndClose(3);
          expect(snapshots(), isEmpty);
          expect(records.map((r) => r.event), isNot(contains('db.snapshot')));
        },
      );

      test('a failure mid-migration restores the snapshot and opens read-only '
          'in safe mode', () async {
        await createAt(1);

        final opening = await openAt(3, failAt: 3);

        expect(opening, isA<SafeMode<_Versioned>>());
        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.migrationFailed);
        // Step 2 committed and step 3 created its table before failing; the
        // safe-mode open ran neither again.
        expect(steps, ['1->2', '2->3']);
        final reader = safe.reader!;
        addTearDown(reader.close);
        expect(reader.schemaVersion, 1);
        expect(
          (await reader.customSelect('PRAGMA integrity_check').getSingle())
              .data,
          {'integrity_check': 'ok'},
        );
        await expectLater(
          reader.customStatement('INSERT INTO t1 (x) VALUES (9)'),
          throwsA(isA<Exception>()),
        );
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        // A replayed WAL of the failed attempt would bring t2 and t3 back.
        expect(_state(raw), [
          1,
          ['t1'],
          [1, 2, 3],
        ]);
        expect(_integrity(raw), 'ok');
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        expect(
          records.map((r) => r.event),
          containsAllInOrder([
            'db.snapshot',
            'db.migrationFailed',
            'db.restored',
          ]),
        );
        expect(_fields(records.last), containsPair('code', 'migrationFailed'));
      });

      test('a snapshot that cannot be written stops the migration', () async {
        await createAt(1);
        // A file where the snapshot directory goes: no directory can be made
        // there, whoever runs the test.
        File(path('snapshots')).writeAsStringSync('');

        final opening = await openAt(2);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.snapshotFailed);
        expect(steps, isEmpty);
        final reader = safe.reader!;
        addTearDown(reader.close);
        await expectLater(
          reader.customStatement('INSERT INTO t1 (x) VALUES (9)'),
          throwsA(isA<Exception>()),
        );
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          1,
          ['t1'],
          [1, 2, 3],
        ]);
        expect(_fields(records.last), containsPair('code', 'snapshotFailed'));
      });

      test('a restore that cannot complete opens the snapshot read-only, and '
          'the next open completes it', () async {
        await createAt(1);
        // A directory where the restore copies the snapshot first.
        Directory(path('fixture.db.restore')).createSync();

        final opening = await openAt(3, failAt: 3);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.restoreFailed);
        final reader = safe.reader!;
        expect(reader.schemaVersion, 1);
        expect(
          (await reader.customSelect('SELECT x FROM t1 ORDER BY x').get()).map(
            (r) => r.read<int>('x'),
          ),
          [1, 2, 3],
        );
        await expectLater(
          reader.customStatement('INSERT INTO t1 (x) VALUES (9)'),
          throwsA(isA<Exception>()),
        );
        await reader.close();
        // The marker names the snapshot it restores, by its base name, and
        // went in through its temporary name (P1-01a).
        expect(
          File(path('fixture.db.restoring')).readAsStringSync(),
          'fixture.pre-v1.db',
        );
        expect(File(path('fixture.db.restoring.tmp')).existsSync(), isFalse);
        expect(_fields(records.last), containsPair('code', 'restoreFailed'));

        // The next launch finishes the restore before anything else opens the
        // file, then migrates from the restored version.
        Directory(path('fixture.db.restore')).deleteSync();
        steps.clear();
        await openAndClose(3);
        expect(steps, ['1->2', '2->3']);
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          3,
          _tablesUpTo(3),
          [1, 2, 3],
        ]);
      });

      test(
        'a restore cut short never replays the failed attempt\'s WAL',
        () async {
          await createAt(1);
          await openAndClose(2); // leaves snapshots/fixture.pre-v1.db
          // The state a crash between the rename and the WAL's deletion leaves:
          // the marker, and a WAL whose frames belong to another file.
          final raw = sqlite3.open(path('fixture.db'))
            ..execute('PRAGMA wal_autocheckpoint = 0')
            ..execute('CREATE TABLE junk (x INTEGER)')
            ..execute('INSERT INTO t1 (x) VALUES (99)');
          final wal = File(path('fixture.db-wal')).readAsBytesSync();
          raw.close();
          File(path('fixture.db-wal')).writeAsBytesSync(wal);
          File(path('fixture.db.restoring')).writeAsStringSync('1');
          steps.clear();

          await openAndClose(2);

          expect(steps, ['1->2']);
          final check = sqlite3.open(path('fixture.db'));
          addTearDown(check.close);
          expect(_state(check), [
            2,
            _tablesUpTo(2),
            [1, 2, 3],
          ]);
          expect(_integrity(check), 'ok');
        },
      );

      test('an old file keeps the snapshot it just took, whatever the '
          'versions of the others (review #1)', () async {
        await createAt(1);
        // Newer snapshots already on disk, as when an old backup is restored
        // over a database that had migrated further (architecture §10.2).
        Directory(path('snapshots')).createSync();
        for (final (version, age) in [(2, 2), (3, 1)]) {
          File(path('snapshots/fixture.pre-v$version.db'))
            ..writeAsStringSync('older snapshot')
            ..setLastModifiedSync(
              DateTime.now().subtract(Duration(hours: age)),
            );
        }

        final opening = await openAt(4, failAt: 3);

        expect(
          (opening as SafeMode<_Versioned>).reason,
          SafeModeReason.migrationFailed,
        );
        await opening.reader?.close();
        expect(snapshots(), ['fixture.pre-v1.db', 'fixture.pre-v3.db']);
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          1,
          ['t1'],
          [1, 2, 3],
        ]);
      });

      test('the restore marker goes in only through fixture.db.restoring.tmp: '
          'when that name cannot be written, no marker appears and the '
          'snapshot is read (P1-01a)', () async {
        await createAt(1);
        // A directory where the marker's temporary file goes.
        Directory(path('fixture.db.restoring.tmp')).createSync();

        final opening = await openAt(3, failAt: 3);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.restoreFailed);
        expect(safe.reader!.schemaVersion, 1);
        await safe.reader!.close();
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        expect(records.map((r) => r.event), isNot(contains('db.restored')));
      });

      test('a lone fixture.db.restoring.tmp (no marker) is deleted on open and '
          'nothing is restored (P1-01a)', () async {
        await createAt(1);
        await openAndClose(2); // snapshots/fixture.pre-v1.db; the file at v2
        File(path('fixture.db.restoring.tmp'))
            .writeAsStringSync('fixture.pre-v1.db');
        steps.clear();
        records.clear();

        await openAndClose(2);

        expect(steps, isEmpty, reason: 'nothing restored, so nothing re-run');
        expect(File(path('fixture.db.restoring.tmp')).existsSync(), isFalse);
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        expect(records.map((r) => r.event), isNot(contains('db.restored')));
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          2,
          _tablesUpTo(2),
          [1, 2, 3],
        ]);
      });

      test('a restore marker with a .tmp beside it: the marker governs and '
          'the .tmp goes (P1-01a)', () async {
        await createAt(1);
        await openAndClose(2); // snapshots/fixture.pre-v1.db; the file at v2
        File(path('fixture.db.restoring'))
            .writeAsStringSync('fixture.pre-v1.db');
        File(path('fixture.db.restoring.tmp')).writeAsStringSync('');
        steps.clear();

        await openAndClose(2);

        expect(steps, ['1->2']);
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        expect(File(path('fixture.db.restoring.tmp')).existsSync(), isFalse);
      });

      test('the restore marker\'s named snapshot is restored even when '
          'another snapshot is newer by modification time (P1-01a)', () async {
        await createAt(1);
        await openAndClose(2); // snapshots/fixture.pre-v1.db
        await openAndClose(3); // snapshots/fixture.pre-v2.db; the file at v3
        File(path('snapshots/fixture.pre-v2.db'))
            .setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
        File(path('snapshots/fixture.pre-v1.db')).setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
        File(path('fixture.db.restoring'))
            .writeAsStringSync('fixture.pre-v1.db\n');
        steps.clear();

        await openAndClose(3);

        expect(steps, ['1->2', '2->3'], reason: 'restored to v1, not v2');
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        expect(
          _fields(records.firstWhere((r) => r.event == 'db.restored')),
          containsPair('version', '1'),
        );
      });

      // 05 §8: a marker that names no snapshot of this database (empty, not
      // a name, another database's, a path) restores the newest snapshot by
      // write order. The P0 form, a bare version number, still reads ('a
      // restore cut short' above).
      for (final marker in [
        '',
        'not a version',
        'other.pre-v1.db',
        'snapshots/fixture.pre-v1.db',
        '../fixture.pre-v1.db',
        '-1',
      ]) {
        test('an unreadable restore marker ("$marker") restores the newest '
            'snapshot by write order (review #2, P1-01a)', () async {
          await createAt(1);
          await openAndClose(2); // snapshots/fixture.pre-v1.db
          await openAndClose(3); // snapshots/fixture.pre-v2.db; the file at v3
          File(path('fixture.db.restoring')).writeAsStringSync(marker);
          steps.clear();

          await openAndClose(3);

          expect(steps, ['2->3'], reason: 'the newest snapshot, pre-v2');
          expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
          expect(
            _fields(
              records.firstWhere(
                (r) => r.event == 'db.restoreMarkerUnreadable',
              ),
            ),
            containsPair('marker', 'restoring'),
          );
        });
      }

      test(
        'the migrating marker is down, naming its snapshot, from the '
        'snapshot until the migration succeeds, then goes (P1-01a, R-10)',
        () async {
          await createAt(1);
          final seen = <String>[];

          await openAt(
            3,
            duringStep: (step) {
              expect(
                File(path('snapshots/fixture.pre-v1.db')).existsSync(),
                isTrue,
              );
              expect(
                File(path('fixture.db.migrating.tmp')).existsSync(),
                isFalse,
              );
              seen.add(File(path('fixture.db.migrating')).readAsStringSync());
            },
          ).then((o) => (o as Opened<_Versioned>).database.close());

          expect(seen, ['fixture.pre-v1.db', 'fixture.pre-v1.db']);
          expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
          expect(File(path('fixture.db.migrating.tmp')).existsSync(), isFalse);
        },
      );

      test('a failed migration restores and removes the migrating marker '
          '(P1-01a, R-10)', () async {
        await createAt(1);

        final opening = await openAt(3, failAt: 3);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.migrationFailed);
        await safe.reader?.close();
        expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          1,
          ['t1'],
          [1, 2, 3],
        ]);
      });

      test('a migrating marker that cannot be removed after the migration '
          'is no success: the snapshot is put back (P1-01a, R-10)', () async {
        await createAt(1);

        final opening = await openAt(
          2,
          duringStep: (_) {
            // Something that cannot be deleted as a file where the marker is.
            File(path('fixture.db.migrating')).deleteSync();
            Directory(path('fixture.db.migrating/x'))
                .createSync(recursive: true);
          },
        );

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.migrationFailed);
        await safe.reader?.close();
        expect(records.map((r) => r.event), contains('db.restored'));
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          1,
          ['t1'],
          [1, 2, 3],
        ]);
      });

      test('a migrating marker left by a launch cut short restores its '
          'snapshot over the half-migrated file, goes, and the migration '
          'runs again (P1-01a, R-10)', () async {
        await createAt(1);
        await openAndClose(2); // snapshots/fixture.pre-v1.db; the file at v2
        // A launch migrating to 3 killed after its step 2: the marker stays.
        File(path('fixture.db.migrating'))
            .writeAsStringSync('fixture.pre-v1.db');
        steps.clear();

        await openAndClose(3);

        expect(steps, ['1->2', '2->3'], reason: 'restored to v1 first');
        expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
        expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
        expect(
          records.map((r) => r.event),
          containsAllInOrder(['db.migrationInterrupted', 'db.restored']),
        );
      });

      test('an unreadable migrating marker restores the newest snapshot by '
          'write order (P1-01a, R-10)', () async {
        await createAt(1);
        await openAndClose(2); // snapshots/fixture.pre-v1.db
        await openAndClose(3); // snapshots/fixture.pre-v2.db; the file at v3
        File(path('fixture.db.migrating')).writeAsStringSync('');
        steps.clear();

        await openAndClose(3);

        expect(steps, ['2->3'], reason: 'the newest snapshot, pre-v2');
        expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
        expect(
          _fields(
            records.firstWhere((r) => r.event == 'db.restoreMarkerUnreadable'),
          ),
          containsPair('marker', 'migrating'),
        );
      });

      for (final marker in ['fixture.db.restoring', 'fixture.db.migrating']) {
        test('a $marker naming a snapshot that is not on disk restores '
            'nothing: restoreFailed reads the file as it is, and the marker '
            'stays (P1-01a)', () async {
          await createAt(1);
          await openAndClose(2); // snapshots/fixture.pre-v1.db
          await openAndClose(3); // snapshots/fixture.pre-v2.db; the file at v3
          File(path(marker)).writeAsStringSync('fixture.pre-v7.db');
          steps.clear();

          final opening = await openAt(3);

          final safe = opening as SafeMode<_Versioned>;
          expect(safe.reason, SafeModeReason.restoreFailed);
          final reader = safe.reader!;
          addTearDown(reader.close);
          expect(reader.schemaVersion, 3, reason: 'the file, not a snapshot');
          expect(steps, isEmpty);
          expect(File(path(marker)).readAsStringSync(), 'fixture.pre-v7.db');
          expect(
            records.map((r) => r.event),
            allOf(
              contains('db.restoreSnapshotMissing'),
              isNot(contains('db.restored')),
            ),
          );
        });
      }

      // P1-01a.8: every marker change is durable (the directory fsynced)
      // before the open goes on, so no user commit precedes it.
      String durable(Directory d) {
        final where = d.path == dir.path ? 'dir' : 'snapshots';
        final markers = [
          for (final m in ['migrating', 'restoring'])
            if (File(path('fixture.db.$m')).existsSync()) m,
        ];
        return '$where:${markers.join('+')}';
      }

      test('a migration syncs the directory after the snapshot, after its '
          'marker\'s rename and after its removal, before it is ready '
          '(P1-01a)', () async {
        await createAt(1);
        final syncs = <String>[];

        final opening = await openAt(2, sync: (d) => syncs.add(durable(d)));

        expect(opening, isA<Opened<_Versioned>>());
        await (opening as Opened<_Versioned>).database.close();
        expect(syncs, ['snapshots:', 'dir:migrating', 'dir:']);
      });

      test('a failed migration\'s restore syncs the directory after its '
          'marker\'s rename, after the file\'s, and after both markers go '
          '(P1-01a)', () async {
        await createAt(1);
        final syncs = <String>[];

        final opening = await openAt(
          3,
          failAt: 3,
          sync: (d) => syncs.add(durable(d)),
        );

        await (opening as SafeMode<_Versioned>).reader?.close();
        expect(opening.reason, SafeModeReason.migrationFailed);
        expect(syncs, [
          'snapshots:',
          'dir:migrating',
          'dir:migrating+restoring',
          'dir:migrating+restoring',
          'dir:',
        ]);
      });

      test('a removal of the migrating marker that cannot be made durable is '
          'no success: the snapshot goes back (P1-01a)', () async {
        await createAt(1);
        var failed = false;

        final opening = await openAt(
          2,
          sync: (d) {
            if (!failed && durable(d) == 'dir:') {
              failed = true;
              throw const FileSystemException('injected fsync failure');
            }
          },
        );

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.migrationFailed);
        await safe.reader?.close();
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(_state(raw), [
          1,
          ['t1'],
          [1, 2, 3],
        ]);
        expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
      });

      test('a lone fixture.db.migrating.tmp is a migration that never began: '
          'deleted on open, nothing restored (P1-01a, R-10)', () async {
        await createAt(1);
        await openAndClose(2); // snapshots/fixture.pre-v1.db; the file at v2
        File(path('fixture.db.migrating.tmp'))
            .writeAsStringSync('fixture.pre-v1.db');
        steps.clear();

        await openAndClose(2);

        expect(steps, isEmpty);
        expect(File(path('fixture.db.migrating.tmp')).existsSync(), isFalse);
        expect(records.map((r) => r.event), isNot(contains('db.restored')));
      });

      test('a migrating marker that cannot be written stops the migration '
          'as a snapshot failure (P1-01a, R-10)', () async {
        await createAt(1);
        // A directory where the marker's temporary file goes.
        Directory(path('fixture.db.migrating.tmp')).createSync();

        final opening = await openAt(2);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.snapshotFailed);
        await safe.reader?.close();
        expect(steps, isEmpty);
        expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
      });

      test('an unreadable restore marker with no snapshot reads the file, '
          'and the marker stays (review #2)', () async {
        await createAt(1);
        File(path('fixture.db.restoring')).writeAsStringSync('');

        final opening = await openAt(2);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.restoreFailed);
        final reader = safe.reader!;
        addTearDown(reader.close);
        expect(reader.schemaVersion, 1);
        expect(steps, isEmpty);
        expect(File(path('fixture.db.restoring')).existsSync(), isTrue);
        expect(
          records.map((r) => r.event),
          contains('db.restoreMarkerUnreadable'),
        );
      });

      test('a file newer than the build opens read-only at its own version '
          '(review #3)', () async {
        await createAt(5);

        final opening = await openAt(3);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.openFailed);
        final reader = safe.reader!;
        addTearDown(reader.close);
        expect(reader.schemaVersion, 5);
        await expectLater(
          reader.customStatement('INSERT INTO t1 (x) VALUES (9)'),
          throwsA(isA<Exception>()),
        );
        expect(snapshots(), isEmpty);
      });

      for (final wrapped in [true, false]) {
        test('a parent rebuilt in onUpgrade through the opener '
            '${wrapped ? 'keeps' : 'loses, unwrapped,'} its children '
            '(review #4)', () async {
          Future<DatabaseOpening<_ParentChild>> openPc(int version) =>
              openWithSnapshot(
                directory: dir,
                name: 'fixture',
                targetVersion: version,
                open: (e) => _ParentChild(e, version, wrapped: wrapped),
                log: log,
                connect: connect,
              );
          await ((await openPc(1)) as Opened<_ParentChild>).database.close();

          final opened = (await openPc(2)) as Opened<_ParentChild>;
          final db = opened.database;
          addTearDown(db.close);

          Future<int> one(String sql) async =>
              (await db.customSelect(sql).getSingle()).data.values.single
                  as int;
          expect(await one('SELECT count(*) FROM parent'), 2);
          expect(await one('SELECT count(*) FROM child'), wrapped ? 2 : 0);
          expect(await one('PRAGMA foreign_keys'), 1);
          expect(snapshots(), ['fixture.pre-v1.db']);
        });
      }

      test('a file that is not a database opens nothing and says so', () async {
        File(path('fixture.db')).writeAsStringSync('not a database' * 100);

        final opening = await openAt(1);

        final safe = opening as SafeMode<_Versioned>;
        expect(safe.reason, SafeModeReason.openFailed);
        expect(safe.reader, isNull);
        expect(snapshots(), isEmpty);
      });
    });
  }

  group('V-3: background opens never migrate (D-044 addendum)', () {
    late Directory dir;
    final log = Log(const [], debugEnabled: false);

    setUp(() => dir = Directory.systemTemp.createTempSync('apsira_db_v3_'));
    tearDown(() => dir.deleteSync(recursive: true));

    String path(String name) => '${dir.path}/$name';

    Future<DatabaseOpening<_Meta>> uiOpen(
      int version, {
      List<String>? migrations,
      Future<void> Function()? midMigration,
    }) => openWithSnapshot(
      directory: dir,
      name: 'fixture',
      targetVersion: version,
      open: (e) =>
          _Meta(e, version, migrations: migrations, midMigration: midMigration),
      log: log,
      connect: (file) => DatabaseServer(
        registry: FakePortRegistry(),
        portName: databasePortName('fixture'),
      ).connect(file),
    );

    Future<void> createV1() async =>
        ((await uiOpen(1)) as Opened<_Meta>).database.close();

    test(
      'a UI open and a background open started together on a v1 file '
      'take one snapshot and one migration; the background is not ready',
      () async {
        await createV1();
        final migrations = <String>[];
        // The background open runs in its own isolate and starts first, so
        // it may answer before the UI's migration begins or during it (the
        // migration waits for its answer); either way it is not ready. The
        // overlap inside the migration's transaction is proved
        // deterministically by background_open_test.dart ("a background
        // open that overlaps the UI migration").
        final background = _backgroundOpenInIsolate(dir.path, 2);

        final ui = uiOpen(
          2,
          migrations: migrations,
          midMigration: () => background,
        );
        final (opening, answer) = await (ui, background).wait;

        // Before the snapshot, the file's version; from the snapshot on, the
        // migrating marker (P1-01a, R-10).
        expect(
          answer,
          anyOf(
            NotReadyReason.versionMismatch.name,
            NotReadyReason.migrationPending.name,
          ),
        );
        final db = (opening as Opened<_Meta>).database;
        expect(migrations, ['1->2']);
        expect(
          (await db
                  .customSelect('SELECT schema_version FROM app_meta')
                  .getSingle())
              .read<int>('schema_version'),
          2,
        );
        await db.close();
        expect(
          [for (final f in Directory(path('snapshots')).listSync()) f.path],
          [path('snapshots/fixture.pre-v1.db')],
        );
        final raw = sqlite3.open(path('fixture.db'));
        addTearDown(raw.close);
        expect(raw.userVersion, 2);
      },
    );

    test('once the UI open has migrated, a background open is ready: the '
        'opener checkpoints, so the header carries the new version', () async {
      await createV1();
      final db = ((await uiOpen(2)) as Opened<_Meta>).database;
      // The UI stays open: the header is read while its connection holds
      // the file.
      addTearDown(db.close);

      expect(await _backgroundOpenInIsolate(dir.path, 2), 'ready');
    });

    test('a fresh install leaves the header at the target', () async {
      final db = ((await uiOpen(1)) as Opened<_Meta>).database;
      addTearDown(db.close);

      expect(await _backgroundOpenInIsolate(dir.path, 1), 'ready');
    });
  });
}

/// In a new isolate, as a background entry point would: `openForBackground`
/// on [directory] at [target]; 'ready' or the reason it was not.
Future<String> _backgroundOpenInIsolate(String directory, int target) =>
    Isolate.run(() async {
      final opening = await openForBackground(
        directory: Directory(directory),
        name: 'fixture',
        targetVersion: target,
        open: (e) => _Meta(e, target),
        log: Log(const [], debugEnabled: false),
      );
      switch (opening) {
        case OpenedInBackground(:final database):
          await database.close();
          return 'ready';
        case NotReady(:final reason):
          return reason.name;
      }
    });

/// A test schema with an `app_meta` row, migrated as the app's is: every
/// step and the `schema_version` update in one transaction. [midMigration]
/// runs inside it, after the step's DDL.
final class _Meta extends GeneratedDatabase {
  _Meta(
    super.executor,
    this.schemaVersion, {
    this.migrations,
    this.midMigration,
  });

  @override
  final int schemaVersion;

  final List<String>? migrations;

  final Future<void> Function()? midMigration;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE app_meta (id INTEGER PRIMARY KEY CHECK (id = 1), '
        'schema_version INTEGER NOT NULL)',
      );
      await customStatement('INSERT INTO app_meta VALUES (1, $schemaVersion)');
    },
    onUpgrade: (m, from, to) async {
      migrations?.add('$from->$to');
      await migrateWithForeignKeysOff(this, () async {
        await customStatement('CREATE TABLE added_v$to (x INTEGER)');
        await midMigration?.call();
        await customStatement('UPDATE app_meta SET schema_version = $to');
      });
    },
  );
}

/// A test schema: version v has the tables t1 … tv, one created by each
/// step, without a transaction, so a failing step leaves its DDL behind.
/// The step to [failAt] throws after its DDL.
final class _Versioned extends GeneratedDatabase {
  _Versioned(
    super.executor,
    this.schemaVersion, {
    required this.steps,
    this.failAt,
    this.duringStep,
  });

  @override
  final int schemaVersion;

  final int? failAt;

  final List<String> steps;

  /// Called at each step, before its DDL: what a test observes mid-way.
  final void Function(int step)? duringStep;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (var v = 1; v <= schemaVersion; v++) {
        await customStatement('CREATE TABLE t$v (x INTEGER)');
      }
    },
    onUpgrade: (m, from, to) async {
      for (var v = from + 1; v <= to; v++) {
        steps.add('${v - 1}->$v');
        duringStep?.call(v);
        await customStatement('CREATE TABLE t$v (x INTEGER)');
        if (v == failAt) throw StateError('injected failure in step $v');
        await customStatement('PRAGMA user_version = $v');
      }
    },
  );
}

/// A parent with a cascading child at v1; v2 rebuilds the parent in
/// onUpgrade, through [migrateWithForeignKeysOff] when [wrapped], else in a
/// plain transaction (the control that shows the cascade).
final class _ParentChild extends GeneratedDatabase {
  _ParentChild(super.executor, this.schemaVersion, {required this.wrapped});

  @override
  final int schemaVersion;

  final bool wrapped;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE parent (id INTEGER PRIMARY KEY, name TEXT)',
      );
      await customStatement(
        'CREATE TABLE child (id INTEGER PRIMARY KEY, parent_id INTEGER '
        'NOT NULL REFERENCES parent (id) ON DELETE CASCADE)',
      );
      await customStatement("INSERT INTO parent VALUES (1, 'a'), (2, 'b')");
      await customStatement('INSERT INTO child VALUES (10, 1), (20, 2)');
    },
    onUpgrade: (m, from, to) async {
      Future<void> rebuild() async {
        await customStatement('PRAGMA foreign_keys = OFF');
        await customStatement(
          'CREATE TABLE parent_new (id INTEGER PRIMARY KEY, name TEXT, '
          'extra INTEGER)',
        );
        await customStatement(
          'INSERT INTO parent_new (id, name) SELECT id, name FROM parent',
        );
        await customStatement('DROP TABLE parent');
        await customStatement('ALTER TABLE parent_new RENAME TO parent');
      }

      if (wrapped) {
        await migrateWithForeignKeysOff(this, rebuild);
      } else {
        await transaction(rebuild);
      }
    },
  );
}

/// A database with no declared tables, for the probes that build their own.
final class _Bare extends GeneratedDatabase {
  _Bare(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}

List<String> _tablesUpTo(int version) => [
  for (var v = 1; v <= version; v++) 't$v',
];

/// [user_version, tables, the rows of t1].
List<Object> _state(Database raw) => [
  raw.userVersion,
  [
    for (final r in raw.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    ))
      r['name'] as String,
  ],
  [for (final r in raw.select('SELECT x FROM t1 ORDER BY x')) r['x'] as int],
];

String _integrity(Database raw) =>
    raw.select('PRAGMA integrity_check').single.values.single! as String;

Map<String, String> _fields(LogRecord r) => {
  for (final MapEntry(:key, :value) in r.fields.entries) key: value.render(),
};

final class _MemorySink implements LogSink {
  _MemorySink(this.records);

  final List<LogRecord> records;

  @override
  void write(LogRecord record) => records.add(record);
}
