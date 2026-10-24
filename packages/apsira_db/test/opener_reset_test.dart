// From relay test/data/db/opener_reset_test.dart @ 09b28810 (D-APK-018,
// AC-13.3): safe mode's way out of `openFailed`. "Reset from the safety
// copy" puts the newest snapshot back as the database, and "Erase and start
// again" removes the database so the next open creates an empty one. Each
// closes safe mode's reader before it touches a file, and leaves the next
// open ready. A reset with no snapshot fails and leaves the file as it was.
// RELAY's settings rows are the fixture's notes; its third group (the app's
// `database.dart` service) stays in RELAY.
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late MemoryLog log;

  String path(String name) => '${dir.path}/$name';

  Future<DatabaseOpening<FixtureDatabase>> open() => openWithSnapshot(
    directory: dir,
    name: 'fixture',
    targetVersion: fixtureVersion,
    open: FixtureDatabase.new,
    log: log.log,
  );

  Future<List<String>> titles(GeneratedDatabase db) async => [
    for (final r
        in await db.customSelect('SELECT title FROM notes ORDER BY id').get())
      r.read<String>('title'),
  ];

  /// A current-version file holding `snapshot`, its snapshot copy (as a
  /// migration from that version would have taken it), and then a later
  /// write, `after`, which the snapshot lacks.
  Future<void> fileWithSnapshot() async {
    final db = ((await open()) as Opened<FixtureDatabase>).database;
    await db.customStatement("INSERT INTO notes (title) VALUES ('snapshot')");
    Directory(path('snapshots')).createSync();
    await db.customStatement('VACUUM INTO ?', [
      path('snapshots/fixture.pre-v$fixtureVersion.db'),
    ]);
    await db.customStatement("INSERT INTO notes (title) VALUES ('after')");
    await db.close();
  }

  /// Makes the database newer than the build, so the open is `openFailed`
  /// with a reader on it.
  void makeNewer() {
    final raw = sqlite3.open(path('fixture.db'));
    raw.userVersion = 99;
    raw.close();
  }

  Future<SafeMode<FixtureDatabase>> safeMode() async {
    final opening = await open();
    expect(opening, isA<SafeMode<FixtureDatabase>>());
    final safe = opening as SafeMode<FixtureDatabase>;
    expect(safe.reason, SafeModeReason.openFailed);
    return safe;
  }

  /// A hook that proves the reader is closed before any file is touched:
  /// a query on it fails, and the database file is still there.
  Future<void> Function() readerClosed(
    ReadOnlyDatabase reader,
    List<String> seen,
  ) => () async {
    seen.add('files');
    expect(File(path('fixture.db')).existsSync(), isTrue);
    await expectLater(reader.customSelect('SELECT 1').get(), throwsA(anything));
  };

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_db_reset_');
    log = MemoryLog();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('safe mode: reset from the safety copy', () {
    test('closes the reader first, puts the newest snapshot back, and the '
        'next open is ready with the snapshot data', () async {
      await fileWithSnapshot();
      makeNewer();
      final safe = await safeMode();
      final reader = safe.reader!;
      expect(hasSnapshot(dir, name: 'fixture'), isTrue);
      final seen = <String>[];

      final reset = await resetFromSnapshot(
        directory: dir,
        name: 'fixture',
        reader: reader,
        log: log.log,
        beforeFiles: readerClosed(reader, seen),
      );

      expect(reset, isTrue);
      expect(seen, ['files']);
      for (final marker in ['fixture.db.restoring', 'fixture.db.migrating']) {
        expect(File(path(marker)).existsSync(), isFalse);
      }
      final db = ((await open()) as Opened<FixtureDatabase>).database;
      addTearDown(db.close);
      expect(await titles(db), ['snapshot']);
      // The safety copy stays for another reset.
      expect(hasSnapshot(dir, name: 'fixture'), isTrue);
      expect(log.events, contains('db.reset'));
    });

    test('with no snapshot there is nothing to reset from: it fails and the '
        'file is as it was', () async {
      final db = ((await open()) as Opened<FixtureDatabase>).database;
      await db.close();
      makeNewer();
      final safe = await safeMode();
      expect(hasSnapshot(dir, name: 'fixture'), isFalse);
      final bytes = File(path('fixture.db')).readAsBytesSync();

      expect(
        await resetFromSnapshot(
          directory: dir,
          name: 'fixture',
          reader: safe.reader,
          log: log.log,
        ),
        isFalse,
      );
      expect(File(path('fixture.db')).readAsBytesSync(), bytes);
      expect(log.events, contains('db.resetNoSnapshot'));
    });
  });

  group('safe mode: erase and start again', () {
    test('closes the reader first, removes the database, its WAL and the '
        'markers, keeps the snapshots, and the next open is an empty '
        'database', () async {
      await fileWithSnapshot();
      makeNewer();
      final safe = await safeMode();
      final reader = safe.reader!;
      File(path('fixture.db.migrating.tmp')).writeAsStringSync('x');
      final seen = <String>[];

      final erased = await eraseDatabase(
        directory: dir,
        name: 'fixture',
        reader: reader,
        log: log.log,
        beforeFiles: readerClosed(reader, seen),
      );

      expect(erased, isTrue);
      expect(seen, ['files']);
      for (final name in [
        'fixture.db',
        'fixture.db-wal',
        'fixture.db-shm',
        'fixture.db.migrating.tmp',
      ]) {
        expect(File(path(name)).existsSync(), isFalse, reason: name);
      }
      expect(hasSnapshot(dir, name: 'fixture'), isTrue);
      final db = ((await open()) as Opened<FixtureDatabase>).database;
      addTearDown(db.close);
      expect(await titles(db), isEmpty);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        fixtureVersion,
      );
      expect(log.events, contains('db.recreated'));
    });

    test('a file that is not a database (no reader) is erased too', () async {
      File(path('fixture.db')).writeAsStringSync('not a database' * 100);
      final safe = await safeMode();
      expect(safe.reader, isNull);

      expect(
        await eraseDatabase(directory: dir, name: 'fixture', log: log.log),
        isTrue,
      );
      expect(await open(), isA<Opened<FixtureDatabase>>());
      final db = ((await open()) as Opened<FixtureDatabase>).database;
      await db.close();
    });
  });
}
