// lib/scripts/session_guard.sh (D-APK-011): `refuse_in_session` exits 3 on
// each of the eight session markers, the union of VIATICUM's and LYCEUM's
// guards, and returns quietly in a clean environment. RELAY's guard missed
// ARMY_TREE and ARMY_TASK. Tests run from the package root.
import 'dart:io';

import 'package:test/test.dart';

import 'sandbox.dart';

/// Sources the guard and calls it the way a release script does.
ProcessResult _guard(Map<String, String> env) => Process.runSync(
  'bash',
  [
    '-c',
    '. "\$1" && refuse_in_session demo_release && echo "demo_release: passed"',
    'guard',
    File('$scriptsDir/session_guard.sh').absolute.path,
  ],
  environment: env,
  includeParentEnvironment: false,
);

void main() {
  final clean = {'PATH': '/usr/bin:/bin', 'HOME': '/home/operator'};

  test('a clean environment passes', () {
    final result = _guard(clean);
    expect(result.exitCode, 0, reason: out(result));
    expect('${result.stdout}', 'demo_release: passed\n');
    expect('${result.stderr}', isEmpty);
  });

  const markers = {
    'CLAUDECODE': 'CLAUDECODE set',
    'CLAUDE_CODE_ENTRYPOINT': 'CLAUDE_CODE_ENTRYPOINT set',
    'AI_AGENT': 'AI_AGENT set',
    'CODESPACES': 'CODESPACES set',
    'CLOUD_SHELL': 'CLOUD_SHELL set',
    'ARMY_TREE': 'ARMY_TREE set',
    'ARMY_TASK': 'ARMY_TASK set',
  };
  for (final MapEntry(key: name, value: shown) in markers.entries) {
    test('$name refuses with exit 3', () {
      final result = _guard({...clean, name: '1'});
      expect(result.exitCode, 3, reason: out(result));
      expect('${result.stdout}', isEmpty);
      expect('${result.stderr}', contains('demo_release: refused ($shown)'));
      expect('${result.stderr}', contains('D-APK-011'));
    });
  }

  test('HOME=/home/user refuses with exit 3', () {
    final result = _guard({...clean, 'HOME': '/home/user'});
    expect(result.exitCode, 3, reason: out(result));
    expect('${result.stderr}', contains('refused (HOME is /home/user)'));
  });

  test('an empty marker is no marker', () {
    final result = _guard({...clean, 'ARMY_TREE': ''});
    expect(result.exitCode, 0, reason: out(result));
  });

  test('the refusal names three markers, then counts the rest', () {
    final result = _guard({
      ...clean,
      'AI_AGENT': '1',
      'ARMY_TASK': 'T4',
      'ARMY_TREE': '/x',
      'CLAUDECODE': '1',
      'HOME': '/home/user',
    });
    expect(result.exitCode, 3);
    expect(
      '${result.stderr}',
      contains(
        'refused (CLAUDECODE set AI_AGENT set ARMY_TREE set and 2 more)',
      ),
    );
  });

  test("the app's own record is cited beside D-APK-011", () {
    final result = _guard({
      ...clean,
      'ARMY_TASK': 'T4',
      'APSIRA_GUARD_RECORD': 'D-090',
    });
    expect(result.exitCode, 3);
    expect('${result.stderr}', contains('(D-APK-011, D-090)'));
  });
}
