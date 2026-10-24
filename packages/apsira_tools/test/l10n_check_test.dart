// From relay test/critical/l10n_complete_test.dart @ 5f606e9
// The `l10n_complete` critical suite (08 §3, D-030, 07 P0-07): every key
// exists in EN and ES with matching placeholders, and no `Text(` in lib/ is
// given a string literal (the source-scan half; the analyzer half is
// deferred, 08 §3). The fixtures in test/fixtures/l10n/ must each fail.
// Tests run from the package root.
import 'dart:io';

import 'package:apsira_tools/src/l10n_check.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/l10n';

/// RELAY's gen-l10n file (lib/app/l10n/l10n.yaml) is not in this package:
/// the command-line tests pass one of the same shape with `--l10n-config`
/// (P-5) before their own arguments.
late String _l10nConfig;

Future<(int, String)> _run(List<String> args) async {
  final out = StringBuffer();
  final code = await runL10nCheck([
    '--l10n-config',
    _l10nConfig,
    ...args,
  ], out: out);
  return (code, out.toString());
}

void main() {
  late Directory configDir;
  setUpAll(() {
    configDir = Directory.systemTemp.createTempSync('l10n_config_');
    _l10nConfig =
        (File('${configDir.path}/l10n.yaml')..writeAsStringSync(
              'arb-dir: lib/app/l10n\ntemplate-arb-file: app_en.arb\n',
            ))
            .path;
  });
  tearDownAll(() => configDir.deleteSync(recursive: true));

  group('the ARB check', () {
    test('fails on a missing key, naming the key and the file', () async {
      final problems = checkArbDir('$_fixtures/missing_key');
      expect(problems, hasLength(1));
      expect(problems.single.key, 'noteDeleted');
      expect(problems.single.file, '$_fixtures/missing_key/app_es.arb');

      final (code, out) = await _run(['--arb-dir', '$_fixtures/missing_key']);
      expect(code, 1);
      expect(out, contains("missing_key/app_es.arb: 'noteDeleted' is missing"));
    });

    test('fails on a placeholder mismatch, naming the key and the file', () {
      final problems = checkArbDir('$_fixtures/placeholder_mismatch');
      expect(problems, hasLength(1));
      expect(problems.single.key, 'notesInFolder');
      expect(
        problems.single.toString(),
        endsWith(
          "placeholder_mismatch/app_es.arb: 'notesInFolder' has placeholders "
          '{carpeta, count}, app_en.arb has {count, folder}',
        ),
      );
    });

    test('reads placeholders at any depth of an ICU message', () {
      expect(placeholdersIn('Plain text'), isEmpty);
      expect(placeholdersIn('Hello {name}'), {'name'});
      expect(
        placeholdersIn(
          '{count, plural, =0{None in {folder}} =1{one} other{{count} in x}}',
        ),
        {'count', 'folder'},
      );
      expect(placeholdersIn('{kind, select, a{A} other{B {who}}}'), {
        'kind',
        'who',
      });
      expect(placeholdersIn('Due {date, date, yMMMd}'), {'date'});
    });

    test('reports a malformed message instead of guessing', () {
      expect(() => placeholdersIn('Unclosed {name'), throwsFormatException);
      expect(() => placeholdersIn('Stray } brace'), throwsFormatException);
    });
  });

  group('the source scan', () {
    test('exempts only generated localisations and the dev-only '
        'ThemePreview (P0-12b)', () {
      expect(scanExemptions, [
        'app/l10n/generated/',
        'features/theme_preview/',
      ]);
    });

    test('scans features/spike_lab/ like any feature now the Spike lab is '
        'gone (D-104)', () {
      final dir = Directory.systemTemp.createTempSync('l10n_scan_');
      addTearDown(() => dir.deleteSync(recursive: true));
      const literal = "final w = Text('Run spike');\n";
      for (final path in [
        'features/spike_lab/spike_lab_screen.dart',
        'features/theme_preview/theme_preview_screen.dart',
        'app/l10n/generated/app_localizations.dart',
      ]) {
        File('${dir.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(literal);
      }
      final problems = scanHardCodedText(dir.path);
      expect(problems, hasLength(1));
      expect(
        problems.single.file,
        endsWith('features/spike_lab/spike_lab_screen.dart'),
      );
      expect(problems.single.line, 1);
      expect(problems.single.message, contains("'Run spike'"));
    });

    test('finds the one in its fixture, with file and line', () async {
      final problems = scanHardCodedText('$_fixtures/hard_coded_text');
      expect(problems, hasLength(1));
      expect(problems.single.file, endsWith('hard_coded_text/note_tile.dart'));
      expect(problems.single.line, 14);
      expect(problems.single.message, contains("'Untitled note'"));

      final (code, out) = await _run([
        '--source-dir',
        '$_fixtures/hard_coded_text',
      ]);
      expect(code, 1);
      expect(out, contains('note_tile.dart:14'));
    });

    test('ignores comments, variables, numbers and other widgets', () {
      const source = '''
// Text('in a line comment')
/* Text('in a block comment') */
final a = Text(title);
final b = Text('\$count');
final c = Text('\${items.length} / \$total');
final d = SelectableText('not this scan');
final e = 'Text(\\'inside a string\\')';
''';
      expect(textLiterals(source), isEmpty);
    });

    test('flags literals in every quoting style', () {
      const source = '''
final a = const Text('Single');
final b = Text("Double");
final c = Text(r'Raw');
final d = Text(\'\'\'Triple\'\'\');
final e = Text(
  'On the next line',
);
final f = Text('\$count notes');
final g = material.Text('Prefixed');
''';
      expect(textLiterals(source).map((found) => found.$2), [
        "'Single'",
        '"Double"',
        "r'Raw'",
        "'''Triple'''",
        "'On the next line'",
        "'\$count notes'",
        "'Prefixed'",
      ]);
    });
  });

  test('bad usage exits 2', () async {
    final (code, _) = await _run(['--unknown']);
    expect(code, 2);
  });

  group('a missing gen-l10n file (v0.2)', () {
    test('exits 2 with one line naming the path, not a stack trace', () async {
      final missing = '${configDir.path}/absent/l10n.yaml';
      final out = StringBuffer();
      final code = await runL10nCheck(['--l10n-config', missing], out: out);
      expect(code, 2);
      expect(out.toString(), 'l10n_check: no l10n config at $missing\n');
    });

    test('the default path of the tools file is named the same way', () async {
      final out = StringBuffer();
      final code = await runL10nCheck(const [], out: out);
      expect(code, 2);
      expect(
        out.toString(),
        'l10n_check: no l10n config at lib/app/l10n/l10n.yaml\n',
      );
    });
  });
}
