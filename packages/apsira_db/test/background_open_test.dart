// From relay test/data/db/background_open_test.dart @ 09b28810 (D-APK-018,
// AC-13.3). A background open (`openForBackground`) never snapshots,
// migrates, restores or creates. It is ready only for an existing file with
// no restore or migrating marker whose `user_version` is the build's
// target; otherwise it reports `NotReady` and leaves the database, `-wal`,
// `-shm` and `snapshots/` exactly as they were (bytes, size and
// modification time). RELAY's cases; only the names move.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_db/apsira_db.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

const _target = 2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late List<LogRecord> records;
  late Log log;
  late List<String> calls;
  final open = <Database>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_db_background_');
    records = [];
    log = Log([_MemorySink(records)], debugEnabled: false);
    calls = [];
  });

  tearDown(() {
    for (final raw in open) {
      raw.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  String path(String name) => '${dir.path}/$name';

  Future<BackgroundOpening<_Strict>> openInBackground() => openForBackground(
    directory: dir,
    name: 'fixture',
    targetVersion: _target,
    open: (executor) => _Strict(executor, _target, calls),
    log: log,
  );

  /// A WAL database at [version] with one row, checkpointed so the header
  /// carries the version, as the UI's opener leaves it.
  void createAt(int version) {
    final raw = sqlite3.open(path('fixture.db'))
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE t (x INTEGER)')
      ..execute('INSERT INTO t VALUES (1)')
      ..execute('PRAGMA user_version = $version')
      ..execute('PRAGMA wal_checkpoint(TRUNCATE)');
    raw.close();
  }

  /// A second connection that stays open with frames in the WAL, so `-wal`
  /// and `-shm` exist while the background open runs.
  void holdWal() {
    final raw = sqlite3.open(path('fixture.db'))
      ..execute('PRAGMA wal_autocheckpoint = 0')
      ..execute('INSERT INTO t VALUES (2)');
    open.add(raw);
  }

  /// Every file the open must not touch: name → [size, mtime, bytes].
  Map<String, List<Object>> files() {
    final found = <String, List<Object>>{};
    void add(File f, String name) {
      final stat = f.statSync();
      found[name] = [stat.size, stat.modified, f.readAsBytesSync().toList()];
    }

    for (final name in ['fixture.db', 'fixture.db-wal', 'fixture.db-shm']) {
      final f = File(path(name));
      if (f.existsSync()) add(f, name);
    }
    final snapshots = Directory(path('snapshots'));
    if (snapshots.existsSync()) {
      found['snapshots/'] = [snapshots.statSync().modified];
      for (final f in snapshots.listSync().whereType<File>()) {
        add(f, 'snapshots/${f.uri.pathSegments.last}');
      }
    }
    return found;
  }

  Future<void> expectNotReady(NotReadyReason reason) async {
    final before = files();
    final opening = await openInBackground();
    expect(opening, isA<NotReady<_Strict>>());
    expect((opening as NotReady<_Strict>).reason, reason);
    expect(files(), before, reason: 'the files are untouched');
    expect(calls, isEmpty, reason: 'nothing created or migrated');
    expect(
      records.map((r) => r.event),
      isNot(anyOf(contains('db.snapshot'), contains('db.restored'))),
    );
  }

  test('a missing file is not created', () async {
    await expectNotReady(NotReadyReason.noDatabase);
    expect(dir.listSync(), isEmpty);
  });

  test('an older file is not migrated, with -wal and -shm present', () async {
    createAt(1);
    holdWal();
    expect(File(path('fixture.db-wal')).existsSync(), isTrue);
    expect(File(path('fixture.db-shm')).existsSync(), isTrue);

    await expectNotReady(NotReadyReason.versionMismatch);
    expect(Directory(path('snapshots')).existsSync(), isFalse);
  });

  test('a newer file is not touched', () async {
    createAt(3);
    holdWal();
    await expectNotReady(NotReadyReason.versionMismatch);
  });

  test('a file at version 0 (a creation cut short) is not created', () async {
    createAt(0);
    await expectNotReady(NotReadyReason.versionMismatch);
  });

  test('an empty file is not created', () async {
    File(path('fixture.db')).writeAsBytesSync(const []);
    await expectNotReady(NotReadyReason.versionMismatch);
  });

  test('a pending restore is not finished, even at the target', () async {
    createAt(_target);
    holdWal();
    Directory(path('snapshots')).createSync();
    sqlite3.open(path('snapshots/fixture.pre-v1.db'))
      ..execute('CREATE TABLE t (x INTEGER)')
      ..execute('PRAGMA user_version = 1')
      ..close();
    File(path('fixture.db.restoring')).writeAsStringSync('1');

    await expectNotReady(NotReadyReason.restorePending);
    expect(File(path('fixture.db.restoring')).existsSync(), isTrue);
  });

  test('a restore marker\'s temporary file alone is a pending restore too '
      '(P1-01a)', () async {
    createAt(_target);
    holdWal();
    File(path('fixture.db.restoring.tmp'))
        .writeAsStringSync('fixture.pre-v1.db');

    await expectNotReady(NotReadyReason.restorePending);
    expect(File(path('fixture.db.restoring.tmp')).existsSync(), isTrue);
  });

  test('a file that is not a database is not opened', () async {
    File(path('fixture.db')).writeAsStringSync('not a database' * 100);
    await expectNotReady(NotReadyReason.openFailed);
  });

  test('a header at the target over a WAL at another version is refused '
      'by the connection itself', () async {
    // The header is a pre-check; the connection reads the version through
    // the WAL and refuses before drift could migrate.
    createAt(_target);
    final raw = sqlite3.open(path('fixture.db'))
      ..execute('PRAGMA wal_autocheckpoint = 0')
      ..execute('PRAGMA user_version = 1');
    open.add(raw);

    final opening = await openInBackground();

    expect(
      (opening as NotReady<_Strict>).reason,
      NotReadyReason.versionMismatch,
    );
    expect(calls, isEmpty);
    expect(raw.userVersion, 1);
  });

  test('a background open that overlaps the UI migration (gated inside its '
      'transaction) is versionMismatch and writes nothing (P0-18a review '
      '#2)', () async {
    createAt(1);
    final midMigration = Completer<void>();
    final release = Completer<void>();
    final uiCalls = <String>[];

    final uiOpening = openWithSnapshot(
      directory: dir,
      name: 'fixture',
      targetVersion: _target,
      open: (executor) =>
          _Gated(executor, _target, uiCalls, midMigration, release),
      log: log,
    );
    // The UI's migration transaction is open and has written; it waits
    // here until the background open has answered.
    await midMigration.future;

    final answer = await _backgroundOpenInIsolate(dir.path);

    expect(release.isCompleted, isFalse, reason: 'still inside the migration');
    // The migrating marker is down from the snapshot on (P1-01a, R-10).
    expect(answer.reason, NotReadyReason.migrationPending.name);
    expect(answer.calls, isEmpty, reason: 'nothing created or migrated');
    release.complete();
    final opened = await uiOpening;
    final db = (opened as Opened<_Gated>).database;
    expect(uiCalls, ['upgrade 1->$_target']);
    expect(await _count(db), 2, reason: 'the row and the migration only');
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      _target,
    );
    await db.close();

    // After the migration, and its checkpoint, the same open is ready.
    final after = await _backgroundOpenInIsolate(dir.path);
    expect(after.reason, isNull);
    expect(after.calls, isEmpty);
  });

  test('F-9: a background open racing a migration that fails at drift\'s '
      'user-version write is notReady, and the restore puts the snapshot '
      'back byte for byte with no -wal or -shm of the failed attempt '
      '(P1-01a)', () async {
    createAt(1);
    final committed = Completer<void>();
    final release = Completer<void>();
    final uiCalls = <String>[];

    final uiOpening = openWithSnapshot(
      directory: dir,
      name: 'fixture',
      targetVersion: _target,
      open: (executor) =>
          _FailsAtVersionWrite(executor, _target, uiCalls, committed, release),
      log: log,
    );
    // The migration's transaction has committed, `user_version` with it, as
    // `migrateWithForeignKeysOff` does; drift's own write of the version
    // comes next and will fail.
    await committed.future;
    final snapshot = File(path('snapshots/fixture.pre-v1.db'))
        .readAsBytesSync();

    final answer = await _backgroundOpenInIsolate(dir.path);

    expect(release.isCompleted, isFalse, reason: 'still before the write');
    expect(
      answer.reason,
      NotReadyReason.migrationPending.name,
      reason: 'notReady inside the window',
    );
    expect(answer.calls, isEmpty, reason: 'nothing created or migrated');
    release.complete();
    final opening = await uiOpening;
    final safe = opening as SafeMode<_FailsAtVersionWrite>;
    expect(safe.reason, SafeModeReason.migrationFailed);
    expect(uiCalls, ['upgrade 1->$_target']);
    expect(
      records.map((r) => r.event),
      containsAllInOrder(['db.migrationFailed', 'db.restored']),
    );
    // While safe mode reads it, the WAL holds no frame of the failed attempt.
    final wal = File(path('fixture.db-wal'));
    if (wal.existsSync()) expect(wal.lengthSync(), 0);
    expect(await _count(safe.reader!), 1, reason: 'the snapshot\'s one row');
    await safe.reader!.close();

    expect(File(path('fixture.db')).readAsBytesSync(), snapshot);
    expect(File(path('fixture.db-wal')).existsSync(), isFalse);
    expect(File(path('fixture.db-shm')).existsSync(), isFalse);
    expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
    expect(File(path('fixture.db.restoring.tmp')).existsSync(), isFalse);
    expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
  });

  test('R-8: a migration whose commit goes over 1,000 WAL pages '
      'auto-checkpoints, so the header is at the target before drift\'s '
      'user-version write fails; the migrating marker makes the background '
      'open back off, and the restore puts the snapshot back byte for byte '
      '(P1-01a, R-10)', () async {
    createAt(1);
    final committed = Completer<void>();
    final release = Completer<void>();
    final uiCalls = <String>[];

    final uiOpening = openWithSnapshot(
      directory: dir,
      name: 'fixture',
      targetVersion: _target,
      open: (executor) => _FailsAtVersionWrite(
        executor,
        _target,
        uiCalls,
        committed,
        release,
        rows: 2000,
      ),
      log: log,
    );
    await committed.future;
    final snapshot = File(path('snapshots/fixture.pre-v1.db'))
        .readAsBytesSync();
    // R-8 reproduced: the commit checkpointed, and the header, which the
    // background open reads first, already carries the target.
    final header = File(path('fixture.db')).openSync();
    final bytes = header.readSync(64);
    header.closeSync();
    expect(bytes.buffer.asByteData().getUint32(60), _target);
    expect(
      File(path('fixture.db.migrating')).readAsStringSync(),
      'fixture.pre-v1.db',
    );
    expect(File(path('fixture.db.migrating.tmp')).existsSync(), isFalse);
    final before = files();

    final answer = await _backgroundOpenInIsolate(dir.path);

    expect(release.isCompleted, isFalse, reason: 'still before the write');
    expect(answer.reason, NotReadyReason.migrationPending.name);
    expect(answer.calls, isEmpty, reason: 'nothing created or migrated');
    expect(files(), before, reason: 'the background open wrote nothing');
    release.complete();
    final opening = await uiOpening;
    final safe = opening as SafeMode<_FailsAtVersionWrite>;
    expect(safe.reason, SafeModeReason.migrationFailed);
    expect(await _count(safe.reader!), 1, reason: 'the snapshot\'s one row');
    await safe.reader!.close();

    expect(File(path('fixture.db')).readAsBytesSync(), snapshot);
    expect(File(path('fixture.db-wal')).existsSync(), isFalse);
    expect(File(path('fixture.db-shm')).existsSync(), isFalse);
    expect(File(path('fixture.db.migrating')).existsSync(), isFalse);
    expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
  });

  for (final marker in ['fixture.db.migrating', 'fixture.db.migrating.tmp']) {
    test('a $marker at the target is a migration under way: notReady, '
        'untouched (P1-01a, R-10)', () async {
      createAt(_target);
      holdWal();
      File(path(marker)).writeAsStringSync('fixture.pre-v1.db');

      await expectNotReady(NotReadyReason.migrationPending);
      expect(File(path(marker)).existsSync(), isTrue);
    });
  }

  test('the connection checks the markers before it opens the file: a '
      'restore begun after the early check is restorePending, not a failed '
      'open of the file it replaces (P1-01a)', () async {
    createAt(_target);

    final opening = await openForBackground(
      directory: dir,
      name: 'fixture',
      targetVersion: _target,
      open: (executor) => _Strict(executor, _target, calls),
      log: log,
      beforeConnect: () {
        // A restore under way: its marker, and a file that is not yet a
        // database.
        File(path('fixture.db.restoring'))
            .writeAsStringSync('fixture.pre-v1.db');
        File(path('fixture.db')).writeAsStringSync('not a database' * 100);
      },
    );

    expect(
      (opening as NotReady<_Strict>).reason,
      NotReadyReason.restorePending,
    );
    expect(calls, isEmpty);
  });

  for (final (marker, reason) in [
    (_putMigratingMarker, NotReadyReason.migrationPending),
    (_putRestoreMarker, NotReadyReason.restorePending),
  ]) {
    test(
      'the connection checks the markers again after it has read the '
      'version: a marker that appears then is ${reason.name} (P1-01a)',
      () async {
        createAt(_target);

        final opening = await openForBackground(
          directory: dir,
          name: 'fixture',
          targetVersion: _target,
          open: (executor) => _Strict(executor, _target, calls),
          log: log,
          afterVersionRead: marker,
        );

        expect((opening as NotReady<_Strict>).reason, reason);
        expect(calls, isEmpty);
      },
    );
  }

  test('a file at the target opens, with the four pragmas, and nothing is '
      'created or migrated', () async {
    createAt(_target);
    holdWal();

    final opening = await openInBackground();

    expect(opening, isA<OpenedInBackground<_Strict>>());
    final db = (opening as OpenedInBackground<_Strict>).database;
    addTearDown(db.close);
    Future<Object?> pragma(String name) async =>
        (await db.customSelect('PRAGMA $name').getSingle()).data.values.single;
    expect(await pragma('journal_mode'), 'wal');
    expect(await pragma('foreign_keys'), 1);
    expect(await pragma('busy_timeout'), 5000);
    expect(await pragma('synchronous'), 2); // FULL
    expect(await pragma('user_version'), _target);
    await db.customStatement('INSERT INTO t VALUES (3)');
    expect(
      (await db.customSelect('SELECT count(*) AS n FROM t').getSingle())
          .read<int>('n'),
      3,
    );
    expect(calls, isEmpty);
    expect(Directory(path('snapshots')).existsSync(), isFalse);
  });
}

/// Test seams for the connection's isolate: top level, so they can be sent.
void _putMigratingMarker(String dbPath) =>
    File('$dbPath.migrating').writeAsStringSync('fixture.pre-v1.db');

void _putRestoreMarker(String dbPath) =>
    File('$dbPath.restoring').writeAsStringSync('fixture.pre-v1.db');

/// In a new isolate, as a background entry point does: [openForBackground]
/// on [directory] with a strict schema, then close. The reason it was not
/// ready (null when it opened) and the strict schema's calls.
Future<({String? reason, List<String> calls})> _backgroundOpenInIsolate(
  String directory,
) => Isolate.run(() => _backgroundOpen(directory));

Future<({String? reason, List<String> calls})> _backgroundOpen(
  String directory,
) async {
  final calls = <String>[];
  final opening = await openForBackground(
    directory: Directory(directory),
    name: 'fixture',
    targetVersion: _target,
    open: (executor) => _Strict(executor, _target, calls),
    log: Log(const [], debugEnabled: false),
  );
  switch (opening) {
    case OpenedInBackground(:final database):
      await database.close();
      return (reason: null, calls: calls);
    case NotReady(:final reason):
      return (reason: reason.name, calls: calls);
  }
}

Future<int> _count(GeneratedDatabase db) async =>
    (await db.customSelect('SELECT count(*) AS n FROM t').getSingle())
        .read<int>('n');

/// The UI's schema for the overlap test: its upgrade, in one transaction
/// as the real one, inserts a row, then signals [midMigration] and waits
/// for [release] before it commits.
final class _Gated extends GeneratedDatabase {
  _Gated(
    super.executor,
    this.schemaVersion,
    this.calls,
    this.midMigration,
    this.release,
  );

  @override
  final int schemaVersion;

  final List<String> calls;
  final Completer<void> midMigration;
  final Completer<void> release;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async => calls.add('create'),
    onUpgrade: (_, from, to) => transaction(() async {
      calls.add('upgrade $from->$to');
      await customStatement('INSERT INTO t VALUES (9)');
      midMigration.complete();
      await release.future;
    }),
  );
}

