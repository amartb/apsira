// package:apsira_db/plain.dart is apsira_db without Flutter, for a plain Dart
// process (RELAY's database child processes, which imported src/ with
// implementation_imports ignores): the connection, the migration wrapper,
// the snapshot, the swap, the layout and fsync, never the opener or the
// server, which reach Flutter. Like apsira_app's clock_library_test.dart, a
// plain Dart program imports it and runs under the VM, where a library that
// reaches dart:ui does not compile (exporting the opener here fails it).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `dart` next to the `flutter` running this test, else the one on PATH.
String _dart() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dart = File('$root/bin/dart');
    if (dart.existsSync()) return dart.path;
  }
  return 'dart';
}

void main() {
  test('plain.dart opens, migrates and snapshots a database in a plain Dart '
      'process, reaching no Flutter library', () async {
    final dir = await Directory.systemTemp.createTemp('apsira_db_plain');
    addTearDown(() => dir.delete(recursive: true));
    // flutter test runs from the package root, where `dart run` finds the
    // package config and the sqlite3 hook's host library.
    final result = await Process.run(_dart(), [
      'run',
      'test/plain_dart/plain_main.dart',
      dir.path,
    ]);
    final out = '${result.stdout}';
    expect(
      result.exitCode,
      0,
      reason: 'stdout: $out\nstderr: ${result.stderr}',
    );
    expect(out, contains('journal=wal snapshot=v2:1'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
