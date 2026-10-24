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
  test('clock.dart loads in a plain Dart process, without Flutter', () async {
    // flutter test runs from the package root, where pub get wrote the
    // package config the VM resolves package:apsira_app/clock.dart with.
    final result = await Process.run(_dart(), [
      '--packages=.dart_tool/package_config.json',
      'test/plain_dart/clock_main.dart',
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    expect(result.stdout, contains('zone=Europe/Madrid utc=true'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
