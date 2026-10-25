// From lyceum test/data/db/json_dump_test.dart @ 9f4ff27 (the generic
// cases; LYCEUM's seed and device-state guards stay in LYCEUM): the
// exported tables are derived from `sqlite_master`, never a hand list; the
// rows are canonical JSON in primary-key order, soft-deleted rows included,
// so the same data gives the same bytes. Then RELAY's parity (AC-14.4): on
// RELAY v2.0.1's own database (schema v11), with its table list, its
// `settings` redactions and its layout, `tables` is byte for byte what
// RELAY v2.0.1's `JsonDump` wrote; only the head differs.
import 'dart:convert';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_exchange/apsira_exchange.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'support/apps.dart';
import 'support/db.dart';

Future<String> _dump(DatabaseConnectionUser db, {JsonDump? dump}) async {
  final out = StringBuffer();
  await (dump ?? JsonDump(db)).writeTables(out, await exportedTables(db));
  return out.toString();
}

Future<void> _insert(SqlDatabase db, String table, Map<String, Object?> row) =>
    db.customStatement(
      'INSERT INTO $table (${row.keys.join(', ')}) '
      'VALUES (${List.filled(row.length, '?').join(', ')})',
      row.values.toList(),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SqlDatabase db;
  setUp(() => db = SqlDatabase.memory(smallSchema));
  tearDown(() => db.close());

  test('every base table is exported and no FTS or shadow table is; a new '
      'table is, a device-state table is not', () async {
    final exported = await exportedTables(db);
    expect(exported, ['alarms', 'parts', 'tags', 'works']);
    final shadows = [
      for (final r
          in await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE name LIKE 'works\\_fts\\_%' "
                r"ESCAPE '\' AND type = 'table'",
              )
              .get())
        r.read<String>('name'),
    ];
    expect(shadows, isNotEmpty);
    expect(exported.toSet().intersection({'works_fts', ...shadows}), isEmpty);

    await db.customStatement('CREATE TABLE zz_added (k TEXT PRIMARY KEY)');
    await db.customStatement('CREATE VIRTUAL TABLE notes_fts USING fts5(x)');
    expect(await exportedTables(db), [...exported, 'zz_added']);
    expect(await exportedTables(db, exclude: {'alarms', 'zz_added'}), [
      'parts',
      'tags',
      'works',
    ]);
  });

  test('only: the app\'s own list in its order; a name that is not an '
      'exported table is an error', () async {
    expect(await exportedTables(db, only: ['works', 'parts']), [
      'works',
      'parts',
    ]);
    for (final bad in ['nope', 'works_fts', 'works_fts_data']) {
      await expectLater(
        exportedTables(db, only: ['works', bad]),
        throwsArgumentError,
        reason: bad,
      );
    }
    await expectLater(
      exportedTables(db, exclude: {'alarms'}, only: ['alarms']),
      throwsArgumentError,
    );
  });

  test('same data gives same bytes; rows in key order; soft-deleted rows '
      'included', () async {
    final other = SqlDatabase.memory(smallSchema);
    addTearDown(other.close);
    await _insert(db, 'works', {'id': 'w2', 'title': 'B'});
    await _insert(db, 'works', {'id': 'w1', 'title': 'A'});
    await _insert(other, 'works', {'id': 'w1', 'title': 'A'});
    await _insert(other, 'works', {'id': 'w2', 'title': 'B'});
    for (final d in [db, other]) {
      await _insert(d, 'tags', {'name': 'z', 'work_id': 'w1'});
      await _insert(d, 'tags', {'name': 'a', 'work_id': 'w2'});
      await _insert(d, 'tags', {'name': 'b', 'work_id': 'w1'});
    }

    final text = await _dump(db);
    expect(await _dump(other), text);
    expect(await _dump(db), text, reason: 'a second dump is identical');
    final tables = jsonDecode(text) as Map<String, Object?>;
    expect(encodeSortedJson(tables), text);
    expect(tables.keys, await exportedTables(db));
    expect(
      [for (final r in tables['works']! as List) (r as Map)['id']],
      ['w1', 'w2'],
    );
    // A composite key in key order: (work_id, name).
    expect(
      [
        for (final r in tables['tags']! as List)
          '${(r as Map)['work_id']}/${r['name']}',
      ],
      ['w1/b', 'w1/z', 'w2/a'],
    );
  });

  test('writeTables returns the rows written per table, every page of a '
      'large table in key order', () async {
    await db.transaction(() async {
      for (var i = 1200; i >= 0; i--) {
        await _insert(db, 'works', {
          'id': 'bulk-${i.toString().padLeft(4, '0')}',
          'title': 'n$i',
        });
      }
    });
    final out = StringBuffer();
    final counts = await JsonDump(db)
        .writeTables(out, await exportedTables(db));
    final tables = jsonDecode(out.toString()) as Map<String, Object?>;
    expect(counts, {'alarms': 0, 'parts': 0, 'tags': 0, 'works': 1201});
    final ids = [
      for (final row in tables['works']! as List<Object?>)
        (row! as Map<String, Object?>)['id']! as String,
    ];
    expect(ids, hasLength(1201));
    expect(ids, [...ids]..sort());
  });

  test('values are written as stored: integer, real, text, BLOB as base64, '
      'null', () async {
    await db.customStatement(
      'CREATE TABLE zz_values (k INTEGER PRIMARY KEY, i INTEGER, r REAL, '
      't TEXT, b BLOB, n TEXT)',
    );
    await db.customStatement(
      'INSERT INTO zz_values VALUES (1, 42, 2.5, ?, ?, NULL)',
      [
        'línea\n"dos"',
        Uint8List.fromList([0, 1, 2, 254, 255]),
      ],
    );
    final tables = jsonDecode(await _dump(db)) as Map<String, Object?>;
    expect(tables['zz_values'], [
      {
        'b': base64.encode([0, 1, 2, 254, 255]),
        'i': 42,
        'k': 1,
        'n': null,
        'r': 2.5,
        't': 'línea\n"dos"',
      },
    ]);
  });

  test('a redaction rewrites its table\'s rows only; jsonFieldRedaction '
      'keeps every other field in its stored order', () async {
    await db.customStatement(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
    );
    final rows = {
      'backup': '{"folderUri":"content://b","folderName":"B","keep":14}',
      'export':
          '{"vault":{"folderUri":"content://v","folderName":"V"},'
          '"json":{"folderUri":"content://j"},"later":1}',
      'lock': '{"folderUri":"kept: no redaction for this key"}',
      'note': 'not json',
    };
    for (final MapEntry(:key, :value) in rows.entries) {
      await _insert(db, 'settings', {'key': key, 'value': value});
    }
    final tables = jsonDecode(
      await _dump(db, dump: JsonDump(db, redactions: relayRedactions)),
    ) as Map<String, Object?>;
    final values = {
      for (final r in tables['settings']! as List)
        (r as Map)['key']: r['value'],
    };
    expect(values, {
      'backup': '{"folderName":"B","keep":14}',
      'export': '{"vault":{"folderName":"V"},"json":{},"later":1}',
      'lock': rows['lock'],
      'note': 'not json',
    });
  });

  test('rowPerLine: RELAY\'s layout, one row per line, its reals', () async {
    await _insert(db, 'works', {'id': 'w1', 'title': 'A', 'ratio': 3.0});
    await _insert(db, 'works', {'id': 'w2', 'title': 'B', 'ratio': -1e-9});
    final out = StringBuffer();
    await JsonDump(
      db,
      layout: DumpLayout.rowPerLine,
    ).writeTables(out, ['alarms', 'works']);
    expect(
      out.toString(),
      '{\n"alarms":[],\n"works":[\n'
      '{"id":"w1","ratio":3.0,"title":"A","words":0},\n'
      '{"id":"w2","ratio":-0.000000001,"title":"B","words":0}\n]\n}',
    );
    final none = StringBuffer();
    await JsonDump(db, layout: DumpLayout.rowPerLine).writeTables(none, []);
    expect(none.toString(), '{\n}');
    expect(formatExportReal(double.infinity), '1e999');
    expect(formatExportReal(1e20), '100000000000000000000.0');
    expect(formatExportReal(1.5e-7), '0.00000015');
  });

  group('RELAY parity on its v2.0.1 database (schema v11)', () {
    late SqlDatabase relay;
    late String fixture;
    setUp(() {
      relay = SqlDatabase.file(
        relayV201Database(scratch('relay')),
        version: 11,
      );
      fixture = utf8.decode(fixtureBytes('relay/relay-v2.0.1.json.gz'));
    });
    tearDown(() => relay.close());

    test(
      'sqlite_master minus RELAY\'s device-state tables is its list',
      () async {
        expect(
          await exportedTables(relay, exclude: relayDeviceStateTables),
          relayExportTables,
        );
      },
    );

    test('tables is byte for byte RELAY v2.0.1\'s, with its list, '
        'redactions and order; the head is the envelope', () async {
      final out = StringBuffer();
      final counts = await writeExport(
        out,
        envelope: ExportEnvelope(
          format: 'relay-export',
          producedAt: DateTime.utc(2026, 10, 24, 12),
          producer: const Producer('relay', '2.0.1'),
          schemaVersion: 11,
        ),
        dump: relayDump(relay),
        tables: await exportedTables(relay, only: relayExportTables),
      );
      final document = out.toString();
      expect(tablesText(document), tablesText(fixture));
      expect(
        document.substring(0, document.indexOf('"tables":')),
        '{"format":"relay-export","format_version":"1.0",'
        '"produced_at":"2026-10-24T12:00:00Z",'
        '"producer":{"app":"relay","app_version":"2.0.1"},'
        '"schema_version":11,',
      );
      expect(document.endsWith('\n}}\n'), isTrue);
      final old = jsonDecode(fixture) as Map<String, Object?>;
      expect(counts, {
        for (final MapEntry(:key, :value)
            in (old['tables']! as Map<String, Object?>).entries)
          key: (value! as List).length,
      });
      // The redactions bit: the fixture holds no folder URI.
      expect(fixture, isNot(contains('folderUri')));
      final read = checkEnvelope(
        jsonDecode(document),
        formats: {'relay-export'},
        currentSchemaVersion: 12,
        legacy: const [LegacyShape.relayExportV1],
      );
      expect((read as EnvelopeOk).readAs, isNull);
    });
  });
}
