/// The tests' databases: hand-written SQL behind a [GeneratedDatabase]
/// (the package ships no generated code, D-APK-001), the fixtures of each
/// released tag, and a scratch directory per test.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

/// A drift database whose schema is [ddl], run on create, at [version].
final class SqlDatabase extends GeneratedDatabase {
  SqlDatabase(super.executor, {required this.ddl, this.version = 1});

  final List<String> ddl;
  final int version;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final statement in ddl) {
        await customStatement(statement);
      }
    },
  );

  /// An in-memory database of [ddl].
  static SqlDatabase memory(List<String> ddl, {int version = 1}) =>
      SqlDatabase(NativeDatabase.memory(), ddl: ddl, version: version);

  /// The database at [file], opened as it is (a fixture: no create runs
  /// when the file already holds a schema at [version]).
  static SqlDatabase file(File file, {int version = 1}) =>
      SqlDatabase(NativeDatabase(file), ddl: const [], version: version);
}

/// A small schema with a parent, a child, a self-reference, a BLOB and a
/// full-text index (virtual, with its shadow tables).
const List<String> smallSchema = [
  'CREATE TABLE works (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, '
      'words INTEGER NOT NULL DEFAULT 0, ratio REAL)',
  'CREATE TABLE parts (id TEXT NOT NULL PRIMARY KEY, work_id TEXT NOT NULL '
      'REFERENCES works (id), parent_id TEXT REFERENCES parts (id), '
      'cover BLOB)',
  'CREATE TABLE tags (name TEXT NOT NULL, work_id TEXT NOT NULL '
      'REFERENCES works (id), PRIMARY KEY (work_id, name))',
  'CREATE TABLE alarms (code INTEGER NOT NULL PRIMARY KEY, at INTEGER)',
  'CREATE VIRTUAL TABLE works_fts USING fts5(title)',
];

/// Rows for [smallSchema], as `tables` holds them.
Map<String, Object?> smallTables({int works = 3}) => {
  'works': [
    for (var i = 0; i < works; i++)
      <String, Object?>{
        'id': 'w$i',
        'title': 'Obra $i',
        'words': i * 10,
        'ratio': i / 4,
      },
  ],
  'parts': [
    <String, Object?>{
      'id': 'p1',
      'work_id': 'w0',
      'parent_id': null,
      'cover': 'AAEC',
    },
    <String, Object?>{
      'id': 'p2',
      'work_id': 'w0',
      'parent_id': 'p1',
      'cover': null,
    },
  ],
  'tags': [
    <String, Object?>{'name': 'casa', 'work_id': 'w0'},
  ],
  'alarms': [
    <String, Object?>{'code': 7, 'at': 1},
  ],
};

/// A fresh directory under the system temp, removed after the test.
Directory scratch(String name) {
  final dir = Directory.systemTemp.createTempSync('apsira_exchange_$name');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// The package's `test/fixtures/` directory.
final Directory fixtures = Directory('test/fixtures');

/// The bytes of fixture [path], gunzipped when it ends in `.gz`.
List<int> fixtureBytes(String path) {
  final bytes = File('${fixtures.path}/$path').readAsBytesSync();
  return path.endsWith('.gz') ? gzip.decode(bytes) : bytes;
}

/// Fixture [path] decoded as JSON.
Object? fixtureJson(String path) => jsonDecode(utf8.decode(fixtureBytes(path)));

/// RELAY v2.0.1's database (schema v11) copied into [dir], ready to open.
File relayV201Database(Directory dir) {
  final file = File('${dir.path}/relay.db');
  file.writeAsBytesSync(fixtureBytes('relay/relay-v2.0.1.db.gz'));
  return file;
}
