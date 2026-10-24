// The README's release wrappers ("Scripts"): each app's
// tool/release/local_release.sh refuses in a session (exit 3) before it runs
// dart, flutter or the package's script, so not even
// `dart run apsira_tools:script_path` runs there (D-APK-011). Each wrapper is
// taken from the README as written and run in a sandbox whose `dart` stub
// fails if it is called; with no marker it runs the package's script.
// Tests run from the package root.
import 'dart:io';

import 'package:test/test.dart';

import 'sandbox.dart';

/// The README's `bash` blocks that run local_release, by app (each block's
/// second line is `# <APP>: …`).
Map<String, String> _releaseWrappers() {
  final readme = File('README.md').readAsStringSync();
  final blocks = RegExp(r'```bash\n(.*?)```', dotAll: true);
  return {
    for (final match in blocks.allMatches(readme))
      if (match[1]!.contains('script_path local_release'))
        RegExp(r'^# ([A-Z]+):', multiLine: true).firstMatch(match[1]!)![1]!:
            match[1]!,
  };
}

/// The app's own guard a wrapper sources instead of the snippet.
const _appGuard = 'tool/release/session_guard.sh';

/// A sandbox holding [wrapper] as tool/release/local_release.sh and, when
/// it sources one, the app's session_guard.sh (the package's list: LYCEUM's
/// is its source). Its `dart` fails when called, unless [resolves].
Sandbox _box(String wrapper, {bool resolves = false, bool guard = true}) {
  final box = Sandbox()..write('tool/release/local_release.sh', wrapper);
  if (guard && wrapper.contains(_appGuard)) {
    box.write(
      _appGuard,
      File('$scriptsDir/session_guard.sh').readAsStringSync(),
    );
  }
  final script = File('$scriptsDir/local_release.sh').absolute.path;
  box.stub(
    'bin/dart',
    resolves
        ? 'log "dart \$*"\n'
              '[ "\$*" = "run apsira_tools:script_path local_release" ] '
              '&& echo "$script"\n'
        : 'log "dart \$*"\nexit 97\n',
  );
  return box;
}

ProcessResult _run(Sandbox box, List<String> args, Map<String, String> env) =>
    Process.runSync(
      'bash',
      ['${box.root}/tool/release/local_release.sh', ...args],
      environment: env,
      includeParentEnvironment: false,
      workingDirectory: box.root,
    );

void main() {
  final wrappers = _releaseWrappers();

  test('the README has a release wrapper for each app', () {
    expect(wrappers.keys, unorderedEquals(['RELAY', 'VIATICUM', 'LYCEUM']));
  });

  test("a wrapper's own check lists session_guard.sh's markers", () {
    List<String> listed(String text, String variable) => RegExp(
      'for $variable in ([^;]*?); do',
      dotAll: true,
    ).firstMatch(text)![1]!.replaceAll('\\\n', ' ').split(RegExp(r'\s+'));
    final guard = listed(
      File('$scriptsDir/session_guard.sh').readAsStringSync(),
      'name',
    );
    for (final MapEntry(key: app, value: wrapper) in wrappers.entries) {
      if (wrapper.contains(_appGuard)) continue;
      expect(listed(wrapper, 'marker'), guard, reason: app);
    }
  });

  const markers = {
    'CLAUDECODE': 'CLAUDECODE set',
    'CLAUDE_CODE_ENTRYPOINT': 'CLAUDE_CODE_ENTRYPOINT set',
    'AI_AGENT': 'AI_AGENT set',
    'CODESPACES': 'CODESPACES set',
    'CLOUD_SHELL': 'CLOUD_SHELL set',
    'ARMY_TREE': 'ARMY_TREE set',
    'ARMY_TASK': 'ARMY_TASK set',
    'HOME': 'HOME is /home/user',
  };

  for (final MapEntry(key: app, value: wrapper) in wrappers.entries) {
    group(app, () {
      for (final MapEntry(key: marker, value: shown) in markers.entries) {
        test('$marker refuses with exit 3 before dart runs', () {
          final box = _box(wrapper);
          for (final args in [
            ['v2.0.2'],
            ['--dry-run', 'v2.0.2'],
            ['--help'],
          ]) {
            final env = box.env({
              marker: marker == 'HOME' ? '/home/user' : '1',
            });
            final result = _run(box, args, env);
            expect(result.exitCode, 3, reason: '$args: ${out(result)}');
            expect('${result.stdout}', isEmpty);
            expect(
              '${result.stderr}',
              contains('local_release: refused ($shown)'),
            );
          }
          expect(box.calls, isEmpty, reason: 'nothing runs, not even dart');
          expect(Directory('${box.root}/build').existsSync(), isFalse);
        });
      }

      test('a clean environment runs the package script', () {
        final box = _box(wrapper, resolves: true);
        final result = _run(box, ['--help'], box.env());
        expect(result.exitCode, 0, reason: out(result));
        expect('${result.stdout}', contains('usage: local_release.sh'));
        expect(box.calls, ['dart run apsira_tools:script_path local_release']);
      });

      test('a failing script_path exits 1, not the package exit 2', () {
        final box = _box(wrapper);
        final result = _run(box, ['v2.0.2'], box.env());
        expect(result.exitCode, 1, reason: out(result));
        expect(box.calls, ['dart run apsira_tools:script_path local_release']);
      });

      if (wrapper.contains(_appGuard)) {
        test('without its session_guard.sh it refuses with exit 3', () {
          final box = _box(wrapper, resolves: true, guard: false);
          final result = _run(box, ['--help'], box.env());
          expect(result.exitCode, 3, reason: out(result));
          expect('${result.stderr}', contains('session_guard.sh'));
          expect(box.calls, isEmpty);
        });
      }
    });
  }
}
