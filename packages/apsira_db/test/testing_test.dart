// `package:apsira_db/testing.dart` (D-APK-018): the helpers an app's crash
// matrix uses, each proved to catch what it claims to catch.
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late DatabaseFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_db_testing_');
    files = DatabaseFiles(dir, name: 'fixture');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('crashAfter throws only after its own step', () {
    final hook = crashAfter(SwapStep.armed);
    hook(SwapStep.begun);
    hook(OpenStep.markerDown);
    expect(
      () => hook(SwapStep.armed),
      throwsA(
        isA<SimulatedCrash>().having((c) => c.step, 'step', SwapStep.armed),
      ),
    );
  });

  group('expectOneWholeDatabase', () {
    test('passes one whole database at an allowed version', () async {
      await createFixture(files.database);
      await expectOneWholeDatabase(files, versions: {fixtureVersion});
    });

    test('fails a missing database, a marker left, another version and a '
        'damaged file', () async {
      await expectLater(
        expectOneWholeDatabase(files, versions: {fixtureVersion}),
        throwsA(isA<DatabaseCheckFailed>()),
        reason: 'missing',
      );
      await createFixture(files.database);
      await expectLater(
        expectOneWholeDatabase(files, versions: {1}),
        throwsA(isA<DatabaseCheckFailed>()),
        reason: 'version',
      );
      for (final marker in [
        files.restoreMarker,
        files.restoreMarkerTmp,
        files.migratingMarker,
        files.migratingMarkerTmp,
      ]) {
        marker.writeAsStringSync('x');
        await expectLater(
          expectOneWholeDatabase(files, versions: {fixtureVersion}),
          throwsA(isA<DatabaseCheckFailed>()),
          reason: marker.path,
        );
        marker.deleteSync();
      }
      // Many rows, then the type byte of the notes table's root page gone.
      sqlite3.open(files.database.path)
        ..execute(
          'INSERT INTO notes (title) SELECT hex(randomblob(500)) FROM '
          '(WITH RECURSIVE r(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM r '
          'WHERE i < 500) SELECT i FROM r)',
        )
        ..execute('PRAGMA wal_checkpoint(TRUNCATE)')
        ..close();
      final raw = sqlite3.open(files.database.path);
      final root =
          raw
                  .select(
                    "SELECT rootpage FROM sqlite_master WHERE name = 'notes'",
                  )
                  .single['rootpage']!
              as int;
      raw.close();
      final bytes = files.database.readAsBytesSync();
      final pageSize = bytes.buffer.asByteData().getUint16(16);
      bytes[(root - 1) * pageSize] = 0x7f;
      files.database.writeAsBytesSync(bytes);
      await expectLater(
        expectOneWholeDatabase(files, versions: {fixtureVersion}),
        throwsA(anything),
        reason: 'damaged',
      );
    });
  });

  test('RecordingSync records syncs and steps in order, relative to its '
      'root, and fails when told', () {
    final sync = RecordingSync(
      root: dir,
      failWhen: (d) => d.path.endsWith('x'),
    );
    sync.step(SwapStep.armed);
    sync(dir);
    sync(Directory('${dir.path}/snapshots'));
    expect(sync.events, ['step:armed', 'sync:.', 'sync:snapshots']);
    expect(sync.syncs, ['.', 'snapshots']);
    expect(
      () => sync(Directory('${dir.path}/x')),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('killEveryMigrationStep kills each step of an upgrade and finds the '
      'next open whole', () async {
    final log = MemoryLog();
    var opens = 0;

    await killEveryMigrationStep(
      directory: dir,
      name: 'fixture',
      targetVersion: fixtureVersion,
      steps: [2, 3, 4],
      createOld: () => createFixture(files.database, version: 1),
      open: (executor, onStep) {
        opens++;
        return FixtureDatabase(executor, onStep: onStep);
      },
      log: log.log,
    );

    expect(opens, 6, reason: 'one crashed open and one reopen per step');
    expect(noteTitles(files.database.path), ['one', 'two', 'three']);
    expect(
      log.events.where((e) => e == 'db.migrationInterrupted'),
      hasLength(3),
    );
  });

  test(
    'killEveryMigrationStep fails a step the upgrade never reaches',
    () async {
      await expectLater(
        killEveryMigrationStep(
          directory: dir,
          name: 'fixture',
          targetVersion: fixtureVersion,
          steps: [9],
          createOld: () => createFixture(files.database, version: 1),
          open: (executor, onStep) => FixtureDatabase(executor, onStep: onStep),
          log: MemoryLog().log,
        ),
        throwsA(isA<DatabaseCheckFailed>()),
      );
    },
  );

  test('hardKill fails when the child never reaches its step', () async {
    await createFixture(files.database, titles: ['live']);
    await createFixture(files.stagedDatabase, titles: ['restored']);

    await expectLater(
      hardKill(
        'never',
        script: 'test/support/kill_child.dart',
        args: ['swap', dir.path, 'never'],
      ),
      throwsA(isA<DatabaseCheckFailed>()),
    );
    // The child ran the whole swap.
    expect(noteTitles(files.database.path), ['restored']);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
