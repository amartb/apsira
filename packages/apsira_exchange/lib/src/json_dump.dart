// From lyceum lib/data/db/json_dump.dart @ 9f4ff27
/// The `tables` of an export document (D-APK-019), written from a database
/// snapshot (read-only), after LYCEUM's dump, itself after RELAY's.
///
/// The tables are derived from `sqlite_master` ([exportedTables]), so a
/// table the schema gains is exported without a change here; an app that
/// names its tables (RELAY's list) passes them. Rows are read page by page
/// in primary-key order. [DumpLayout.canonical] writes LYCEUM's canonical
/// JSON; [DumpLayout.rowPerLine] writes RELAY's layout (one row per line,
/// its reals), so each app's `tables` keeps its bytes.
library;

import 'dart:convert';

import 'package:apsira_core/apsira_core.dart';
import 'package:drift/drift.dart';

import 'envelope.dart';

/// Every table of [db] an export carries, sorted by name: each base table
/// of `sqlite_master`, except SQLite's own (`sqlite_*`), virtual tables (a
/// full-text index) and their shadow tables (`<vtab>_*`), and the tables of
/// [exclude] (state true only on this phone: alarm ids, grants, caches).
///
/// With [only] (an app's own list, in its order): those names, after
/// checking that each is such a table; a name that is not, or one in
/// [exclude], is an [ArgumentError] (the list names a table the schema
/// dropped).
Future<List<String>> exportedTables(
  DatabaseConnectionUser db, {
  Set<String> exclude = const {},
  List<String>? only,
}) async {
  final rows = await db
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\'",
      )
      .get();
  final virtual = [
    for (final row in rows)
      if ((row.read<String?>('sql') ?? '').trimLeft().toUpperCase().startsWith(
        'CREATE VIRTUAL TABLE',
      ))
        row.read<String>('name'),
  ];
  final tables = [
    for (final row in rows)
      if (row.read<String>('name') case final name
          when !virtual.contains(name) &&
              !virtual.any((v) => name.startsWith('${v}_')) &&
              !exclude.contains(name))
        name,
  ]..sort();
  if (only == null) return tables;
  for (final name in only) {
    if (!tables.contains(name)) {
      throw ArgumentError.value(name, 'only', 'not an exported table');
    }
  }
  return [...only];
}

/// Rewrites one row before it is written: the row's columns, as stored, to
/// the columns to write. Used to leave out device grants.
typedef RowRedaction = Map<String, Object?> Function(Map<String, Object?> row);

// From relay lib/domain/export/json_export_format.dart @ 09b28810
// (redactSettingsValue)
/// A [RowRedaction] for a key-value table: in the row whose [keyColumn] is
/// a key of [fields], the JSON object in [valueColumn] loses the fields at
/// each path (`['vault', 'folderUri']`) and is written back with
/// `jsonEncode`, every other field in its stored order. A value that is not
/// a JSON object, and every other row, is kept as stored (RELAY's
/// `settings` redactions).
RowRedaction jsonFieldRedaction({
  required String keyColumn,
  required String valueColumn,
  required Map<String, List<List<String>>> fields,
}) => (row) {
  final paths = fields[row[keyColumn]];
  final value = row[valueColumn];
  if (paths == null || paths.isEmpty || value is! String) return row;
  final Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    return row;
  }
  if (decoded is! Map<String, Object?>) return row;
  for (final path in paths) {
    Object? at = decoded;
    for (final step in path.take(path.length - 1)) {
      at = at is Map<String, Object?> ? at[step] : null;
    }
    if (at is Map<String, Object?>) at.remove(path.last);
  }
  return {...row, valueColumn: jsonEncode(decoded)};
};

/// How `tables` is laid out.
enum DumpLayout {
  /// LYCEUM's: canonical JSON (`writeSortedJson`), no whitespace.
  canonical,

  /// RELAY's: `{\n"<table>":[\n{row},\n{row}\n],\n…\n}`, one row per line,
  /// columns sorted, reals by [formatExportReal].
  rowPerLine,
}

/// Writes the `tables` object of an export document.
final class JsonDump {
  /// [redactions] by table name; [pageSize] rows per statement, so a large
  /// table never sits in memory whole.
  JsonDump(
    this.db, {
    this.pageSize = 500,
    this.redactions = const {},
    this.layout = DumpLayout.canonical,
  });

  final DatabaseConnectionUser db;
  final int pageSize;
  final Map<String, RowRedaction> redactions;
  final DumpLayout layout;

