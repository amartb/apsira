// From lyceum lib/data/db/json_load.dart @ 9f4ff27
/// The restore's load (D-APK-019): an export document's `tables` built into
/// a fresh database file at the app's current schema, which the app's swap
/// then puts in place of the live one. The reverse of `json_dump.dart`.
/// LYCEUM's loader, with the app's database, upgrade steps, load order and
/// last step passed in.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apsira_core/apsira_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database, SqliteException;

import 'json_dump.dart' show exportedTables;

/// Why [buildDatabaseFrom] refused.
enum LoadRefusal {
  /// The data is not this schema's: a table it does not export, a column it
  /// does not have, a value that is not an integer, a real, a text or null,
  /// a row a constraint refuses, a dangling foreign key or a failed check.
  notABundle,

  /// Written by a newer schema than this build's.
  schemaTooNew,

  /// The disk is full (`ENOSPC`, `SQLITE_FULL`).
  storageFull,
}

/// A [LoadRefusal] as a [Failure]: its code is `load` + the refusal
/// (`loadNotABundle`), which each app maps to its own.
final class LoadRefused extends Failure {
  LoadRefused(this.refusal)
    : super('load${refusal.name[0].toUpperCase()}${refusal.name.substring(1)}');

  final LoadRefusal refusal;
}

/// A whole build: the rows per table of the built file.
final class LoadSummary {
  const LoadSummary(this.counts);

  final Map<String, int> counts;
}

/// Called after each table's rows are inserted: [loaded] of [total] tables.
/// A test seam (a kill point between tables); an app passes none.
typedef LoadStepHook = FutureOr<void> Function(
  String table,
  int loaded,
  int total,
);

/// Builds the database file [target] from [tables] (table name → rows,
/// each row column → value as stored) of a document written at schema
/// [bundleSchema], for an app at [currentSchema].
///
/// The file is created fresh by [open] (the app's database over the file;
/// anything at [target], with its `-wal`, `-shm` or `-journal`, is deleted
/// first; [setup] runs on the connection, the app's pragmas), and every row
/// is inserted in one transaction, tables in [loadOrder] (by default
/// [loadOrderOf]: parents first, so a trigger reads whole rows) with
/// `PRAGMA defer_foreign_keys = ON` as the backstop for cycles and
/// self-references. A column the row leaves out takes its default (a
/// document of an older schema); a BLOB column's text is decoded from
/// base64 (`PRAGMA table_info`). Then [upgrade] runs for every version
/// from [bundleSchema] up to [currentSchema] − 1, on the rows just written,
/// then [afterLoad] (LYCEUM's derived indexes), both inside the
/// transaction. The file must pass `PRAGMA foreign_key_check` (empty),
/// `PRAGMA integrity_check` (`ok`) and hold as many rows per table as
/// [tables] gave. It is closed whole.
///
/// Refused, with nothing left at [target]: [LoadRefusal.schemaTooNew],
/// [LoadRefusal.notABundle] (see there) and [LoadRefusal.storageFull]. Any
/// other error is rethrown, after the file is removed.
///
/// It runs on the calling isolate (a synchronous connection): run it off
/// the UI isolate.
Future<Result<LoadSummary, LoadRefused>> buildDatabaseFrom(
  File target,
  Map<String, Object?> tables, {
  required int bundleSchema,
  required int currentSchema,
  required GeneratedDatabase Function(QueryExecutor executor) open,
  Future<void> Function(GeneratedDatabase db, int from)? upgrade,
  Future<void> Function(GeneratedDatabase db)? afterLoad,
  List<String>? loadOrder,
  Set<String> exclude = const {},
  void Function(Database db)? setup,
  LoadStepHook? onStep,
}) async {
  // A build an earlier run left at [target] never stays, whatever follows.
  _deleteFamily(target);
  if (bundleSchema > currentSchema) {
    return Err(LoadRefused(LoadRefusal.schemaTooNew));
  }
  if (bundleSchema < 1) return Err(LoadRefused(LoadRefusal.notABundle));

  GeneratedDatabase? db;
  var built = false;
  try {
    target.parent.createSync(recursive: true);
    db = open(NativeDatabase(target, setup: setup));
    final counts = await _load(
      db,
      tables,
      bundleSchema: bundleSchema,
      currentSchema: currentSchema,
      upgrade: upgrade,
      afterLoad: afterLoad,
      order: loadOrder ?? await loadOrderOf(db, exclude: exclude),
      onStep: onStep,
    );
    await db.close();
    built = true;
    return Ok(LoadSummary(counts));
  } on _NotABundle {
    return Err(LoadRefused(LoadRefusal.notABundle));
  } on SqliteException catch (e) {
    switch (e.resultCode) {
      case _sqliteFull:
        return Err(LoadRefused(LoadRefusal.storageFull));
      case _sqliteConstraint || _sqliteMismatch || _sqliteRange:
        return Err(LoadRefused(LoadRefusal.notABundle));
      default:
        rethrow;
    }
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == _enospc) {
      return Err(LoadRefused(LoadRefusal.storageFull));
    }
    rethrow;
  } finally {
    // Anything but a whole build: the connection closed, the file gone.
    if (!built) {
      await db?.close();
      _deleteFamily(target);
    }
  }
}

