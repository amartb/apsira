// The backup snapshot (D-APK-018, AC-13.3), ported from
// relay test/data/db/backup_snapshot_test.dart @ 09b28810 (`VACUUM INTO` on
// the app's own connection gives a file that opens, passes
// `integrity_check` and holds every row of every table, even while another
// connection writes, and is the database at one commit, but the left-out
// tables, held empty; the counts) and viaticum
// test/data/db/backup_snapshot_test.dart @ 78d38e0 (`readSnapshot`). RELAY's
// schema is the fixture's two tables plus two cache tables the snapshot
// leaves out, as RELAY's VIATICUM copy.
import 'dart:async';
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture_database.dart';

/// The cache tables the snapshot leaves out (RELAY's VIATICUM copy).
const _leavesOut = ['cache_bookings', 'cache_trips'];

/// A body of about 4 KB in mixed EN/ES text, different for each [i].
String _body(int i) =>
    '# Nota $i\n\n${'Una línea con año, ñandú y café; a line in English. ' * 80}';

/// [notes] notes with a body and a tag each, and a row in each cache table.
Future<void> _populate(GeneratedDatabase db, {int notes = 200}) =>
    db.transaction(() async {
      for (final table in _leavesOut) {
        await db.customStatement(
          'CREATE TABLE IF NOT EXISTS $table (id INTEGER PRIMARY KEY, v TEXT)',
        );
        await db.customStatement("INSERT INTO $table (v) VALUES ('cached')");
      }
      for (var i = 0; i < notes; i++) {
        await db.customStatement(
          'INSERT INTO notes (title, body) VALUES (?, ?)',
          ['Nota $i', _body(i)],
        );
        await db.customStatement(
          'INSERT INTO tags (note_id, name, color) '
          "VALUES (last_insert_rowid(), 'Lectura', 'red')",
        );
      }
    });

/// Every table of the file, from `sqlite_master`, without SQLite's own.
Future<List<String>> _fileTables(GeneratedDatabase db) async => [
  for (final row
      in await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' ORDER BY name",
          )
          .get())
    row.read<String>('name'),
];

/// Every row of [table], each as its column values joined, sorted: equal
/// lists mean equal tables, whatever the physical order.
Future<List<String>> _rows(GeneratedDatabase db, String table) async {
  final rows = await db.customSelect('SELECT * FROM "$table"').get();
  return [for (final row in rows) row.data.values.join('\u0000')]..sort();
}

Future<Set<String>> _noteTitles(GeneratedDatabase db) async => {
  for (final row in await db.customSelect('SELECT title FROM notes').get())
    row.read<String>('title'),
};