  /// Writes `{"<table>":[<row>,…],…}` for each of [tables], in that order,
  /// into [out], and returns the rows written per table (a manifest's
  /// `counts`).
  ///
  /// Rows come from `SELECT *` ordered by the primary key (a composite key
  /// in key order; a table without one, by every column), soft-deleted
  /// rows included, one object per row with its columns sorted. Values are
  /// written as stored: integer, real, text, BLOB as base64, null. Reads
  /// only: run it on a snapshot, so every table is the same commit.
  Future<Map<String, int>> writeTables(
    StringSink out,
    List<String> tables,
  ) async {
    final lines = layout == DumpLayout.rowPerLine;
    final counts = <String, int>{};
    out.write(lines ? '{\n' : '{');
    for (final (i, table) in tables.indexed) {
      if (i > 0) out.write(lines ? ',\n' : ',');
      out
        ..write(jsonEncode(table))
        ..write(':');
      counts[table] = await _table(table, out);
    }
    out.write(lines && tables.isNotEmpty ? '\n}' : '}');
    return counts;
  }

  /// Writes `[<row>,…]` for [table]; the number of rows.
  Future<int> _table(String table, StringSink out) async {
    final lines = layout == DumpLayout.rowPerLine;
    final redact = redactions[table];
    final quoted = _quote(table);
    final info = await db.customSelect('PRAGMA table_info($quoted)').get();
    final key = [
      for (final c in info)
        if (c.read<int>('pk') > 0) c,
    ]..sort((a, b) => a.read<int>('pk').compareTo(b.read<int>('pk')));
    final order = (key.isEmpty ? info : key)
        .map((c) => _quote(c.read<String>('name')))
        .join(', ');
    out.write('[');
    var count = 0;
    while (true) {
      final rows = await db
          .customSelect(
            'SELECT * FROM $quoted ORDER BY $order LIMIT ? OFFSET ?',
            variables: [Variable.withInt(pageSize), Variable.withInt(count)],
          )
          .get();
      for (final row in rows) {
        final data = redact == null ? row.data : redact(row.data);
        if (lines) {
          out.write(count == 0 ? '\n' : ',\n');
          _line(data, out);
        } else {
          if (count > 0) out.write(',');
          writeSortedJson(data, out);
        }
        count++;
      }
      if (rows.length < pageSize) break;
    }
    out.write(lines && count > 0 ? '\n]' : ']');
    return count;
  }

  static void _line(Map<String, Object?> data, StringSink out) {
    final columns = data.keys.toList()..sort();
    out.write('{');
    for (final (i, column) in columns.indexed) {
      if (i > 0) out.write(',');
      out
        ..write(jsonEncode(column))
        ..write(':')
        ..write(switch (data[column]) {
          null => 'null',
          final int v => '$v',
          final double v => formatExportReal(v),
          final String v => jsonEncode(v),
          final Uint8List v => '"${base64.encode(v)}"',
          final v => throw ArgumentError.value(
            v.runtimeType,
            column,
            'a value SQLite does not store',
          ),
        });
    }
    out.write('}');
  }

  static String _quote(String name) => '"${name.replaceAll('"', '""')}"';
}

/// Writes a whole export document into [out]: [envelope]'s head, the
/// [tables] of [dump], then the tail; the rows written per table. Every
/// error of [out] or of the database reaches the caller unchanged, so a
/// caller that writes into a `.part` and renames it once this returns
/// never leaves a document cut short under its final name.
Future<Map<String, int>> writeExport(
  StringSink out, {
  required ExportEnvelope envelope,
  required JsonDump dump,
  required List<String> tables,
}) async {
  envelope.writeHead(out);
  final counts = await dump.writeTables(out, tables);
  out.write(ExportEnvelope.tail);
  return counts;
}

// From relay lib/domain/export/json_export_format.dart @ 09b28810
/// [value] as RELAY's `relay.json` writes a real: the shortest text that
/// reads back as [value], with a `.` decimal (`3.0`, never `3`), and no
/// exponent below 1e15 in magnitude (`0.000000001`, never `1e-9`); larger
/// values as Dart writes them. Infinities, which JSON cannot spell, are
/// `1e999` and `-1e999`, which read back as them. SQLite stores no NaN.
String formatExportReal(double value) {
  if (value.isInfinite) return value.isNegative ? '-1e999' : '1e999';
  if (value.isNaN) throw ArgumentError.value(value, 'value', 'NaN');
  final text = value.toString();
  if (value.abs() >= 1e15 || !text.contains('e')) return text;
  // A tiny value: Dart writes `d.ddde-N`; spell it out.
  final negative = text.startsWith('-');
  final unsigned = negative ? text.substring(1) : text;
  final [mantissa, exponent] = unsigned.split('e');
  final shift = int.parse(exponent);
  final digits = mantissa.replaceAll('.', '');
  final point = mantissa.contains('.')
      ? mantissa.indexOf('.')
      : mantissa.length;
  final at = point + shift;
  final spelled = at <= 0
      ? '0.${'0' * -at}$digits'
      : '${digits.substring(0, at)}.${digits.substring(at)}';
  return '${negative ? '-' : ''}$spelled';
}
