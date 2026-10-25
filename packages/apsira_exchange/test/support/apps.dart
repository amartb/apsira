/// Each app's parts as it passes them to the package (D-APK-019), so the
/// tests prove the apps' bytes and codes, not the package's defaults.
library;

import 'dart:convert';
import 'dart:io';

import 'package:apsira_exchange/apsira_exchange.dart';
import 'package:drift/drift.dart';

// --- RELAY -----------------------------------------------------------------

// From relay lib/domain/export/json_export_format.dart @ 09b28810 (v2.0.1)
/// RELAY's `jsonExportTables`: every table `relay.json` holds, in name
/// order.
const List<String> relayExportTables = [
  'app_meta',
  'attachments',
  'backup_log',
  'cal_conflicts',
  'cal_constraint_exceptions',
  'cal_constraints',
  'cal_holiday_packs',
  'cal_holidays',
  'cal_item_events',
  'cal_item_layers',
  'cal_item_note_links',
  'cal_item_property_values',
  'cal_item_tags',
  'cal_items',
  'cal_layers',
  'cal_looks',
  'cal_occurrences',
  'cal_reminders',
  'cal_type_properties',
  'cal_types',
  'folders',
  'links',
  'note_tags',
  'note_types',
  'notes',
  'places',
  'property_defs',
  'property_values',
  'reminders',
  'rule_runs',
  'rules',
  'saved_views',
  'select_options',
  'settings',
  'tags',
  'task_events',
  'task_recurrence_exceptions',
  'task_statuses',
  'tasks',
  'type_properties',
];

/// RELAY's `jsonExcludedTables` that are base tables (the two FTS indexes
/// are virtual, which `exportedTables` leaves out by itself).
const Set<String> relayDeviceStateTables = {
  'registered_alarms',
  'rule_events',
  'cal_viaticum_trips',
  'cal_viaticum_bookings',
};

/// RELAY's `jsonRedactions`: the picked folders' URIs of two `settings`
/// rows.
final Map<String, RowRedaction> relayRedactions = {
  'settings': jsonFieldRedaction(
    keyColumn: 'key',
    valueColumn: 'value',
    fields: {
      'backup': [
        ['folderUri'],
      ],
      'export': [
        ['vault', 'folderUri'],
        ['json', 'folderUri'],
      ],
    },
  ),
};

/// RELAY's dump after adoption.
JsonDump relayDump(DatabaseConnectionUser db) =>
    JsonDump(db, redactions: relayRedactions, layout: DumpLayout.rowPerLine);

/// The `tables` value of a `relay.json` text: everything between
/// `"tables":` and the object's end, as written.
String tablesText(String document) {
  final start = document.indexOf('"tables":{\n') + '"tables":'.length;
  final end = document.lastIndexOf('\n}') + 2;
  return document.substring(start, end);
}

// --- LYCEUM ----------------------------------------------------------------

// From lyceum lib/domain/export/format.dart @ 9f4ff27
const String lyceumFormat = 'lyceum-export';

/// LYCEUM's envelope: the shared one with its top-level `app_version`.
ExportEnvelope lyceumEnvelope({
  required String appVersion,
  required DateTime producedAt,
  required int schemaVersion,
}) => ExportEnvelope(
  format: lyceumFormat,
  producedAt: producedAt,
  producer: Producer('lyceum', appVersion),
  schemaVersion: schemaVersion,
  extra: {'app_version': appVersion},
);

// From lyceum lib/domain/export/import_failures.dart @ 9f4ff27
const String importNotABundle = 'importNotABundle';
const String importFormatUnsupported = 'importFormatUnsupported';
const String importSchemaTooNew = 'importSchemaTooNew';

/// LYCEUM's `checkEnvelope` on the package's: its codes, and its
/// top-level `app_version` required.
String? lyceumRefusal(Object? json, {int current = 2}) {
  final read = checkEnvelope(
    json,
    formats: {lyceumFormat},
    currentSchemaVersion: current,
  );
  return switch (read) {
    EnvelopeOk(:final envelope) => switch (envelope.extra['app_version']) {
      final String v when v.isNotEmpty => null,
      _ => importNotABundle,
    },
    NotABundle() => importNotABundle,
    FormatUnsupported() => importFormatUnsupported,
    SchemaTooNew() => importSchemaTooNew,
  };
}

/// LYCEUM v1.0.0's `exchange/` folder, copied from the tag.
const String lyceumExchange = 'test/fixtures/exchange/lyceum-v1.0.0';

/// The `CREATE TABLE`s of LYCEUM v1.0.0's export tables, from the table
/// schemas of its `exchange/` (every column with its type, nullable when
/// the schema allows null, `x-primary-key` the key), plus its FTS index.
List<String> lyceumDdl() {
  final dir = Directory('$lyceumExchange/schemas/tables');
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      () {
        final schema =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        final table = file.uri.pathSegments.last.split('.').first;
        final props = schema['properties']! as Map<String, Object?>;
        final key = (schema['x-primary-key']! as List<Object?>).cast<String>();
        final columns = [
          for (final MapEntry(:key, :value) in props.entries)
            () {
              final type = (value! as Map<String, Object?>)['type'];
              final types = type is List
                  ? type.cast<String>()
                  : [type! as String];
              final sql = switch (types.first) {
                'integer' => 'INTEGER',
                'number' => 'REAL',
                _ => 'TEXT',
              };
              return '"$key" $sql${types.contains('null') ? '' : ' NOT NULL'}';
            }(),
        ];
        return 'CREATE TABLE "$table" (${columns.join(', ')}, '
            'PRIMARY KEY (${key.map((k) => '"$k"').join(', ')}))';
      }(),
    'CREATE VIRTUAL TABLE search_fts USING fts5(entity_id, title, body)',
  ];
}
