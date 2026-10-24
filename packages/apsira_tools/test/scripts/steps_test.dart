// lib/scripts/check.sh and lib/scripts/codegen.sh: the skeletons that run
// the app's step list (APSIRA_CHECK_STEPS, APSIRA_CODEGEN_STEPS) the way this
// repository's tool/check.sh runs its steps: every step runs whatever the
// others did, each ends with `ok <step>` or `FAIL <step>`, and the last line
// is the verdict. Tests run from the package root.
import 'package:test/test.dart';

import 'sandbox.dart';

void main() {
  for (final (script, setting) in [
    ('check', 'APSIRA_CHECK_STEPS'),
    ('codegen', 'APSIRA_CODEGEN_STEPS'),
  ]) {
    group(script, () {
      const steps = '''
# the app's steps, one per line: <name>: <command>
format: echo formatted >> "\$LOG"

analyze: echo analyzed >> "\$LOG"; echo "lib/a.dart:1 error" >&2; exit 1
tests: echo "tests \$*" >> "\$LOG"
''';

      test('one failing step still runs the others; the verdict names it', () {
        final box = Sandbox();
        final result = box.run(script, ['--long'], box.env({setting: steps}));
        expect(result.exitCode, 1, reason: out(result));
        expect(box.calls, ['formatted', 'analyzed', 'tests --long']);
        final lines = '${result.stdout}'.trim().split('\n');
        expect(
          lines,
          containsAllInOrder([
            'ok format',
            'lib/a.dart:1 error',
            'FAIL analyze',
            'ok tests',
          ]),
        );
        expect(lines.last, '$script: FAIL (analyze)');
      });

      test('every step green is PASS (exit 0)', () {
        final box = Sandbox();
        final result = box.run(
          script,
          [],
          box.env({setting: 'one: true\ntwo: echo two >> "\$LOG"\n'}),
        );
        expect(result.exitCode, 0, reason: out(result));
        expect(box.calls, ['two']);
        expect('${result.stdout}'.trim().split('\n').last, '$script: PASS');
      });

      test('steps run in APSIRA_ROOT', () {
        final box = Sandbox()..write('app/marker', 'here');
        final result = box.run(
          script,
          [],
          box.env({
            setting: 'where: cat marker',
            'APSIRA_ROOT': '${box.root}/app',
          }),
        );
        expect(result.exitCode, 0, reason: out(result));
        expect('${result.stdout}', contains('here'));
      });

      for (final (name, value) in [
        ('no steps', ''),
        ('a line without a name', 'just a command'),
        ('a name twice', 'a: true\na: true'),
        ('a step without a command', 'a:'),
      ]) {
        test('$name is a settings error (exit 2)', () {
          final box = Sandbox();
          final result = box.run(script, [], box.env({setting: value}));
          expect(result.exitCode, 2, reason: out(result));
          expect('${result.stderr}', contains(setting));
          expect(
            '${result.stdout}'.trim().split('\n').last,
            '$script: FAIL (settings)',
          );
        });
      }

      test('--help names the setting', () {
        final box = Sandbox();
        final result = box.run(script, ['--help'], box.env());
        expect(result.exitCode, 0, reason: out(result));
        expect('${result.stdout}', contains(setting));
      });
    });
  }
}
