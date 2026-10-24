// From lyceum test/data/db/json_load_test.dart @ 9f4ff27 (its generic
// cases; LYCEUM's v1 → v2 ref rewrite and its derived index stay in LYCEUM,
// passed in as `upgrade` and `afterLoad`): `tables` built into a fresh
// database file at the current schema, parents first, in one transaction,
// then checked (foreign keys, integrity, counts) before the swap may take
// it. A document the load cannot take leaves no file behind. Then the
// golden (AC-14.3): LYCEUM v1.0.0's own `lyceum.json` example, loaded and
// written back by the package, byte for byte.
import 'dart:convert';
import 'dart:io';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_exchange/apsira_exchange.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'support/apps.dart';
import 'support/db.dart';

List<Map<String, Object?>> _rows(Map<String, Object?> tables, String name) =>
    (tables[name]! as List).cast<Map<String, Object?>>();

Future<String> _dump(DatabaseConnectionUser db) async {
  final out = StringBuffer();
  await JsonDump(db).writeTables(out, await exportedTables(db));
  return out.toString();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late File target;
  setUp(() {
    dir = scratch('load');
    target = File('${dir.path}/restore/built.db');
  });

  Future<Result<LoadSummary, LoadRefused>> load(
    Map<String, Object?> tables, {
    int bundleSchema = 2,
    int currentSchema = 2,
    List<String> ddl = smallSchema,
    Future<void> Function(GeneratedDatabase db, int from)? upgrade,
    Future<void> Function(GeneratedDatabase db)? afterLoad,
    List<String>? loadOrder,
  }) => buildDatabaseFrom(
    target,
    tables,
    bundleSchema: bundleSchema,
    currentSchema: currentSchema,
    open: (e) => SqlDatabase(e, ddl: ddl, version: currentSchema),
    upgrade: upgrade,
    afterLoad: afterLoad,
    loadOrder: loadOrder,
  );

  List<String> leftovers() => [
    if (target.parent.existsSync())
      for (final f in target.parent.listSync()) f.uri.pathSegments.last,
  ];

  test('dump then load gives equal rows in every table, foreign keys '
      'checked', () async {
    final tables = smallTables();
    final built = await load(tables);
    expect(built.valueOrNull?.counts, {
      'works': 3,
      'parts': 2,
      'tags': 1,
      'alarms': 1,
    });

    final snapshot = SqlDatabase.file(target, version: 2);
    try {
      final written = jsonDecode(await _dump(snapshot)) as Map<String, Object?>;
      expect(written, jsonDecode(jsonEncode(tables)));
      expect(
        await snapshot.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await snapshot.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
    } finally {
      await snapshot.close();
    }
    expect(File('${target.path}-wal').existsSync(), isFalse);

    // A row whose parent is not in the document is refused; nothing stays.
    final dangling = smallTables();
    _rows(dangling, 'parts').first['work_id'] = 'no-such-work';
    expect(
      (await load(dangling)).failureOrNull?.refusal,
      LoadRefusal.notABundle,
    );
    expect(leftovers(), isEmpty);
  });

  test('parents first by foreign key; a self-reference and a given order '
      'load too', () async {
    final db = SqlDatabase.memory(smallSchema);
    addTearDown(db.close);
    expect(await loadOrderOf(db), ['alarms', 'works', 'parts', 'tags']);
    expect(await loadOrderOf(db, exclude: {'alarms'}), [
      'works',
      'parts',
      'tags',
    ]);
    // Children before parents: the deferred keys still hold at commit.
    final built = await load(
      smallTables(),
      loadOrder: ['tags', 'parts', 'works', 'alarms'],
    );
    expect(built.isOk, isTrue);
  });

  test('a document of an older schema loads with defaults for absent '
      'columns and gets every upgrade from its version on, before afterLoad; '
      'a newer one is refused', () async {
    final tables = smallTables();
    for (final row in _rows(tables, 'works')) {
      row.remove('words');
    }
    final steps = <String>[];
    final built = await load(
      tables,
      bundleSchema: 1,
      currentSchema: 3,
      upgrade: (db, from) async {
        steps.add('upgrade $from');
        await db.customStatement("UPDATE works SET title = title || ' v$from'");
      },
      afterLoad: (db) async => steps.add('afterLoad'),
    );
    expect(built.isOk, isTrue);
    expect(steps, ['upgrade 1', 'upgrade 2', 'afterLoad']);
    final snapshot = SqlDatabase.file(target, version: 3);
    try {
      final rows = await snapshot
          .customSelect('SELECT DISTINCT words, title FROM works ORDER BY id')
          .get();
      expect(rows.first.data, {'words': 0, 'title': 'Obra 0 v1 v2'});
    } finally {
      await snapshot.close();
    }

    steps.clear();
    await load(
      tables,
      bundleSchema: 3,
      currentSchema: 3,
      upgrade: (db, from) async => steps.add('upgrade $from'),
    );
    expect(steps, isEmpty, reason: 'a current-schema document needs no step');

    expect(
      (await load(tables, bundleSchema: 3)).failureOrNull?.refusal,
      LoadRefusal.schemaTooNew,
    );
    expect(leftovers(), isEmpty);
  });

  test('a table, a column or a value the schema does not have is refused '
      'with nothing left', () async {
    final unknownTable = smallTables()..['registered_alarms'] = <Object?>[];
    final unknownColumn = smallTables();
    _rows(unknownColumn, 'works').first['legacy_rating'] = 3;
    final notRows = smallTables()..['works'] = {'id': 'w0'};
    final notAValue = smallTables();
    _rows(notAValue, 'works').first['title'] = ['a', 'list'];
    final notBase64 = smallTables();
    _rows(notBase64, 'parts').first['cover'] = '%%%';
    final notNull = smallTables();
    _rows(notNull, 'works').first['title'] = null;

    for (final tables in [
      unknownTable,
      unknownColumn,
      notRows,
      notAValue,
      notBase64,
      notNull,
    ]) {
      final refused = (await load(tables)).failureOrNull;
      expect(refused?.refusal, LoadRefusal.notABundle);
      expect(refused?.code, 'loadNotABundle');
      expect(leftovers(), isEmpty);
    }
    expect(
      (await load(smallTables(), bundleSchema: 0)).failureOrNull?.refusal,
      LoadRefusal.notABundle,
    );
  });

  test('an absent table loads empty and a stale file at the path is '
      'replaced', () async {
    target
      ..createSync(recursive: true)
      ..writeAsStringSync('a build cut short');
    File('${target.path}-journal').writeAsStringSync('stale');
    final built = await load(smallTables()..remove('tags'));
    expect(built.valueOrNull?.counts['tags'], 0);
    expect(File('${target.path}-journal').existsSync(), isFalse);
  });

  test('a BLOB column\'s base64 text is stored as bytes', () async {
    expect((await load(smallTables())).isOk, isTrue);
    final snapshot = SqlDatabase.file(target, version: 2);
    try {
      final row = await snapshot
          .customSelect(
            "SELECT typeof(cover) AS t, cover FROM parts WHERE id = 'p1'",
          )
          .getSingle();
      expect(row.read<String>('t'), 'blob');
      expect(row.read<Uint8List>('cover'), [0, 1, 2]);
    } finally {
      await snapshot.close();
    }
  });

  group('LYCEUM v1.0.0 (AC-14.3)', () {
    final example = File(
      '$lyceumExchange/examples/valid/lyceum-export-synthetic.json',
    );

    test('its synthetic lyceum.json, loaded and written back by the package, '
        'is byte for byte the example the tag ships', () async {
      final bytes = example.readAsBytesSync();
      final doc = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final read = checkEnvelopeUtf8(
        bytes,
        formats: {lyceumFormat},
        currentSchemaVersion: 2,
      );
      final info = (read as EnvelopeOk).envelope;
      final tables = doc['tables']! as Map<String, Object?>;

      final built = await load(
        tables,
        bundleSchema: info.schemaVersion!,
        ddl: lyceumDdl(),
      );
      expect(built.valueOrNull?.counts, {
        for (final MapEntry(:key, :value) in tables.entries)
          key: (value! as List).length,
      });

      final snapshot = SqlDatabase.file(target, version: 2);
      try {
        final out = StringBuffer();
        final counts = await writeExport(
          out,
          envelope: lyceumEnvelope(
            appVersion: info.producer!.appVersion,
            producedAt: info.producedAt!,
            schemaVersion: info.schemaVersion!,
          ),
          dump: JsonDump(snapshot),
          tables: await exportedTables(snapshot),
        );
        expect(utf8.encode(out.toString()), bytes);
        expect(counts.keys, tables.keys);
      } finally {
        await snapshot.close();
      }
    });

    test('its minimal lyceum.json is the envelope with no tables', () {
      final minimal = File(
        '$lyceumExchange/examples/valid/lyceum-export-minimal.json',
      ).readAsStringSync();
      expect(
        lyceumEnvelope(
          appVersion: '0.0.1+1',
          producedAt: DateTime.utc(2026, 10, 22, 9),
          schemaVersion: 1,
        ).encode(),
        minimal,
      );
    });
  });
}
