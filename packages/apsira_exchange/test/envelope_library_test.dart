// package:apsira_exchange/envelope.dart is the envelope alone, for an app's
// pure-Dart domain layer (VIATICUM's exchange readers, V3): it must reach no
// drift, sqlite3, dart:io or Flutter library. The barrel brings all four.
// Like apsira_app's clock_library_test.dart, a plain Dart program imports it
// and runs under the VM; that program lists every library it reaches.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('envelope.dart reads an envelope in a plain Dart program, reaching '
      'no drift, sqlite3, dart:io or Flutter library', () async {
    // dart test runs from the package root, where pub get wrote the package
    // config the VM resolves package:apsira_exchange/envelope.dart with.
    final result = await Process.run(Platform.resolvedExecutable, [
      '--packages=.dart_tool/package_config.json',
      'test/plain_dart/envelope_main.dart',
    ]);
    final out = '${result.stdout}';
    expect(
      result.exitCode,
      0,
      reason: 'stdout: $out\nstderr: ${result.stderr}',
    );
    expect(out, contains('readAs=viaticumExchangeV1 written=true'));
    final reached = [
      for (final line in out.split('\n'))
        if (line.startsWith('reaches ')) line.substring('reaches '.length),
    ];
    expect(reached, contains('package:apsira_exchange/envelope.dart'));
    expect(reached, contains('package:apsira_core/apsira_core.dart'));
    final forbidden = [
      for (final uri in reached)
        if (uri == 'dart:io' ||
            uri == 'dart:ui' ||
            uri.startsWith('package:drift/') ||
            uri.startsWith('package:sqlite3/') ||
            uri.startsWith('package:flutter/'))
          uri,
    ];
    expect(forbidden, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the barrel reaches drift, sqlite3 and dart:io (so the check above '
      'can see them)', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      '--packages=.dart_tool/package_config.json',
      'test/plain_dart/barrel_main.dart',
    ]);
    final out = '${result.stdout}';
    expect(
      result.exitCode,
      0,
      reason: 'stdout: $out\nstderr: ${result.stderr}',
    );
    expect(out, contains('reaches dart:io'));
    expect(out, contains('reaches package:drift/drift.dart'));
    expect(out, contains('reaches package:sqlite3/sqlite3.dart'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
