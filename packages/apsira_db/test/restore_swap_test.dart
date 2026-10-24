// The restore swap (D-APK-018, AC-13.3), ported from the three apps:
//
// - relay test/data/db/restore_swap_test.dart @ 09b28810: the marker's
//   `.tmp` before the database closes, the safety copy, the marker down
//   (naming the safety copy), the staged database renamed over the file, and
//   the marker removed only at the end; a restore cut short by process
//   death at any point is rolled back by the next open, which puts the
//   safety copy back byte for byte, or, before the marker went down, finds
//   the file untouched. RELAY's settings rows are the fixture's notes.
// - viaticum test/data/db/restore_swap_test.dart @ 78d38e0: its swap cases
//   (the marker naming the safety copy, a missing copy, a lone `.tmp`, the
//   restore's own reopen and its failing migration, the kept and covered
//   copies, a WAL with commits, the staged header and the integrity check).
// - lyceum test/data/db/restore_swap_test.dart @ 9f4ff27, on LYCEUM's layout
//   and RELAY's protocol: a crash after each step and each roll-back step
//   leaves one whole database, the refusals touch nothing, the copies are
//   never overwritten. LYCEUM's media-sweep half stays in LYCEUM.
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

/// LYCEUM's on-disk names (`restore_swap.dart` @ 9f4ff27).
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
  late DatabaseFiles files;
  late MemoryLog log;
  late List<String> syncs;

  String path(String name) => '${dir.path}/$name';

  void sync(Directory d) =>
      syncs.add(d.uri.pathSegments.lastWhere((s) => s.isNotEmpty));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_db_restore_swap_');
    files = DatabaseFiles(dir, name: 'fixture');
    log = MemoryLog();
    syncs = [];
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<DatabaseOpening<FixtureDatabase>> open({
    bool restoring = false,
    String name = 'fixture',
    DatabaseLayout? layout,
    int version = fixtureVersion,
    int? failAt,
  }) => openWithSnapshot(
    directory: dir,
    name: name,
    layout: layout,
    targetVersion: version,
    open: (e) => FixtureDatabase(e, schemaVersion: version, failAt: failAt),
    log: log.log,
    restoring: restoring,
  );

  Future<FixtureDatabase> ready({
    bool restoring = false,
    String name = 'fixture',
    DatabaseLayout? layout,
  }) async {
    final opening = await open(
      restoring: restoring,
      name: name,
      layout: layout,
    );
    expect(opening, isA<Opened<FixtureDatabase>>());
    return (opening as Opened<FixtureDatabase>).database;
  }

  Future<List<String>> titlesOf(GeneratedDatabase db) async => [
    for (final r
        in await db.customSelect('SELECT title FROM notes ORDER BY id').get())
      r.read<String>('title'),
  ];

  Uint8List liveBytes() => File(path('fixture.db')).readAsBytesSync();

  bool exists(String name) =>
      FileSystemEntity.typeSync(path(name)) != FileSystemEntityType.notFound;

  void expectNoMarkers() {
    for (final name in [
      'fixture.db.restoring',
      'fixture.db.restoring.tmp',
      'fixture.db.migrating',
      'fixture.db.migrating.tmp',
    ]) {
      expect(exists(name), isFalse, reason: name);
    }
  }

  /// A closed current-version database holding the note [title].
  Future<Uint8List> closedWith(String title) async {
    await createFixture(files.database, titles: [title]);
    return liveBytes();
  }

  /// The backup to restore, as staging leaves it: a whole database file
  /// holding `backup`.
  Future<File> stagedBackup() async {
    await createFixture(files.stagedDatabase, titles: ['backup']);
    return files.stagedDatabase;
  }

  group('RELAY: the steps in order', () {
    test("begin writes only the marker's .tmp, naming the safety copy, and "
        'a background open backs off from it', () async {
      await closedWith('live');

      beginRestore(files);

      expect(exists('fixture.db.restoring'), isFalse);
      expect(
        File(path('fixture.db.restoring.tmp')).readAsStringSync(),
        'fixture.safety.db',
      );
      final background = await openForBackground(
        directory: dir,
        name: 'fixture',
        targetVersion: fixtureVersion,
        open: FixtureDatabase.new,
        log: log.log,
      );
      expect(
        (background as NotReady<FixtureDatabase>).reason,
        NotReadyReason.restorePending,
      );
    });

    test('the safety copy is the closed file byte for byte, written through '
        'a synced .partial, and its directory is synced', () async {
      final before = await closedWith('live');
      beginRestore(files);

      await writeSafetyCopy(files, syncDirectory: sync);

      expect(files.safetyCopy.readAsBytesSync(), before);
      expect(File('${files.safetyCopy.path}.partial').existsSync(), isFalse);
      expect(syncs, ['snapshots']);
    });

    test('a safety copy is refused while a -wal holds commits: the copy of '
        'the file alone would miss them', () async {
      await closedWith('live');
      File(path('fixture.db-wal')).writeAsBytesSync([1, 2, 3]);
      beginRestore(files);

      await expectLater(
        writeSafetyCopy(files, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
      );
      expect(files.safetyCopy.existsSync(), isFalse);
    });

    test('arming renames the .tmp into the marker, synced; the swap renames '
        'the staged copy over the file and drops the stale -wal and -shm; '
        'finishing removes the marker, synced', () async {
      await closedWith('live');
      final staged = await stagedBackup();
      File(path('fixture.db-wal')).writeAsBytesSync([]);
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      File(path('fixture.db-shm')).writeAsBytesSync([9]);

      armRestore(files, syncDirectory: sync);
      expect(exists('fixture.db.restoring.tmp'), isFalse);
      expect(
        File(path('fixture.db.restoring')).readAsStringSync(),
        'fixture.safety.db',
      );
      await swapIn(files, staged: staged, syncDirectory: sync);
      expect(liveBytes(), staged.readAsBytesSync());
      expect(exists('fixture.db-wal'), isFalse);
      expect(exists('fixture.db-shm'), isFalse);
      expect(exists('fixture.db.restore'), isFalse);

      // The restore's own reopen leaves its marker in place.
      final db = await ready(restoring: true);
      expect(await titlesOf(db), ['backup']);
      await db.close();
      expect(exists('fixture.db.restoring'), isTrue);

      finishRestore(files, syncDirectory: sync);
      expectNoMarkers();
      final base = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      expect(syncs, ['snapshots', base, base, base]);
      final after = await ready();
      addTearDown(after.close);
      expect(await titlesOf(after), ['backup']);
    });

    test('abandoning before the marker went down removes the .tmp and the '
        'partial safety copy, and the file is untouched', () async {
      final before = await closedWith('live');
      beginRestore(files);
      File('${files.safetyCopy.path}.partial')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('half');

      abandonRestore(files, syncDirectory: sync);

      expectNoMarkers();
      expect(File('${files.safetyCopy.path}.partial').existsSync(), isFalse);
      expect(liveBytes(), before);
    });

    test('rolling back puts the safety copy back byte for byte and removes '
        'every marker', () async {
      final before = await closedWith('live');
      final staged = await stagedBackup();
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await swapIn(files, staged: staged, syncDirectory: sync);
      expect(liveBytes(), isNot(before));

      expect(
        await restoreSafetyCopy(
          directory: dir,
          name: 'fixture',
          log: log.log,
          syncDirectory: sync,
        ),
        isTrue,
      );

      expect(liveBytes(), before);
      expectNoMarkers();
      final db = await ready();
      addTearDown(db.close);
      expect(await titlesOf(db), ['live']);
    });
  });

  // Process death at each point: the files as the step left them, then the
  // next launch's open.
  group('RELAY: process death, then the next open', () {
    late Uint8List before;
    late File staged;

    setUp(() async {
      before = await closedWith('live');
      staged = await stagedBackup();
    });

    Future<void> expectRolledBack() async {
      final db = await ready();
      addTearDown(db.close);
      expect(await titlesOf(db), ['live']);
      await db.close();
      expect(liveBytes(), before);
      expectNoMarkers();
    }

    test('after begin: the .tmp goes and the file opens untouched', () async {
      beginRestore(files);
      await expectRolledBack();
    });

    test(
      'after the safety copy, before arming: the file opens untouched',
      () async {
        beginRestore(files);
        await writeSafetyCopy(files, syncDirectory: sync);
        await expectRolledBack();
      },
    );

    test('armed, before the swap: the safety copy goes back', () async {
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await expectRolledBack();
    });

    test(
      'mid-swap, a partial copy beside the file: the safety copy goes back',
      () async {
        beginRestore(files);
        await writeSafetyCopy(files, syncDirectory: sync);
        armRestore(files, syncDirectory: sync);
        File(path('fixture.db.restore'))
            .writeAsBytesSync(staged.readAsBytesSync().sublist(0, 4096));
        await expectRolledBack();
        expect(exists('fixture.db.restore'), isFalse);
      },
    );

    test('after the swap: the safety copy goes back', () async {
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await swapIn(files, staged: staged, syncDirectory: sync);
      await expectRolledBack();
    });

    test(
      'mid-migration, its marker and snapshot down: the safety copy goes '
      "back, not the migration's snapshot, and the migrating marker goes",
      () async {
        beginRestore(files);
        await writeSafetyCopy(files, syncDirectory: sync);
        armRestore(files, syncDirectory: sync);
        await swapIn(files, staged: staged, syncDirectory: sync);
        files.snapshots.createSync(recursive: true);
        staged.copySync(files.snapshot(2).path);
        File(path('fixture.db.migrating'))
            .writeAsStringSync('fixture.pre-v2.db');
        await expectRolledBack();
      },
    );

    test('mid-rebuild, commits in the -wal: the safety copy goes back and '
        'the -wal is not replayed onto it', () async {
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await swapIn(files, staged: staged, syncDirectory: sync);
      final db = await ready(restoring: true);
      await db.customStatement("INSERT INTO notes (title) VALUES ('rebuilt')");
      // Killed: the connection is left open, its -wal on disk.
      expect(exists('fixture.db-wal'), isTrue);
      final wal = File(path('fixture.db-wal')).readAsBytesSync();
      await db.close();
      File(path('fixture.db-wal')).writeAsBytesSync(wal);
      await expectRolledBack();
    });

    test('mid-rollback, the marker down and a partial copy: the next open '
        'finishes it', () async {
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await swapIn(files, staged: staged, syncDirectory: sync);
      File(path('fixture.db.restore')).writeAsBytesSync([1, 2, 3]);
      await expectRolledBack();
    });

    test('after finishing: the restore stands', () async {
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await swapIn(files, staged: staged, syncDirectory: sync);
      finishRestore(files, syncDirectory: sync);
      final db = await ready();
      addTearDown(db.close);
      expect(await titlesOf(db), ['backup']);
      expectNoMarkers();
    });

    test('armed but the safety copy is not on disk: nothing is restored, '
        'safe mode reads the file as it is, and the marker stays', () async {
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      files.safetyCopy.deleteSync();

      final opening = await open();

      expect(
        (opening as SafeMode<FixtureDatabase>).reason,
        SafeModeReason.restoreFailed,
      );
      await opening.reader?.close();
      expect(exists('fixture.db.restoring'), isTrue);
      expect(liveBytes(), before);
    });
  });

  group('VIATICUM: the marker', () {
    void addRow(String title) {
      final raw = sqlite3.open(path('fixture.db'));
      raw.execute('INSERT INTO notes (title) VALUES (?)', [title]);
      raw.close();
    }

    test('naming the safety copy puts the safety copy back at the next open, '
        'never a pre-migration snapshot', () async {
      await closedWith('one');
      await writeSafetyCopy(files, syncDirectory: sync);
      addRow('two');
      files.restoreMarker.writeAsStringSync(files.safetyCopyName);

      final db = await ready();
      await db.close();

      expect(noteTitles(path('fixture.db')), ['one']);
      expect(files.restoreMarker.existsSync(), isFalse);
      expect(files.safetyCopy.existsSync(), isTrue, reason: 'kept');
      expect(
        log.records.map(MemoryLog.fields),
        contains(containsPair('source', 'safetyCopy')),
      );
    });

    test('naming a safety copy that is not there restores nothing: the file '
        'is read as it is and the marker stays', () async {
      await closedWith('one');
      files.restoreMarker.writeAsStringSync(files.safetyCopyName);

      final opening = await open();

      final safe = opening as SafeMode<FixtureDatabase>;
      expect(safe.reason, SafeModeReason.restoreFailed);
      await safe.reader?.close();
      expect(files.restoreMarker.existsSync(), isTrue);
      expect(log.events, contains('db.restoreSnapshotMissing'));
    });

    test('a lone `.tmp` is a restore that never began: it goes, and the file '
        'opens untouched', () async {
      await closedWith('seven');
      files.restoreMarkerTmp.writeAsStringSync(files.safetyCopyName);

      final db = await ready();
      await db.close();

      expect(files.restoreMarkerTmp.existsSync(), isFalse);
      expect(noteTitles(path('fixture.db')), ['seven']);
    });

    test('a migration rollback writes its marker whole: `.tmp` renamed, '
        'nothing left beside it', () async {
      await createFixture(files.database, version: 1);

      final opening = await open(version: 2, failAt: 2);

      final safe = opening as SafeMode<FixtureDatabase>;
      expect(safe.reason, SafeModeReason.migrationFailed);
      await safe.reader?.close();
      expect(files.restoreMarker.existsSync(), isFalse);
      expect(files.restoreMarkerTmp.existsSync(), isFalse);
    });
  });

  group("VIATICUM: the restore's own reopen", () {
    Future<void> swappedToV1() async {
      await createFixture(files.database, version: 2, titles: ['live']);
      await createFixture(
        files.stagedDatabase,
        version: 1,
        titles: ['four', 'five'],
      );
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      armRestore(files, syncDirectory: sync);
      await swapIn(files, syncDirectory: sync);
    }

    test('leaves its marker in place and migrates the swapped file', () async {
      await swappedToV1();

      final opening = await open(restoring: true, version: 2);

      final db = (opening as Opened<FixtureDatabase>).database;
      expect(db.schemaVersion, 2);
      await db.close();
      expect(files.restoreMarker.existsSync(), isTrue);
      expect(noteTitles(path('fixture.db')), ['four', 'five']);
    });

    test('a migration that fails leaves the marker and puts nothing back: '
        'the restore rolls back to its safety copy', () async {
      await swappedToV1();

      final opening = await open(restoring: true, version: 2, failAt: 2);

      final safe = opening as SafeMode<FixtureDatabase>;
      expect(safe.reason, SafeModeReason.migrationFailed);
      expect(safe.reader, isNull);
      expect(files.restoreMarker.readAsStringSync(), files.safetyCopyName);

      expect(
        await restoreSafetyCopy(
          directory: dir,
          name: 'fixture',
          log: log.log,
          syncDirectory: sync,
        ),
        isTrue,
      );
      expect(noteTitles(path('fixture.db')), ['live']);
      expect(files.restoreMarker.existsSync(), isFalse);
    });
  });

  group('VIATICUM: the safety copy', () {
    test('is the closed file byte for byte; an earlier one is kept under a '
        'name of its own, never overwritten', () async {
      await closedWith('one');
      await writeSafetyCopy(files, syncDirectory: sync);
      final first = files.safetyCopy.readAsBytesSync();
      final raw = sqlite3.open(path('fixture.db'));
      raw.execute("INSERT INTO notes (title) VALUES ('two')");
      raw.close();

      await writeSafetyCopy(files, syncDirectory: sync);

      expect(files.safetyCopy.readAsBytesSync(), liveBytes());
      expect(
        File(path('snapshots/fixture.safety-1.db')).readAsBytesSync(),
        first,
      );
      expect(safetyCopies(files).map((f) => f.uri.pathSegments.last).toSet(), {
        'fixture.safety.db',
        'fixture.safety-1.db',
      });
    });

    test('refuses a file whose WAL holds commits', () async {
      await closedWith('one');
      final raw = sqlite3.open(path('fixture.db'))
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA wal_autocheckpoint = 0')
        ..execute("INSERT INTO notes (title) VALUES ('two')");
      addTearDown(raw.close);

      await expectLater(
        writeSafetyCopy(files, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('a backup started after a copy was written covers it: only covered '
        'copies go, never one the marker names', () async {
      await closedWith('one');
      await writeSafetyCopy(files, syncDirectory: sync);
      await writeSafetyCopy(files, syncDirectory: sync);
      final older = File(path('snapshots/fixture.safety-1.db'));
      older.setLastModifiedSync(DateTime.utc(2026, 10, 19, 8));
      files.safetyCopy.setLastModifiedSync(DateTime.utc(2026, 10, 19, 10));
      int at(int hour) =>
          DateTime.utc(2026, 10, 19, hour).millisecondsSinceEpoch;

      // A backup at 09:00 covers the 08:00 copy only.
      expect(
        dropCoveredSafetyCopies(
          files,
          latestOkBackupStart: at(9),
          syncDirectory: sync,
        ),
        1,
      );
      expect(older.existsSync(), isFalse);
      expect(files.safetyCopy.existsSync(), isTrue);

      // While a restore's marker names it, even a later backup keeps it.
      files.restoreMarker.writeAsStringSync(files.safetyCopyName);
      expect(
        dropCoveredSafetyCopies(
          files,
          latestOkBackupStart: at(11),
          syncDirectory: sync,
        ),
        0,
      );
      expect(files.safetyCopy.existsSync(), isTrue);

      files.restoreMarker.deleteSync();
      expect(
        dropCoveredSafetyCopies(
          files,
          latestOkBackupStart: at(11),
          syncDirectory: sync,
        ),
        1,
      );
      expect(safetyCopies(files), isEmpty);
    });

    test('abandoning before the marker is down leaves the file and any '
        'complete safety copy as they were', () async {
      await closedWith('one');
      beginRestore(files);
      await writeSafetyCopy(files, syncDirectory: sync);
      File('${files.safetyCopy.path}.partial').writeAsStringSync('half');

      abandonRestore(files, syncDirectory: sync);

      expect(files.restoreMarkerTmp.existsSync(), isFalse);
      expect(File('${files.safetyCopy.path}.partial').existsSync(), isFalse);
      expect(files.safetyCopy.existsSync(), isTrue);
      expect(noteTitles(path('fixture.db')), ['one']);
    });
  });

  group('VIATICUM: a staged file', () {
    File databaseAt(String name, int version, int rows) {
      final file = File(path('$name.db'));
      final raw = sqlite3.open(file.path);
      raw.execute('CREATE TABLE t1 (x INTEGER)');
      for (var x = 0; x < rows; x++) {
        raw.execute('INSERT INTO t1 (x) VALUES (?)', [x]);
      }
      raw.execute('PRAGMA user_version = $version');
      raw.close();
      return file;
    }

    test('its header names its schema version; a non-database has none', () {
      expect(databaseHeaderVersion(databaseAt('v1', 1, 1)), 1);
      final junk = File(path('junk.db'))..writeAsStringSync('not sqlite' * 20);
      expect(databaseHeaderVersion(junk), isNull);
    });

    test(
      'integrity_check passes a sound file and fails a damaged one',
      () async {
        final sound = databaseAt('sound', 1, 2000);
        expect(await integrityCheckPasses(sound), isTrue);

        final bytes = sound.readAsBytesSync();
        final pageSize = bytes.buffer.asByteData().getUint16(16);
        // The second page holds `t1`'s first b-tree page: its type byte goes.
        bytes[pageSize] = 0x7f;
        final damaged = File(path('damaged.db'))..writeAsBytesSync(bytes);
        expect(await integrityCheckPasses(damaged), isFalse);
      },
      // `PRAGMA integrity_check` runs in an isolate; on a loaded host it
      // has outrun the 30 s default (VIATICUM's final F-3).
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group("LYCEUM's swap tests, on its layout and RELAY's protocol", () {
    late DatabaseFiles lyceum;

    setUp(() => lyceum = DatabaseFiles(dir, name: 'lyceum', layout: _lyceum));

    /// Opens the database as the app will (`openWithSnapshot` on LYCEUM's
    /// layout, which recovers first) and returns its note titles, after
    /// checking it whole.
    Future<List<String>> openAsApp() async {
      final db = await ready(name: 'lyceum', layout: _lyceum);
      try {
        final check = await db.customSelect('PRAGMA integrity_check').get();
        expect(check.single.read<String>('integrity_check'), 'ok');
        return await titlesOf(db);
      } finally {
        await db.close();
      }
    }

    void clear() {
      for (final e in dir.listSync()) {
        e.deleteSync(recursive: true);
      }
    }

    test('a crash after each swap step recovers to one whole database on next open', () async {
      const expected = {
        SwapStep.begun: 'live',
        SwapStep.safetyCopyWritten: 'live',
        SwapStep.armed: 'live',
        SwapStep.stagedWritten: 'live',
        SwapStep.renamedIn: 'live',
        SwapStep.staleCleared: 'live',
        SwapStep.finished: 'restored',
      };
      expect(expected.keys, SwapStep.values);
      for (final MapEntry(key: step, value: data) in expected.entries) {
        await createFixture(lyceum.database, titles: ['live']);
        await createFixture(lyceum.stagedDatabase, titles: ['restored']);
        // An earlier restore's copy, so the safety copy has work to do.
        await createFixture(lyceum.safetyCopy, titles: ['earlier']);

        final hook = crashAfter(step);
        await expectLater(
          () async {
            beginRestore(lyceum, onStep: hook);
            await writeSafetyCopy(lyceum, syncDirectory: sync, onStep: hook);
            armRestore(lyceum, syncDirectory: sync, onStep: hook);
            await swapIn(lyceum, syncDirectory: sync, onStep: hook);
            finishRestore(lyceum, syncDirectory: sync, onStep: hook);
          }(),
          throwsA(isA<SimulatedCrash>()),
          reason: '$step',
        );

        expect(await openAsApp(), [data], reason: '$step');
        expect(lyceum.restoreMarker.existsSync(), isFalse, reason: '$step');
        // The earlier copy is kept under a name of its own once the safety
        // copy is written.
        final kept = File('${lyceum.snapshots.path}/lyceum.safety-1.db');
        expect(kept.existsSync(), step != SwapStep.begun, reason: '$step');
        clear();
      }

      // A marker whose `.tmp` was never renamed is a swap that never
      // began.
      await createFixture(lyceum.database, titles: ['live']);
      lyceum.restoreMarkerTmp.writeAsStringSync('swap', flush: true);
      expect(
        await recoverInterruptedRestore(lyceum, syncDirectory: sync),
        RecoveryOutcome.none,
      );
      expect(lyceum.restoreMarkerTmp.existsSync(), isFalse);
      expect(await openAsApp(), ['live']);
    });

    test(
      'a crash after each roll-back step recovers to the replaced data',
      () async {
        for (final step in RollBackStep.values) {
          await createFixture(lyceum.database, titles: ['live']);
          await createFixture(lyceum.stagedDatabase, titles: ['restored']);
          beginRestore(lyceum);
          await writeSafetyCopy(lyceum, syncDirectory: sync);
          armRestore(lyceum, syncDirectory: sync);
          await swapIn(lyceum, syncDirectory: sync);
          finishRestore(lyceum, syncDirectory: sync);
          expect(await openAsApp(), ['restored']);

          await expectLater(
            rollBack(lyceum, syncDirectory: sync, onStep: crashAfter(step)),
            throwsA(isA<SimulatedCrash>()),
          );

          expect(await openAsApp(), ['live'], reason: '$step');
          expect(lyceum.restoreMarker.existsSync(), isFalse, reason: '$step');
          clear();
        }
      },
    );

    test('the swap refuses a live WAL and a staged file that is not a '
        'database, touching nothing; with no safety copy there is nothing '
        'to roll back to', () async {
      await createFixture(lyceum.database, titles: ['live']);
      final live = lyceum.database.readAsBytesSync();

      await expectLater(
        swapIn(lyceum, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
        reason: 'no staged file',
      );
      File(lyceum.stagedDatabase.path)
        ..createSync(recursive: true)
        ..writeAsStringSync('not a database');
      await expectLater(
        swapIn(lyceum, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
      );
      lyceum.stagedDatabase.deleteSync();
      await createFixture(lyceum.stagedDatabase, titles: ['restored']);
      File('${lyceum.stagedDatabase.path}-wal').writeAsStringSync('commits');
      await expectLater(
        swapIn(lyceum, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
      );
      File('${lyceum.stagedDatabase.path}-wal').deleteSync();
      File('${lyceum.database.path}-wal').writeAsStringSync('commits');
      await expectLater(
        writeSafetyCopy(lyceum, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
      );
      File('${lyceum.database.path}-wal').deleteSync();

      expect(lyceum.database.readAsBytesSync(), live);
      expect(safetyCopies(lyceum), isEmpty);
      await expectLater(
        rollBack(lyceum, syncDirectory: sync),
        throwsA(isA<StateError>()),
      );
    });

    test('safety copies are never overwritten, newest first, and an '
        'export started after a restore covers its copy only', () async {
      final t1 = DateTime.utc(2026, 10, 22, 9);
      final t2 = DateTime.utc(2026, 10, 23, 9);
      Future<void> restore(String title, DateTime at) async {
        await createFixture(lyceum.stagedDatabase, titles: [title]);
        beginRestore(lyceum);
        await writeSafetyCopy(lyceum, syncDirectory: sync);
        lyceum.safetyCopy.setLastModifiedSync(at);
        armRestore(lyceum, syncDirectory: sync);
        await swapIn(lyceum, syncDirectory: sync);
        finishRestore(lyceum, syncDirectory: sync);
        discardStaging(lyceum);
      }

      await createFixture(lyceum.database, titles: ['a']);
      final a = lyceum.database.readAsBytesSync();
      await restore('b', t1);
      final b = lyceum.database.readAsBytesSync();
      await restore('c', t2);

      // Newest first; each byte-identical to the file it replaced.
      final copies = safetyCopies(lyceum);
      expect(
        [for (final c in copies) c.uri.pathSegments.last],
        ['lyceum.safety.db', 'lyceum.safety-1.db'],
      );
      expect(copies[0].readAsBytesSync(), b);
      expect(copies[1].readAsBytesSync(), a);
      expect(copies[0].lastModifiedSync().toUtc(), t2);
      expect(databaseHeaderVersion(copies[1]), fixtureVersion);

      int after(DateTime t) =>
          t.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      expect(
        dropCoveredSafetyCopies(
          lyceum,
          latestOkBackupStart: after(t1),
          syncDirectory: sync,
        ),
        1,
      );
      lyceum.restoreMarker.writeAsStringSync('lyceum.safety.db');
      expect(
        dropCoveredSafetyCopies(
          lyceum,
          latestOkBackupStart: after(t2),
          syncDirectory: sync,
        ),
        0,
      );
      lyceum.restoreMarker.deleteSync();
      expect(
        dropCoveredSafetyCopies(
          lyceum,
          latestOkBackupStart: after(t2),
          syncDirectory: sync,
        ),
        1,
      );
      expect(safetyCopies(lyceum), isEmpty);
    });

    test("LYCEUM's fresh install with no live file: RELAY's protocol has no "
        'file to keep, so the safety copy refuses and nothing moves', () async {
      await createFixture(lyceum.stagedDatabase, titles: ['restored']);
      beginRestore(lyceum);

      await expectLater(
        writeSafetyCopy(lyceum, syncDirectory: sync),
        throwsA(isA<FileSystemException>()),
      );
      abandonRestore(lyceum, syncDirectory: sync);

      expect(lyceum.database.existsSync(), isFalse);
      expect(lyceum.restoreMarker.existsSync(), isFalse);
      expect(noteTitles(lyceum.stagedDatabase.path), ['restored']);
    });

    test(
      'the header version is read from the bytes, null for anything else',
      () async {
        await createFixture(lyceum.database, titles: ['a']);
        expect(databaseHeaderVersion(lyceum.database), fixtureVersion);
        expect(databaseHeaderVersion(File('${dir.path}/missing')), isNull);
        final text = File('${dir.path}/text')
          ..writeAsStringSync('SQLite format 3');
        expect(databaseHeaderVersion(text), isNull);
      },
    );

    test('a directory is synced, a missing one throws', () {
      fsyncDirectory(dir);
      expect(
        () => fsyncDirectory(Directory('${dir.path}/missing')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
