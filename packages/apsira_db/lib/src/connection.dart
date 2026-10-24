// From relay lib/data/db/connection.dart @ 09b28810 (`openRelayDatabase`,
// renamed; VIATICUM's and LYCEUM's copies are the same).
/// The app database's connection and its pragmas. Plain Dart.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// How the opener connects to the database file: [openDatabaseFile] by
/// default, the app's `DatabaseServer.connect` for the UI's open.
typedef Connect = QueryExecutor Function(File file);

/// Opens the database file on a background isolate, so no query runs on the
/// UI thread. The pragmas are set by [applyPragmas] on every connection the
/// isolate opens.
QueryExecutor openDatabaseFile(File file) =>
    NativeDatabase.createInBackground(file, setup: applyPragmas);

/// The connection pragmas: WAL, foreign keys, a 5 s busy timeout and
/// `synchronous = FULL`, so every commit is durable across a power loss.
void applyPragmas(Database db) {
  db
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('PRAGMA foreign_keys = ON')
    ..execute('PRAGMA busy_timeout = 5000')
    ..execute('PRAGMA synchronous = FULL');
}