/// Loads [tables] into [db], runs the upgrades and [afterLoad], checks the
/// result and returns the rows per table. Throws [_NotABundle] when the
/// data is not this schema's.
Future<Map<String, int>> _load(
  GeneratedDatabase db,
  Map<String, Object?> tables, {
  required int bundleSchema,
  required int currentSchema,
  required Future<void> Function(GeneratedDatabase db, int from)? upgrade,
  required Future<void> Function(GeneratedDatabase db)? afterLoad,
  required List<String> order,
  required LoadStepHook? onStep,
}) async {
  if (tables.keys.any((name) => !order.contains(name))) throw _NotABundle();

  final expected = <String, int>{};
  await db.transaction(() async {
    await db.customStatement('PRAGMA defer_foreign_keys = ON');
    for (final (i, table) in order.indexed) {
      final rows = tables[table] ?? const <Object?>[];
      if (rows is! List<Object?>) throw _NotABundle();
      expected[table] = rows.length;
      final columns = await _columns(db, table);
      for (final row in rows) {
        if (row is! Map<String, Object?>) throw _NotABundle();
        final names = row.keys.toList()..sort();
        if (names.any((c) => !columns.containsKey(c))) throw _NotABundle();
        await db.customStatement(
          'INSERT INTO ${_quote(table)} (${names.map(_quote).join(', ')}) '
          'VALUES (${List.filled(names.length, '?').join(', ')})',
          [for (final c in names) _value(row[c], blob: columns[c]!)],
        );
      }
      await onStep?.call(table, i + 1, order.length);
    }
    for (var from = bundleSchema; from < currentSchema; from++) {
      await upgrade?.call(db, from);
    }
    await afterLoad?.call(db);
  });

  final dangling = await db.customSelect('PRAGMA foreign_key_check').get();
  if (dangling.isNotEmpty) throw _NotABundle();
  final integrity = await db.customSelect('PRAGMA integrity_check').get();
  if (integrity.length != 1 || integrity.single.data.values.single != 'ok') {
    throw _NotABundle();
  }
  final counts = <String, int>{
    for (final table in order)
      table: await db
          .customSelect('SELECT COUNT(*) AS n FROM ${_quote(table)}')
          .map((r) => r.read<int>('n'))
          .getSingle(),
  };
  for (final MapEntry(:key, :value) in expected.entries) {
    if (counts[key] != value) throw _NotABundle();
  }
  return counts;
}

/// The exported tables of [db] ([exportedTables] with [exclude]) in load
/// order: a table after every table its foreign keys name, ties and cycles
/// by name.
Future<List<String>> loadOrderOf(
  DatabaseConnectionUser db, {
  Set<String> exclude = const {},
}) async {
  final names = await exportedTables(db, exclude: exclude);
  final parents = <String, Set<String>>{
    for (final table in names)
      table: {
        for (final fk
            in await db
                .customSelect('PRAGMA foreign_key_list(${_quote(table)})')
                .get())
          if (fk.read<String>('table') case final parent
              when parent != table && names.contains(parent))
            parent,
      },
  };
  final order = <String>[];
  final pending = [...names];
  while (pending.isNotEmpty) {
    final ready = pending
        .where((t) => parents[t]!.every(order.contains))
        .toList();
    // A cycle: the first by name goes next, the deferred keys cover it.
    final next = ready.isEmpty ? [pending.first] : ready;
    order.addAll(next);
    pending.removeWhere(next.contains);
  }
  return order;
}

/// Column name → whether it is declared BLOB, from `PRAGMA table_info`.
Future<Map<String, bool>> _columns(
  DatabaseConnectionUser db,
  String table,
) async {
  final info = await db
      .customSelect('PRAGMA table_info(${_quote(table)})')
      .get();
  return {
    for (final c in info)
      c.read<String>('name'): c
          .read<String>('type')
          .toUpperCase()
          .contains('BLOB'),
  };
}

/// A JSON value as SQLite stores it: a BLOB column's text decoded from
/// base64; anything but an integer, a real, a text or null refused.
Object? _value(Object? value, {required bool blob}) {
  switch (value) {
    case null || int() || double():
      return value;
    case String() when blob:
      try {
        return base64.decode(value);
      } on FormatException {
        throw _NotABundle();
      }
    case String():
      return value;
    default:
      throw _NotABundle();
  }
}

void _deleteFamily(File target) {
  for (final name in [
    target.path,
    '${target.path}-journal',
    '${target.path}-wal',
    '${target.path}-shm',
  ]) {
    final file = File(name);
    if (file.existsSync()) file.deleteSync();
  }
}

String _quote(String name) => '"${name.replaceAll('"', '""')}"';

/// The data is not this schema's: [buildDatabaseFrom] answers
/// [LoadRefusal.notABundle].
final class _NotABundle implements Exception {}

const int _sqliteFull = 13;
const int _sqliteConstraint = 19;
const int _sqliteMismatch = 20;
const int _sqliteRange = 25;

/// `ENOSPC` on Linux and Android.
const int _enospc = 28;
