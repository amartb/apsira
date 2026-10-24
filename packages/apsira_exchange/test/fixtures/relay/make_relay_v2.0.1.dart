// Generator, run once in a `git archive v2.0.1` copy of RELAY (task T14 of
// apsira ledger packages-v0-4): RELAY v2.0.1's own JsonDump over the data of
// test/data/db/json_dump_test.dart @ v2.0.1 (its _populate, copied verbatim).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/data/db/backup_snapshot.dart';
import 'package:relay/data/db/connection.dart';
import 'package:relay/data/db/database.dart';
import 'package:relay/data/db/json_dump.dart';
import 'package:relay/domain/export/json_export_format.dart';

import '../support/synth/synth.dart';
import '../support/synth/synth_db.dart';

const _backupUri = 'content://com.android.externalstorage.documents/tree/b';
const _vaultUri = 'content://com.android.externalstorage.documents/tree/v';
const _jsonUri = 'content://com.android.externalstorage.documents/tree/j';

final _waveform = Uint8List.fromList([0, 1, 2, 250, 255, 128, 7]);

/// A row as comparable text: its columns by name, BLOBs as base64, as
/// the round-trip suite's `_canonicalTables` compares them.
String _canonical(Map<String, Object?> row) => jsonEncode({
  for (final key in row.keys.toList()..sort())
    key: switch (row[key]) {
      final Uint8List b => base64.encode(b),
      final v => v,
    },
});

/// [db]'s rows of [table], ordered by its primary key (composite keys in
/// key order), as `PRAGMA table_info` gives them.
Future<List<Map<String, Object?>>> _rowsByKey(
  RelayDatabase db,
  String table,
) async {
  final info = await db.customSelect('PRAGMA table_info("$table")').get();
  final key = [
    for (final c in info)
      if (c.read<int>('pk') > 0) c,
  ]..sort((a, b) => a.read<int>('pk').compareTo(b.read<int>('pk')));
  // A table with no key (the derived `cal_conflicts`, v10) is ordered by
  // every column, as `JsonDump` orders it.
  final order = (key.isEmpty ? info : key)
      .map((c) => '"${c.read<String>('name')}"')
      .join(', ');
  return [
    for (final r
        in await db
            .customSelect('SELECT * FROM "$table" ORDER BY $order')
            .get())
      r.data,
  ];
}

Future<String> _dump(RelayDatabase db) async {
  final out = StringBuffer();
  await JsonDump.write(db, out, appVersion: '0.7.0-test');
  return out.toString();
}

