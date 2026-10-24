// bin/script_path.dart: `dart run apsira_tools:script_path <name>` prints the
// absolute path of lib/scripts/<name>.sh in the resolved package, the one
// line an app's wrapper hands to bash; an unknown name, or no name, exits 2.
// Tests run from the package root.
import 'dart:io';

import 'package:test/test.dart';

import 'sandbox.dart';

ProcessResult _scriptPath(List<String> args) =>
    Process.runSync('dart', ['run', 'apsira_tools:script_path', ...args]);

void main() {
  for (final name in [
    'session_guard',
    'build_apk',
    'local_release',
    'codegen',
    'check',
  ]) {
    test('$name resolves to the package file', () {
      final result = _scriptPath([name]);
      expect(result.exitCode, 0, reason: out(result));
      final path = '${result.stdout}'.trim().split('\n').last;
      expect(path, File('$scriptsDir/$name.sh').absolute.path);
      expect(File(path).existsSync(), isTrue);
    });
  }

  for (final args in <List<String>>[
    ['release'],
    ['_run_steps'],
    ['../bin/script_path'],
    [],
    ['build_apk', 'check'],
  ]) {
    test('$args exits 2 with the usage', () {
      final result = _scriptPath(args);
      expect(result.exitCode, 2, reason: out(result));
      expect(
        '${result.stderr}',
        contains('usage: dart run apsira_tools:script_path'),
      );
      expect('${result.stdout}', isEmpty);
    });
  }
}
