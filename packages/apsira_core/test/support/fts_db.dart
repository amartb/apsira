/// A stand-in for the part of RELAY's drift database that RELAY's
/// `fts_match` test touches, so that test runs here with its body unchanged:
/// `RelayDatabase` holds only RELAY's `note_fts` table (relay
/// lib/data/db/tables/note_fts.drift @ 09b28810, verbatim), and
/// `NativeDatabase.memory`, `Variable`, `customStatement`, `customSelect` and
/// `read` keep drift's names over `package:sqlite3`.
///
/// SQLite is the host's: `libsqlite3.so`, or the runtime's `libsqlite3.so.0`
/// when no development symlink is installed. FTS5 and `unicode61
/// remove_diacritics 2` need SQLite 3.27 or later.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// RELAY's full-text index (data model §9.1): diacritics folded, so `año`
/// matches `ano` (DM-7).
const _noteFts = '''
CREATE VIRTUAL TABLE note_fts USING fts5(
  note_id UNINDEXED,
  title, body, tags, props,
  tokenize = "unicode61 remove_diacritics 2"
);''';

DynamicLibrary _openLinux() {
  try {
    return DynamicLibrary.open('libsqlite3.so');
  } on ArgumentError {
    return DynamicLibrary.open('libsqlite3.so.0');
  }
}

/// RELAY's connection pragmas (relay lib/data/db/connection.dart @
/// 09b28810).
void applyPragmas(Database db) {
  db
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('PRAGMA foreign_keys = ON')
    ..execute('PRAGMA busy_timeout = 5000')
    ..execute('PRAGMA synchronous = FULL');
}

/// A bound value, as drift's `Variable`.
final class Variable {
  const Variable.withString(String this.value);

  const Variable.withInt(int this.value);

  final Object value;
}

/// An in-memory SQLite connection, as drift's `NativeDatabase.memory`.
final class NativeDatabase {
  NativeDatabase.memory({this.setup});

  /// Runs on the connection once it is open (RELAY passes [applyPragmas]).
  final void Function(Database db)? setup;

  Database _open() {
    if (Platform.isLinux) open.overrideFor(OperatingSystem.linux, _openLinux);
    final db = sqlite3.openInMemory();
    setup?.call(db);
    return db;
  }
}

/// RELAY's database, reduced to its `note_fts` table.
final class RelayDatabase {
  RelayDatabase(NativeDatabase executor) : _db = executor._open() {
    _db.execute(_noteFts);
  }

  final Database _db;

  Future<void> customStatement(String sql, [List<Object?>? args]) async =>
      _db.execute(sql, args ?? const []);

  Selectable customSelect(String sql, {List<Variable> variables = const []}) =>
      Selectable._(_db, sql, [for (final v in variables) v.value]);

  Future<void> close() async => _db.dispose();
}

/// A query to run, as drift's `Selectable`.
final class Selectable {
  Selectable._(this._db, this._sql, this._args);

  final Database _db;
  final String _sql;
  final List<Object?> _args;

  Future<List<QueryRow>> get() async => [
    for (final row in _db.select(_sql, _args)) QueryRow._(row),
  ];
}

/// A result row, as drift's `QueryRow`.
final class QueryRow {
  QueryRow._(this._row);

  final Row _row;

  T read<T>(String key) => _row[key] as T;
}
