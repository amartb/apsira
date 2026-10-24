// The crash matrix of apsira_db (D-APK-018, task-specs T13): one test per
// kill point, named by its id. A kill is the step hook throwing
// [SimulatedCrash] after the named step; the test then drops every handle
// and opens again from the files on disk, as a restarted process would.
// KP-R11 and KP-S4 kill a plain Dart child with SIGKILL instead
// (`test/support/kill_child.dart`), so no in-memory state can help the
// recovery. Every case ends in exactly one whole database.
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

/// LYCEUM's on-disk names (`restore_swap.dart` @ 9f4ff27, ruling R-5 Q3-a).
const _lyceum = DatabaseLayout(
  database: 'lyceum.sqlite',
  restoringMarker: 'lyceum.sqlite.restoring',
  migratingMarker: 'lyceum.sqlite.migrating',
  staged: 'restore/lyceum.staged.sqlite',
  safetyCopy: 'snapshots/lyceum.safety.db',
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late MemoryLog log;
  late List<String> steps;
  // Every connection an open made, so a crash can drop them.
  final executors = <QueryExecutor>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_db_crash_');
    log = MemoryLog();
    steps = [];
  });

  tearDown(() async {
    await dropHandles(executors);
    dir.deleteSync(recursive: true);
  });

  DatabaseFiles filesOf(String name, DatabaseLayout? layout) =>
      DatabaseFiles(dir, name: name, layout: layout);

  QueryExecutor recording(File file) {
    final executor = openDatabaseFile(file);
    executors.add(executor);
    return executor;
  }

  Future<DatabaseOpening<FixtureDatabase>> open({
    String name = 'fixture',
    DatabaseLayout? layout,
    int version = fixtureVersion,
    StepHook? onStep,
    StepHook? migrationStep,
    int? danglingAt,
  }) => openWithSnapshot(
    directory: dir,
    name: name,
    layout: layout,
    targetVersion: version,
    open: (executor) => FixtureDatabase(
      executor,
      schemaVersion: version,
      steps: steps,
      onStep: migrationStep,
      danglingAt: danglingAt,
    ),
    log: log.log,
    connect: recording,
    onStep: onStep,
  );

  /// The next launch: an open that must come up ready, closed again.
  Future<void> reopen({String name = 'fixture', DatabaseLayout? layout}) async {
    final opening = await open(name: name, layout: layout);
    expect(opening, isA<Opened<FixtureDatabase>>());
    await (opening as Opened<FixtureDatabase>).database.close();
    executors.clear();
  }

  List<String> snapshotNames(DatabaseFiles files) =>
      !files.snapshots.existsSync()
            ? <String>[]
            : [
                for (final f in files.snapshots.listSync().whereType<File>())
                  if (f.uri.pathSegments.last.contains('.pre-v'))
                    f.uri.pathSegments.last,
              ]
        ..sort();

  group('KP-M migration', () {
    test('KP-M1 pre-migration snapshot written, before the first step: the '
        'next open migrates again from the live file and keeps at most '
        'keepSnapshots', () async {
      final files = filesOf('fixture', null);
      await createFixture(files.database, version: 1);
      // Older snapshots on disk, so the rotation has something to prune.
      files.snapshots.createSync(recursive: true);
      for (final (v, age) in [(7, 3), (8, 2)]) {
        File('${files.snapshots.path}/fixture.pre-v$v.db')
          ..writeAsStringSync('older')
          ..setLastModifiedSync(DateTime.now().subtract(Duration(hours: age)));
      }

      await expectLater(
        open(onStep: crashAfter(OpenStep.snapshotTaken)),
        throwsA(isA<SimulatedCrash>()),
      );
      await dropHandles(executors);
      expect(userVersionOf(files.database.path), 1);
      expect(steps, isEmpty);

      await reopen();

      expect(steps, ['1->2', '2->3', '3->4']);
      expect(noteTitles(files.database.path), ['one', 'two', 'three']);
      expect(snapshotNames(files).length, lessThanOrEqualTo(2));
      expect(snapshotNames(files), contains('fixture.pre-v1.db'));
      await expectOneWholeDatabase(files, versions: {fixtureVersion});
    });

    test('KP-M2 inside each step of a three-step upgrade (v1 to v4): the '
        'transaction rolls back, user_version is unchanged, and the upgrade '
        'runs again and completes', () async {
      for (final step in [2, 3, 4]) {
        final files = filesOf('fixture', null);
        await createFixture(files.database, version: 1);
        steps.clear();

        await expectLater(
          open(migrationStep: crashAfter(step)),
          throwsA(isA<SimulatedCrash>()),
          reason: 'step $step',
        );
        await dropHandles(executors);
        expect(userVersionOf(files.database.path), 1, reason: 'step $step');
        expect(files.migratingMarker.existsSync(), isTrue, reason: '$step');

        steps.clear();
        await reopen();
        expect(steps, ['1->2', '2->3', '3->4'], reason: 'step $step');
        expect(noteTitles(files.database.path), ['one', 'two', 'three']);
        await expectOneWholeDatabase(files, versions: {fixtureVersion});
        for (final e in dir.listSync()) {
          e.deleteSync(recursive: true);
        }
      }
    });

    test('KP-M3 migration committed, before the marker or log line: the next '
        'open is Opened at v4 with no second snapshot', () async {
      final files = filesOf('fixture', null);
      await createFixture(files.database, version: 1);

      await expectLater(
        open(onStep: crashAfter(OpenStep.migrated)),
        throwsA(isA<SimulatedCrash>()),
      );
      await dropHandles(executors);
      expect(files.migratingMarker.existsSync(), isTrue);
      expect(log.events, isNot(contains('db.opened')));

      await reopen();

      expect(userVersionOf(files.database.path), fixtureVersion);
      expect(snapshotNames(files), ['fixture.pre-v1.db']);
      expect(noteTitles(files.database.path), ['one', 'two', 'three']);
      await expectOneWholeDatabase(files, versions: {fixtureVersion});
    });

    test('KP-M4 foreign_key_check fails inside the step: rolled back whole, '
        'SafeMode(migrationFailed) with the snapshot restorable', () async {
      final files = filesOf('fixture', null);
      await createFixture(files.database, version: 1);

      final opening = await open(danglingAt: 3);

      final safe = opening as SafeMode<FixtureDatabase>;
      expect(safe.reason, SafeModeReason.migrationFailed);
      final reader = safe.reader!;
      expect(reader.schemaVersion, 1);
      await reader.close();
      expect(
        log.events,
        containsAllInOrder(['db.migrationFailed', 'db.restored']),
      );
      expect(hasSnapshot(dir, name: 'fixture'), isTrue);
      expect(userVersionOf(files.database.path), 1);
      expect(noteTitles(files.database.path), ['one', 'two', 'three']);
      await expectOneWholeDatabase(files, versions: {1});
    });

    test('KP-M5 the snapshot cannot be written (ENOSPC): no step runs, '
        'SafeMode(snapshotFailed)', () async {
      final files = filesOf('fixture', null);
      await createFixture(files.database, version: 1);
      final before = files.database.readAsBytesSync();

      final opening = await open(
        onStep: (step) {
          if (step == OpenStep.snapshotStarting) {
            throw FileSystemException(
              'No space left on device',
              files.snapshots.path,
              const OSError('No space left on device', 28),
            );
          }
        },
      );

      final safe = opening as SafeMode<FixtureDatabase>;
      expect(safe.reason, SafeModeReason.snapshotFailed);
      await safe.reader?.close();
      expect(steps, isEmpty);
      expect(files.database.readAsBytesSync(), before);
      expect(files.migratingMarker.existsSync(), isFalse);
    });

    for (final (name, layout) in [('fixture', null), ('lyceum', _lyceum)]) {
      test('KP-M6 a launch cut short with the .migrating marker present '
          '(${layout == null ? 'standard' : 'LYCEUM'} layout): the snapshot '
          'is restored, then the migration runs again; a background open '
          'meanwhile is NotReady', () async {
        final files = filesOf(name, layout);
        await createFixture(files.database, version: 1);
        await expectLater(
          open(name: name, layout: layout, migrationStep: crashAfter(3)),
          throwsA(isA<SimulatedCrash>()),
        );
        await dropHandles(executors);
        expect(files.migratingMarker.existsSync(), isTrue);

        final background = await openForBackground(
          directory: dir,
          name: name,
          layout: layout,
          targetVersion: fixtureVersion,
          open: FixtureDatabase.new,
          log: log.log,
        );
        expect(
          (background as NotReady<FixtureDatabase>).reason,
          NotReadyReason.migrationPending,
        );

        steps.clear();
        await reopen(name: name, layout: layout);
        expect(steps, ['1->2', '2->3', '3->4']);
        expect(
          log.events,
          containsAllInOrder(['db.migrationInterrupted', 'db.restored']),
        );
        await expectOneWholeDatabase(files, versions: {fixtureVersion});
      });
    }
  });

  group('KP-R restore', () {
    Future<DatabaseFiles> liveAndStaged(
      String name,
      DatabaseLayout? layout,
    ) async {
      final files = filesOf(name, layout);
      await createFixture(files.database, titles: ['live']);
      await createFixture(files.stagedDatabase, titles: ['restored']);
      return files;
    }

    Future<void> swapUpTo(DatabaseFiles files, StepHook? hook) async {
      beginRestore(files, onStep: hook);
      await writeSafetyCopy(files, onStep: hook);
      armRestore(files, onStep: hook);
      await swapIn(files, onStep: hook);
      finishRestore(files, onStep: hook);
    }

    // RELAY's protocol: the restored file stands only once finishRestore
    // has removed the marker (after the restore's reopen and integrity
    // check); before that the next open puts the safety copy back.
    const expected = {
      SwapStep.begun: 'live',
      SwapStep.safetyCopyWritten: 'live',
      SwapStep.armed: 'live',
      SwapStep.stagedWritten: 'live',
      SwapStep.renamedIn: 'live',
      SwapStep.staleCleared: 'live',
      SwapStep.finished: 'restored',
    };
    test('the matrix names every SwapStep', () {
      expect(expected.keys, SwapStep.values);
    });

    for (final (i, MapEntry(key: step, value: data))
        in expected.entries.indexed) {
      test('KP-R${i + 1} after ${step.name}: exactly one whole database '
          '($data), the marker gone, the safety copy kept', () async {
        final files = await liveAndStaged('fixture', null);

        await expectLater(
          swapUpTo(files, crashAfter(step)),
          throwsA(isA<SimulatedCrash>()),
        );
        await reopen();

        expect(noteTitles(files.database.path), [data]);
        await expectOneWholeDatabase(files, versions: {fixtureVersion});
        expect(
          files.safetyCopy.existsSync(),
          step.index >= SwapStep.safetyCopyWritten.index,
        );
      });
    }

    for (final (id, name, layout) in [
      ('KP-R8', 'fixture', null),
      ('KP-R9', 'lyceum', _lyceum),
    ]) {
      test('$id after each RollBackStep '
          '(${layout == null ? 'standard' : 'LYCEUM'} layout): the old '
          'database, whole', () async {
        for (final step in RollBackStep.values) {
          final files = await liveAndStaged(name, layout);
          beginRestore(files);
          await writeSafetyCopy(files);
          armRestore(files);
          await swapIn(files);
          expect(noteTitles(files.database.path), ['restored']);

          await expectLater(
            rollBack(files, onStep: crashAfter(step)),
            throwsA(isA<SimulatedCrash>()),
            reason: step.name,
          );
          await reopen(name: name, layout: layout);

          expect(noteTitles(files.database.path), ['live'], reason: step.name);
          await expectOneWholeDatabase(files, versions: {fixtureVersion});
          for (final e in dir.listSync()) {
            e.deleteSync(recursive: true);
          }
        }
      });
    }

    test('KP-R10 a LYCEUM 1.0.x leftover with its layout recovers as '
        "LYCEUM's own code did", () async {
      final files = filesOf('lyceum', _lyceum);
      // Each row: the marker's word, what is on disk, what the next open
      // finds (LYCEUM's recoverInterruptedRestore @ 9f4ff27).
      final cases = [
        // A swap that had not moved the live file: it stays.
        ('swap', {'live': 'live', 'staged': 'restored'}, 'live'),
        // Cut short between moving the live file and the staged one.
        ('swap', {'safety': 'live', 'staged': 'restored'}, 'live'),
        // The staged file was renamed in: the restored data stays.
        ('swap', {'live': 'restored', 'safety': 'live'}, 'restored'),
        // A roll back cut short: the safety copy is the live file again.
        ('rollback', {'live': 'restored', 'safety': 'live'}, 'live'),
      ];
      for (final (word, onDisk, found) in cases) {
        for (final MapEntry(key: what, value: title) in onDisk.entries) {
          final file = switch (what) {
            'live' => files.database,
            'safety' => files.safetyCopy,
            _ => files.stagedDatabase,
          };
          await createFixture(file, titles: [title]);
        }
        files.restoreMarker.writeAsStringSync(word);

        await reopen(name: 'lyceum', layout: _lyceum);

        final reason = '$word $onDisk';
        expect(noteTitles(files.database.path), [found], reason: reason);
        expect(files.restoreMarker.existsSync(), isFalse, reason: reason);
        expect(files.staging.existsSync(), isFalse, reason: reason);
        await expectOneWholeDatabase(files, versions: {fixtureVersion});
        for (final e in dir.listSync()) {
          e.deleteSync(recursive: true);
        }
      }
    });

    test(
      'KP-R11 hard kill at renamedIn: as KP-R5, in a fresh process',
      () async {
        final files = await liveAndStaged('fixture', null);

        await hardKill(
          'renamedIn',
          script: 'test/support/kill_child.dart',
          args: ['swap', dir.path, 'renamedIn'],
        );
        expect(files.restoreMarker.existsSync(), isTrue);
        expect(noteTitles(files.database.path), ['restored']);

        await reopen();

        expect(noteTitles(files.database.path), ['live']);
        await expectOneWholeDatabase(files, versions: {fixtureVersion});
        expect(files.safetyCopy.existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('KP-S snapshot', () {
    late FixtureDatabase db;
    late String target;
    const tables = ['notes', 'tags'];

    setUp(() async {
      await createFixture(File('${dir.path}/fixture.db'));
      db = FixtureDatabase(openDatabaseFile(File('${dir.path}/fixture.db')));
      target = '${dir.path}/backup/fixture.db';
    });

    tearDown(() => db.close());

    Future<void> expectSnapshotThere() async {
      final info = await readSnapshot(target, tables: tables);
      expect(info.userVersion, fixtureVersion);
      expect(info.counts, {'notes': 3, 'tags': 3});
    }

    test('KP-S1 inside VACUUM INTO (a partial .tmp): no snapshot is '
        'reported, and the next snapshot sweeps the .tmp', () async {
      // What a kill inside VACUUM INTO leaves: the first page of a copy.
      final whole = '${dir.path}/whole.db';
      sqlite3.open('${dir.path}/fixture.db')
        ..execute('VACUUM INTO ?', [whole])
        ..close();
      File('$target.tmp')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File(whole).readAsBytesSync().sublist(0, 4096));

      expect(File(target).existsSync(), isFalse);
      await expectLater(
        readSnapshot(target, tables: tables),
        throwsA(anything),
      );

      await snapshot(db, target);

      expect(File('$target.tmp').existsSync(), isFalse);
      await expectSnapshotThere();
    });

    test('KP-S2 the .tmp complete, before the rename: as KP-S1', () async {
      await expectLater(
        snapshot(db, target, onStep: crashAfter(SnapshotStep.tmpWritten)),
        throwsA(isA<SimulatedCrash>()),
      );
      expect(File(target).existsSync(), isFalse);
      expect(File('$target.tmp').existsSync(), isTrue);

      await snapshot(db, target);

      expect(File('$target.tmp').existsSync(), isFalse);
      await expectSnapshotThere();
    });

    test('KP-S3 after the rename, before the directory fsync: the snapshot '
        'is readable, and the order is tmp-write, rename, sync', () async {
      await expectLater(
        snapshot(db, target, onStep: crashAfter(SnapshotStep.renamed)),
        throwsA(isA<SimulatedCrash>()),
      );
      await expectSnapshotThere();

      final sync = RecordingSync(root: dir);
      await snapshot(db, target, syncDirectory: sync.call, onStep: sync.step);

      expect(sync.events, [
        'step:started',
        'step:tmpWritten',
        'step:renamed',
        'sync:backup',
        'step:synced',
      ]);
      await expectSnapshotThere();
    });

    test('KP-S4 hard kill inside VACUUM INTO: as KP-S1, in a fresh '
        'process', () async {
      // Some 40 MB, so the kill lands while VACUUM INTO is still copying.
      await db.customStatement(
        'INSERT INTO notes (title) SELECT hex(randomblob(2000)) FROM '
        '(WITH RECURSIVE r(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM r '
        'WHERE i < 10000) SELECT i FROM r)',
      );
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

      await hardKill(
        'started',
        script: 'test/support/kill_child.dart',
        args: ['snapshot', dir.path, target, 'started'],
        // Once VACUUM INTO has created its target: inside it.
        killWhen: () => File('$target.tmp').existsSync(),
      );
      expect(File('$target.tmp').existsSync(), isTrue);
      expect(File(target).existsSync(), isFalse);

      await snapshot(db, target);

      expect(File('$target.tmp').existsSync(), isFalse);
      final info = await readSnapshot(target, tables: tables);
      expect(info.counts['notes'], 10003);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  test('KP-X1 an exclusively() block ends (integrity check, swap): the '
      'server still serves a second client (2520b90b)', () async {
    final registry = FakePortRegistry();
    final server = DatabaseServer(
      registry: registry,
      portName: databasePortName('fixture'),
    );
    final opening = await openWithSnapshot(
      directory: dir,
      name: 'fixture',
      targetVersion: fixtureVersion,
      open: FixtureDatabase.new,
      log: log.log,
      connect: server.connect,
    );
    await server.publish();
    final db = (opening as Opened<FixtureDatabase>).database;
    addTearDown(db.close);

    for (var i = 0; i < 2; i++) {
      final check = await db.exclusively(
        () => db.customSelect('PRAGMA integrity_check').get(),
      );
      expect(check.single.data.values.single, 'ok');
    }
    expect(
      (await db.customSelect('SELECT count(*) AS n FROM notes').getSingle())
          .read<int>('n'),
      0,
    );

    final client = FixtureDatabase(
      (await connectByName(registry, databasePortName('fixture')))!,
    );
    await client.exclusively(() => client.customSelect('SELECT 1').get());
    await client.customStatement("INSERT INTO notes (title) VALUES ('x')");
    expect(
      (await db.customSelect('SELECT count(*) AS n FROM notes').getSingle())
          .read<int>('n'),
      1,
    );
    expect(registry.mappings.keys, [databasePortName('fixture')]);
    await client.close();
  });
}

/// Closes every connection a crashed open left, as the process's death
/// would have; a close that fails is the crash's, not the test's.
Future<void> dropHandles(List<QueryExecutor> executors) async {
  for (final executor in executors) {
    try {
      await executor.close();
    } on Object {
      // Already gone.
    }
  }
  executors.clear();
}