/// The round-trip data (synth `unit`) with what the synth leaves out: a
/// v7 view of the user's, v8 task fields, a reminder, an event, an
/// exception, a link, a registered alarm, a number value, an attachment
/// with a waveform, a soft-deleted note, and the settings rows that hold
/// device grants; v9 (D-135): a rule, one of its runs and a queued event.
Future<void> _populate(RelayDatabase db) async {
  await loadSynth(db, generateSynth(SynthSize.unit));
  final notes = [
    for (final r
        in await db.customSelect('SELECT id FROM notes ORDER BY id').get())
      r.read<String>('id'),
  ];
  final task =
      (await db
              .customSelect(
                "SELECT id FROM tasks WHERE kind = 'item' ORDER BY id",
              )
              .get())
          .first
          .read<String>('id');
  await db.customStatement(
    "UPDATE tasks SET start_date = '2026-10-21', estimate_minutes = 45, "
    "energy = 'low' WHERE id = ?",
    [task],
  );
  await db.customStatement(
    'INSERT INTO reminders (id, task_id, mode, offset_minutes, tz, '
    "created_at, updated_at) VALUES ('jd-reminder', ?, 'relative', 0, "
    "'Europe/Madrid', 1, 1)",
    [task],
  );
  await db.customStatement(
    'INSERT INTO task_events (id, task_id, event, at) VALUES '
    "('jd-event', ?, 'completed', 1)",
    [task],
  );
  await db.customStatement(
    'INSERT INTO task_recurrence_exceptions (task_id, occurrence_date, '
    "action, created_at) VALUES (?, '2026-10-27', 'skip', 1)",
    [task],
  );
  await db.customStatement(
    'INSERT INTO registered_alarms (request_code, reminder_id, fire_utc, '
    "registered_at) VALUES (7, 'jd-reminder', 2, 1)",
  );
  await db.customStatement(
    'INSERT INTO links (source_note_id, ordinal, target_note_id, '
    'target_text, target_block_id, is_embed, target_key) VALUES '
    "(?, 0, ?, 'Target', NULL, 0, 'target')",
    [notes[0], notes[1]],
  );
  await db.customStatement(
    'INSERT INTO saved_views (id, key, name, name_is_custom, icon, colour, '
    'subject, query, layout, layout_config, sort_order, created_at, '
    "updated_at, deleted_at) VALUES ('jd-view', NULL, 'Mine', 0, 'list', "
    "NULL, 'tasks', '{\"v\":1}', 'board', '{}', 5, 1, 2, 3)",
  );
  await db.customStatement(
    'INSERT INTO property_defs (id, key, name, value_type, config, icon, '
    "created_at, updated_at) VALUES ('jd-num', 'jd-num', 'Number', "
    "'number', '{}', NULL, 1, 1)",
  );
  for (final (i, v) in [2.5, 3.0, 0.1, -1e-9].indexed) {
    await db.customStatement(
      'INSERT INTO property_values (note_id, property_id, ordinal, v_num, '
      "updated_at) VALUES (?, 'jd-num', 0, ?, 1)",
      [notes[i], v],
    );
  }
  await db.customStatement(
    'INSERT INTO attachments (id, note_id, kind, mime, path, byte_size, '
    'sha256, waveform, created_at, updated_at) VALUES '
    "('jd-att', ?, 'audio', 'audio/mp4', 'media/2026/10/jd-att.m4a', 3, "
    "'abc', ?, 1, 1)",
    [notes[0], _waveform],
  );
  await db.customStatement(
    'INSERT INTO rules (id, name, enabled, trigger, actions, sort_order, '
    "created_at, updated_at) VALUES ('jd-rule', 'Recibos', 1, "
    '\'{"on":"note_created"}\', \'[{"do":"pin"}]\', 0, 1, 1)',
  );
  await db.customStatement(
    'INSERT INTO rule_runs (id, rule_id, run_kind, depth, at, entity_kind, '
    "entity_id, outcome, changes) VALUES ('jd-run', 'jd-rule', 'event', 0, "
    "2, 'note', ?, 'applied', '[]')",
    [notes[0]],
  );
  await db.customStatement(
    'INSERT INTO rule_events (at, kind, note_id, origin) VALUES '
    "(3, 'note_created', ?, 'ui')",
    [notes[0]],
  );
  await db.customStatement('UPDATE notes SET deleted_at = 99 WHERE id = ?', [
    notes[2],
  ]);
  await db.customStatement(
    'INSERT INTO settings (key, value) VALUES (?, ?), (?, ?)',
    [
      'backup',
      jsonEncode({
        'folderUri': _backupUri,
        'folderName': 'Backups',
        'keep': 14,
      }),
      'export',
      jsonEncode({
        'vault': {
          'folderUri': _vaultUri,
          'folderName': 'Vault',
          'schedule': 'daily',
        },
        'json': {'folderUri': _jsonUri, 'folderName': 'Exports'},
        'later': 1,
      }),
    ],
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('writes relay-v2.0.1.db (schema v11) and its relay.json', () async {
    final out = Directory(Platform.environment['T14_OUT']!);
    final tmp = await Directory.systemTemp.createTemp('t14_gen');
    final file = File('${tmp.path}/db/relay.db');
    final db = RelayDatabase(openRelayDatabase(file));
    await _populate(db);
    final buffer = StringBuffer();
    await JsonDump.write(db, buffer, appVersion: '2.0.1');
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.customStatement('PRAGMA journal_mode = DELETE');
    await db.close();
    expect(File('${file.path}-wal').existsSync(), isFalse);
    await file.copy('${out.path}/relay-v2.0.1.db');
    await File('${out.path}/relay-v2.0.1.relay.json')
        .writeAsString(buffer.toString(), flush: true);
    expect(RelayDatabase.currentVersion, 11);
    // The helpers the dump test keeps for its other cases.
    expect(_canonical({'a': 1}), '{"a":1}');
    expect(_rowsByKey, isNotNull);
    expect(_dump, isNotNull);
    await tmp.delete(recursive: true);
  });
}