/// F-9's UI schema: its upgrade commits, in one transaction, a row and the
/// new `user_version` (as `migrateWithForeignKeysOff` does), signals
/// [committed], waits for [release], and then turns the connection
/// `query_only`, so drift's own write of the version
/// (`setSchemaVersion`, after `onUpgrade` returns) fails and the opener
/// restores the snapshot.
final class _FailsAtVersionWrite extends GeneratedDatabase {
  _FailsAtVersionWrite(
    super.executor,
    this.schemaVersion,
    this.calls,
    this.committed,
    this.release, {
    this.rows = 0,
  });

  @override
  final int schemaVersion;

  final List<String> calls;
  final Completer<void> committed;
  final Completer<void> release;

  /// Extra rows of 4,000 random bytes the upgrade inserts: 2,000 make a
  /// commit of about 2,000 WAL pages, over SQLite's auto-checkpoint of
  /// 1,000 (R-8).
  final int rows;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async => calls.add('create'),
    onUpgrade: (_, from, to) async {
      calls.add('upgrade $from->$to');
      await transaction(() async {
        await customStatement('INSERT INTO t VALUES (9)');
        if (rows > 0) {
          await customStatement('CREATE TABLE big (b BLOB)');
          await customStatement(
            'INSERT INTO big SELECT '
            'randomblob(4000) FROM (WITH RECURSIVE r(i) AS (SELECT 1 '
            'UNION ALL SELECT i + 1 FROM r WHERE i < $rows) SELECT i FROM r)',
          );
        }
        await customStatement('PRAGMA user_version = $to');
      });
      committed.complete();
      await release.future;
      await customStatement('PRAGMA query_only = ON');
    },
  );
}

/// A test schema whose every create and upgrade is recorded in [calls]: a
/// background open must leave it empty.
final class _Strict extends GeneratedDatabase {
  _Strict(super.executor, this.schemaVersion, this.calls);

  @override
  final int schemaVersion;

  final List<String> calls;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async => calls.add('create'),
    onUpgrade: (_, from, to) async => calls.add('upgrade $from->$to'),
  );
}

final class _MemorySink implements LogSink {
  _MemorySink(this.records);

  final List<LogRecord> records;

  @override
  void write(LogRecord record) => records.add(record);
}