Future<String> _pragma(GeneratedDatabase db, String pragma) async =>
    (await db.customSelect('PRAGMA $pragma').getSingle()).data.values.single
        .toString();

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late FixtureDatabase db;
  late String target;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('apsira_db_snapshot_');
    db = FixtureDatabase(openDatabaseFile(File('${dir.path}/fixture.db')));
    await db.customSelect('SELECT 1').get();
    target = '${dir.path}/cache/backup/fixture.db';
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<FixtureDatabase> openTarget() async {
    final copy = openSnapshot(target, FixtureDatabase.new);
    addTearDown(copy.close);
    return copy;
  }

  test('the snapshot of a populated database opens, passes integrity_check '
      'and holds every row of every table but the left-out ones, which it '
      'holds empty', () async {
    await _populate(db);

    await snapshot(db, target, leavesOut: _leavesOut);

    final copy = await openTarget();
    expect(await _pragma(copy, 'integrity_check'), 'ok');
    expect(await _pragma(copy, 'user_version'), '$fixtureVersion');
    final tables = await _fileTables(db);
    expect(await _fileTables(copy), tables);
    for (final table in tables) {
      final rows = await _rows(db, table);
      expect(rows, isNotEmpty, reason: table);
      expect(
        await _rows(copy, table),
        _leavesOut.contains(table) ? isEmpty : rows,
        reason: table,
      );
    }
  });

  test('the snapshot is one self-contained file in rollback-journal mode, '
      'and the source keeps its WAL', () async {
    await _populate(db, notes: 3);

    await snapshot(db, target);

    final copy = await openTarget();
    expect(await _pragma(copy, 'journal_mode'), 'delete');
    expect(await _pragma(db, 'journal_mode'), 'wal');
    expect(File('$target-wal').existsSync(), isFalse);
    expect(File('$target.tmp').existsSync(), isFalse);
  });

  test('a snapshot taken while another connection writes is the database '
      'at one commit, and the writer is never blocked', () async {
    await _populate(db, notes: 2000);
    final base = await _noteTitles(db);
    final writer = FixtureDatabase(
      openDatabaseFile(File('${dir.path}/fixture.db')),
    );
    addTearDown(writer.close);
    await writer.customSelect('SELECT 1').get();

    final committed = <String>[];
    var done = false;
    Future<void> write() async {
      for (var i = 0; !done; i++) {
        final title = 'W $i';
        await writer.customStatement(
          'INSERT INTO notes (title, body) VALUES (?, ?)',
          [title, _body(i)],
        );
        committed.add(title);
      }
    }

    final writing = write();
    while (committed.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final atStart = committed.length;
    await snapshot(db, target);
    final atEnd = committed.length;
    done = true;
    await writing;

    expect(atEnd, greaterThan(atStart), reason: 'the writer kept committing');
    final copy = await openTarget();
    expect(await _pragma(copy, 'integrity_check'), 'ok');
    final titles = await _noteTitles(copy);
    final written = titles.difference(base);
    expect(titles.containsAll(base), isTrue);
    expect(written.length, inInclusiveRange(atStart, atEnd));
    expect(
      written,
      committed.take(written.length).toSet(),
      reason: 'a prefix of the writes: the database at one commit',
    );
  });

  test('a write transaction open on another connection is not in the '
      'snapshot, and commits after it', () async {
    await _populate(db, notes: 3);
    final writer = FixtureDatabase(
      openDatabaseFile(File('${dir.path}/fixture.db')),
    );
    addTearDown(writer.close);
    await writer.customSelect('SELECT 1').get();
    final inside = Completer<void>();
    final release = Completer<void>();

    final tx = writer.transaction(() async {
      await writer.customStatement(
        "INSERT INTO notes (title) VALUES ('pending')",
      );
      inside.complete();
      await release.future;
    });
    await inside.future;
    await snapshot(db, target);
    release.complete();
    await tx;

    final copy = await openTarget();
    expect(await _noteTitles(copy), isNot(contains('pending')));
    expect(await _noteTitles(db), contains('pending'));
  });

  test('a file left at the path, and a stale journal beside it, are '
      'replaced', () async {
    await _populate(db, notes: 3);
    File(target)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('not a database');
    File('$target-journal').writeAsStringSync('stale');

    await snapshot(db, target);

    expect(File('$target-journal').existsSync(), isFalse);
    final copy = await openTarget();
    expect(await _pragma(copy, 'integrity_check'), 'ok');
    expect(await _noteTitles(copy), hasLength(3));
  });

  test('the snapshot cannot be written into', () async {
    await _populate(db, notes: 1);
    await snapshot(db, target);

    final copy = await openTarget();
    await expectLater(
      copy.customStatement('DELETE FROM notes'),
      throwsA(isA<Exception>()),
    );
  });

  group('the live database', () {
    test('passing the live path is refused, and the live database and a '
        'committed write are intact', () async {
      final live = '${dir.path}/fixture.db';
      await _populate(db, notes: 3);
      await db.customStatement("INSERT INTO notes (title) VALUES ('kept')");
      final before = await tableCounts(db, ['notes', 'tags']);

      await expectLater(
        snapshot(db, live),
        throwsA(isA<SnapshotTargetIsLive>()),
      );

      expect(File(live).existsSync(), isTrue);
      expect(File('$live-wal').existsSync(), isTrue);
      expect(await _noteTitles(db), contains('kept'));
      await db.close();
      db = FixtureDatabase(openDatabaseFile(File(live)));
      expect(await _pragma(db, 'integrity_check'), 'ok');
      expect(await _noteTitles(db), contains('kept'));
      expect(await tableCounts(db, ['notes', 'tags']), before);
    });

    test('every other spelling of the live files is refused too', () async {
      final live = '${dir.path}/fixture.db';
      await _populate(db, notes: 1);
      final alias = Link('${dir.path}/alias')..createSync(dir.path);
      Directory('${dir.path}/sub').createSync();

      for (final path in [
        '${dir.path}/sub/../fixture.db',
        '${alias.path}/fixture.db',
        '$live-wal',
        '$live-shm',
        '$live-journal',
        '${alias.path}/fixture.db-wal',
      ]) {
        await expectLater(
          snapshot(db, path),
          throwsA(isA<SnapshotTargetIsLive>()),
          reason: path,
        );
      }

      expect(File(live).existsSync(), isTrue);
      expect(File('$live-wal').existsSync(), isTrue);
      expect(File('$live-shm').existsSync(), isTrue);
      expect(await _noteTitles(db), hasLength(1));
    });

    test('a file of the same name in another directory is not the live '
        'one', () async {
      await _populate(db, notes: 1);
      final other = '${dir.path}/sub/fixture.db';

      await snapshot(db, other);

      final copy = openSnapshot(other, FixtureDatabase.new);
      addTearDown(copy.close);
      expect(await _noteTitles(copy), hasLength(1));
    });
  });

  group('counts', () {
    test('tableCounts counts every table it is given, in one select', () async {
      await _populate(db, notes: 7);
      final tables = await _fileTables(db);

      final counts = await tableCounts(db, tables);

      expect(counts.keys.toList(), tables);
      for (final MapEntry(key: table, value: n) in counts.entries) {
        final actual =
            (await db
                    .customSelect('SELECT COUNT(*) AS n FROM "$table"')
                    .getSingle())
                .read<int>('n');
        expect(n, actual, reason: table);
        expect(n, greaterThan(0), reason: table);
      }
      expect(counts['notes'], 7);
    });

    test('the snapshot counts as its source did when it was taken', () async {
      await _populate(db, notes: 7);
      final tables = await _fileTables(db);
      final before = await tableCounts(db, tables);
      await snapshot(db, target, leavesOut: _leavesOut);
      await db.customStatement("INSERT INTO notes (title) VALUES ('later')");

      final copy = await openTarget();
      expect(await tableCounts(copy, tables), {
        ...before,
        for (final table in _leavesOut) table: 0,
      });
      expect((await tableCounts(db, ['notes']))['notes'], 8);
    });
  });

  group("VIATICUM's readSnapshot", () {
    test('reads the user_version, the schema version the app asks for and '
        'every count, read-only', () async {
      await _populate(db, notes: 5);
      await db.customStatement(
        'CREATE TABLE app_meta (id INTEGER PRIMARY KEY, schema_version INTEGER)',
      );
      await db.customStatement(
        'INSERT INTO app_meta VALUES (1, $fixtureVersion)',
      );
      await snapshot(db, target);
      final bytes = File(target).readAsBytesSync();

      final info = await readSnapshot(
        target,
        tables: const ['notes', 'tags'],
        schemaVersionQuery: 'SELECT schema_version FROM app_meta WHERE id = 1',
      );

      expect(info.schemaVersion, fixtureVersion);
      expect(info.userVersion, fixtureVersion);
      expect(info.counts, {'notes': 5, 'tags': 5});
      expect(File(target).readAsBytesSync(), bytes);
      final plain = await readSnapshot(target, tables: const ['notes']);
      expect(plain.schemaVersion, isNull);
    });

    test('reading a file that is not a database fails', () async {
      File(target)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('not a database at all, just text');
      await expectLater(
        readSnapshot(target, tables: const ['notes']),
        throwsA(anything),
      );
    });
  });
}
