// From relay test/critical/layering_test.dart @ 5f606e9
// The `layering` critical suite (08 §3, D-040, 07 P0-09): the import rules of
// architecture §3 and the pure-code rule (no `DateTime.now()`, `Random()` or
// `Uuid()` in domain or core), checked by tool/layering_lint.dart. Every rule
// has a clean case in test/fixtures/layering/clean/ and a violation in
// test/fixtures/layering/violations/; the rules that read pubspec.yaml or
// a suppression comment (dev-only packages, the lint suppression) have
// theirs in a tree the suite writes to a temporary directory, which also
// proves features/spike_lab/ is an ordinary feature now the Spike lab is
// gone (D-104). The colour-literal rule (CLAUDE.md §1.7, P1-00) has its
// own group: a written tree that fails with a literal in a feature file and
// passes without it, and the source scan's finds and exemptions. Tests run
// from the package root.
import 'dart:io';

import 'package:apsira_tools/src/layering_lint.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/layering';

Future<(int, String)> _run(List<String> args) async {
  final out = StringBuffer();
  final code = await runLayeringLint(args, out: out);
  return (code, out.toString());
}

/// A finding reduced to what the suite pins: where, what and which rule.
String _key(LayeringViolation v) => '${v.file}:${v.line} ${v.what} ${v.rule}';

/// The rules that read pubspec.yaml or the suppression comment, proved in
/// [_tree] rather than in the fixtures.
const _treeRules = {'dev-packages', 'lint-suppression'};

/// Packages the tree's pubspec lists only under `dev_dependencies`.
const _devOnly = {'flutter_test', 'record', 'saf_stream'};

const _treePubspec = '''
name: relay
dependencies:
  # a comment
  drift: ^2.35.2
  flutter:
    sdk: flutter
  yaml: ^3.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  record: ^7.1.2
  saf_stream: ^4.0.2
  yaml: ^3.1.4

flutter:
  uses-material-design: true
''';

/// A lib/ tree holding a clean and a breaking case for each tree rule and
/// for `feature-packages`, all in `features/spike_lab/`: since the Spike lab
/// was removed (D-104), that folder is an ordinary feature with no layer of
/// its own, so nothing there may import a plugin or a dev-only package or
/// silence the dependency lint.
const _tree = {
  // Clean: an allowlisted runtime package (feature-packages, dev-packages),
  // another lint's suppression (lint-suppression), the layers a feature may
  // import and its own folder.
  'features/spike_lab/x.dart': '''
import 'package:flutter/widgets.dart';
// ignore: unused_import
import 'package:relay/app/l10n/strings.dart';
import 'package:relay/app/services/note_service.dart';
import 'package:relay/app/theme/relay_theme.dart';
import 'package:relay/core/log.dart';
import 'package:relay/domain/notes/note.dart';

import 'audio/y.dart';
''',
  // Breaking: the suppression, a plugin, a dev-only package, data/ and
  // another feature.
  'features/spike_lab/audio/y.dart': '''
// ignore_for_file: depend_on_referenced_packages
import 'package:drift/drift.dart';
import 'package:record/record.dart';
import 'package:relay/data/notes_dao.dart';
import 'package:relay/features/home/home_screen.dart';
''',
  // The router may import it like any feature; the app shell and other
  // features may not.
  'app/router.dart': "import 'package:relay/features/spike_lab/x.dart';",
  'app/app.dart': "import 'package:relay/features/spike_lab/x.dart';",
  'features/home/home_screen.dart': '''
import 'package:flutter/widgets.dart';
import 'package:relay/features/spike_lab/x.dart';
''',
  // Outside features: a runtime package (also a dev dependency) passes, a
  // package listed only under dev_dependencies fails.
  'app/services/note_service.dart': '''
import 'package:drift/drift.dart';
import 'package:yaml/yaml.dart';
import 'package:saf_stream/saf_stream.dart';
''',
  'core/log.dart': "import 'dart:core';",
  'domain/notes/note.dart': "import 'package:relay/core/log.dart';",
  'data/notes_dao.dart': "import 'package:relay/domain/notes/note.dart';",
  'app/theme/relay_theme.dart': '',
  'app/l10n/strings.dart': '',
};

void main() {
  group('the clean fixture', () {
    test('passes every rule, composition roots and router included', () {
      expect(checkLayering('$_fixtures/clean'), isEmpty);
    });

    test('covers every layer the rules name', () {
      final layers = {
        for (final file in dartFilesUnder('$_fixtures/clean'))
          layerOf(file).kind,
      };
      expect(
        layers,
        containsAll(LayerKind.values.toSet()..remove(LayerKind.stray)),
      );
    });
  });

  group('the violations fixture', () {
    const root = '$_fixtures/violations';
    const expected = {
      // domain: pure dart: libraries, core, domain and the allowlist only.
      '$root/domain/notes/note.dart:3 dart:io domain-imports',
      '$root/domain/notes/note.dart:5 package:flutter/foundation.dart '
          'domain-imports',
      '$root/domain/notes/note.dart:6 package:relay/data/notes_dao.dart '
          'domain-imports',
      // domain: time and IDs only through Clock and IdGen.
      '$root/domain/notes/ids.dart:9 DateTime.now() pure-calls',
      '$root/domain/notes/ids.dart:10 Random() pure-calls',
      '$root/domain/notes/ids.dart:11 Uuid() pure-calls',
      '$root/domain/notes/ids.dart:13 DateTime.now() pure-calls',
      // core is as pure as domain, and never reaches up.
      '$root/core/log.dart:1 package:flutter/widgets.dart core-imports',
      '$root/core/log.dart:3 package:relay/domain/notes/note.dart '
          'core-imports',
      // data: domain and core, never app or features (export counts too).
      '$root/data/notes_dao.dart:3 package:relay/features/home/home_screen.dart '
          'data-imports',
      // services: domain, data and core, never presentation.
      '$root/app/services/note_service.dart:3 '
          '../../features/home/home_screen.dart services-imports',
      // theme: core, theme and l10n only; l10n may also read domain.
      '$root/app/theme/relay_theme.dart:3 '
          'package:relay/app/services/note_service.dart theme-l10n-imports',
      '$root/app/theme/relay_theme.dart:4 '
          'package:relay/domain/notes/note.dart theme-l10n-imports',
      // only the composition roots wire data into the app.
      '$root/app/app.dart:3 package:relay/data/notes_dao.dart app-imports',
      // features: services, domain, core, theme, l10n and themselves.
      '$root/features/home/home_screen.dart:5 '
          'package:relay/data/notes_dao.dart feature-imports',
      // features: never Drift or plugins.
      '$root/features/home/home_screen.dart:3 package:drift/drift.dart '
          'feature-packages',
      '$root/features/home/home_screen.dart:4 '
          'package:path_provider/path_provider.dart feature-packages',
      // no feature imports another.
      '$root/features/notes/notes_screen.dart:3 '
          'package:relay/features/home/home_screen.dart cross-feature',
      // every file sits in a known layer.
      '$root/stray.dart:1 stray.dart placement',
      // colours come from RelayTheme: no literal outside app/theme/ and
      // generated code (the theme file holds one; the source scan below proves
      // the generated-code exemption).
      '$root/features/home/home_screen.dart:9 Color(…) colour-literals',
      '$root/features/home/home_screen.dart:10 Colors.red colour-literals',
    };

    test('every rule is broken exactly where the fixture breaks it', () {
      expect(checkLayering(root).map(_key).toSet(), expected);
    });

    test('every rule but the tree rules has a violation here', () {
      final rules = checkLayering(root).map((v) => v.rule).toSet();
      expect(
        rules,
        containsAll(layeringRules.keys.toSet().difference(_treeRules)),
      );
    });

    test('the command line fails naming file:line, the import and the rule '
        '(07 P0-09)', () async {
      final (code, out) = await _run(['--root', root]);
      expect(code, 1);
      expect(
        out,
        contains(
          '$root/features/home/home_screen.dart:3: import '
          "'package:drift/drift.dart' breaks feature-packages:",
        ),
      );
      expect(
        out,
        contains(
          '$root/domain/notes/ids.dart:9: DateTime.now() breaks '
          'pure-calls:',
        ),
      );
      expect(out, contains('layering: ${expected.length} violation(s)'));
    });
  });

  group('features/spike_lab/ is an ordinary feature (D-104)', () {
    late Directory tree;

    setUp(() {
      tree = Directory.systemTemp.createTempSync('layering_tree_');
      for (final MapEntry(:key, :value) in _tree.entries) {
        File('${tree.path}/lib/$key')
          ..createSync(recursive: true)
          ..writeAsStringSync(value);
      }
      File('${tree.path}/pubspec.yaml').writeAsStringSync(_treePubspec);
    });
    tearDown(() => tree.deleteSync(recursive: true));

    test('reads the packages pubspec.yaml lists only as dev dependencies', () {
      expect(devOnlyPackages(_treePubspec), _devOnly);
    });

    test('features/spike_lab/ is a feature named spike_lab', () {
      expect(layerOf('features/spike_lab/x.dart'), (
        kind: LayerKind.feature,
        feature: 'spike_lab',
      ));
      expect(layerOf('features/spike_lab/audio/y.dart'), (
        kind: LayerKind.feature,
        feature: 'spike_lab',
      ));
      expect(layerOf('features/home/home_screen.dart'), (
        kind: LayerKind.feature,
        feature: 'home',
      ));
    });

    test('each rule passes its clean case and fails its breaking one', () {
      final found = {
        for (final v in checkLayering('${tree.path}/lib', devOnly: _devOnly))
          '${v.file.substring(tree.path.length + 5)}:${v.line} ${v.what} '
              '${v.rule}',
      };
      expect(found, {
        // lint-suppression: no lib/ file silences the dependency lint.
        'features/spike_lab/audio/y.dart:1 depend_on_referenced_packages '
            'lint-suppression',
        // feature-packages: never Drift or plugins.
        'features/spike_lab/audio/y.dart:2 package:drift/drift.dart '
            'feature-packages',
        // dev-packages: no package listed only under dev_dependencies.
        'features/spike_lab/audio/y.dart:3 package:record/record.dart '
            'dev-packages',
        // feature-imports and cross-feature, as for every feature.
        'features/spike_lab/audio/y.dart:4 '
            'package:relay/data/notes_dao.dart feature-imports',
        'features/spike_lab/audio/y.dart:5 '
            'package:relay/features/home/home_screen.dart cross-feature',
        'features/home/home_screen.dart:2 '
            'package:relay/features/spike_lab/x.dart cross-feature',
        // Only the router reaches a feature from app/.
        'app/app.dart:1 package:relay/features/spike_lab/x.dart app-imports',
        // dev-packages outside features too.
        'app/services/note_service.dart:3 '
            'package:saf_stream/saf_stream.dart dev-packages',
      });
      expect(
        found.map((f) => f.split(' ').last).toSet(),
        containsAll({..._treeRules, 'feature-packages'}),
      );
    });

    test('the command line reads --pubspec and names the rule', () async {
      final (code, out) = await _run([
        '--root',
        '${tree.path}/lib',
        '--pubspec',
        '${tree.path}/pubspec.yaml',
      ]);
      expect(code, 1);
      expect(
        out,
        contains(
          "y.dart:3: import 'package:record/record.dart' breaks "
          'dev-packages:',
        ),
      );
      expect(out, contains('layering: 8 violation(s)'));
    });
  });

  group('freezed_annotation on the domain allowlist (D-108)', () {
    List<String> scan(String file, String source) => [
      for (final v in checkSource(file, source))
        '${v.line} ${v.what} ${v.rule}',
    ];

    test('domain and core may import freezed_annotation', () {
      expect(domainPackages, contains('freezed_annotation'));
      const source =
          "import 'package:freezed_annotation/freezed_annotation.dart';\n";
      expect(scan('domain/notes/note.dart', source), isEmpty);
      expect(scan('core/result.dart', source), isEmpty);
    });

    test('the freezed builder and a direct json_annotation import stay '
        'out', () {
      const source = '''
import 'package:freezed/builder.dart';
import 'package:json_annotation/json_annotation.dart';
''';
      expect(domainPackages, isNot(contains('freezed')));
      expect(scan('domain/notes/note.dart', source), [
        '1 package:freezed/builder.dart domain-imports',
        '2 package:json_annotation/json_annotation.dart domain-imports',
      ]);
    });
  });

  group('colour literals (colour-literals, CLAUDE.md §1.7, P1-00)', () {
    late Directory tree;
    const feature = 'features/home/home_screen.dart';
    const literal = '''
import 'package:flutter/widgets.dart';

const accent = Color(0xFF3A7BD5);
''';

    void write(String path, String source) {
      File('${tree.path}/lib/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
    }

    setUp(() {
      tree = Directory.systemTemp.createTempSync('layering_colour_');
      File('${tree.path}/pubspec.yaml').writeAsStringSync(_treePubspec);
      // The theme is where colour literals live: never a finding.
      write('app/theme/relay_theme.dart', '''
import 'package:flutter/material.dart';

const ink = Color(0xFF101010);
final error = Colors.red;
''');
    });
    tearDown(() => tree.deleteSync(recursive: true));

    Future<(int, String)> lint() => _run([
      '--root',
      '${tree.path}/lib',
      '--pubspec',
      '${tree.path}/pubspec.yaml',
    ]);

    test('a Color(…) in a feature file fails naming file and line; the same '
        'tree without it passes', () async {
      write(feature, literal);
      final (failed, out) = await lint();
      expect(failed, 1, reason: out);
      expect(
        out,
        contains(
          '${tree.path}/lib/$feature:3: Color(…) breaks colour-literals:',
        ),
      );
      expect(out, contains('layering: 1 violation(s)'));

      write(feature, "import 'package:flutter/widgets.dart';\n");
      final (passed, clean) = await lint();
      expect(passed, 0, reason: clean);
      expect(clean, contains('clean'));
    });

    List<String> scan(String file, String source) => [
      for (final v in checkSource(file, source))
        '${v.line} ${v.what} ${v.rule}',
    ];

    test('finds Color(…), Color.fromARGB(…), Color.fromRGBO(…) and '
        'Colors.… in every layer outside app/theme/', () {
      const source = r'''
const a = Color(0xFF000000);
const b = Color . fromARGB(255, 0, 0, 0);
const c = Color.fromRGBO(0, 0, 0, 1.0);
final d = Colors.blue.shade100;
final e = Colors . transparent;
final f = 'at ${Color(0x00000000)}';
const g = Color.from(alpha: 1, red: 0, green: 0, blue: 0);
''';
      const expected = [
        '1 Color(…) colour-literals',
        '2 Color.fromARGB(…) colour-literals',
        '3 Color.fromRGBO(…) colour-literals',
        '4 Colors.blue colour-literals',
        '5 Colors.transparent colour-literals',
        '6 Color(…) colour-literals',
        '7 Color.from(…) colour-literals',
      ];
      for (final file in [
        feature,
        'app/app.dart',
        'app/services/a.dart',
        'app/l10n/a.dart',
        'domain/a.dart',
        'core/a.dart',
        'data/a.dart',
        'main.dart',
      ]) {
        expect(scan(file, source), expected, reason: file);
      }
    });

    test('ignores comments, strings, app/theme/ and generated code', () {
      const source = '''
// Color(0xFF000000) and Colors.red in a line comment
/* Color.fromARGB(255, 0, 0, 0) in a block comment */
/// Use a token, never Colors.blue or Color.fromRGBO(0, 0, 0, 1).
const s = 'Color(0xFF000000) and Colors.red in a string';
const r = r"Color.fromARGB(255, 0, 0, 0)";
''';
      expect(scan(feature, source), isEmpty);
      const literals = '''
const a = Color(0xFF000000);
const b = Color.fromARGB(255, 0, 0, 0);
final c = Colors.red;
''';
      expect(scan('app/theme/relay_colors.dart', literals), isEmpty);
      expect(scan('app/theme/sub/palette.dart', literals), isEmpty);
      expect(scan('features/home/home_screen.g.dart', literals), isEmpty);
      expect(scan('domain/notes/note.freezed.dart', literals), isEmpty);
    });

    test('a Color type, ColoredBox or a token is not a colour literal', () {
      const source = '''
Color? fill;
final Color color = tokens.ring;
Widget box() => ColoredBox(color: tokens.ring);
final c = theme.colorScheme.primary;
final x = MyColors.red;
final y = CupertinoColors.white;
''';
      expect(scan(feature, source), isEmpty);
    });
  });

  group('shared packages (D-APK-002)', () {
    const core = "import 'package:apsira_core/apsira_core.dart';\n";
    const ui = "import 'package:apsira_ui/apsira_ui.dart';\n";

    late Directory tree;

    setUp(() => tree = Directory.systemTemp.createTempSync('layering_shared_'));
    tearDown(() => tree.deleteSync(recursive: true));

    Set<String> lint(Map<String, String> files, {LayeringConfig? config}) {
      for (final MapEntry(:key, :value) in files.entries) {
        File('${tree.path}/lib/$key')
          ..createSync(recursive: true)
          ..writeAsStringSync(value);
      }
      return {
        for (final v in checkLayering(
          '${tree.path}/lib',
          config: config ?? LayeringConfig.relay,
        ))
          '${v.file.substring(tree.path.length + 5)}:${v.line} ${v.what} '
              '${v.rule}',
      };
    }

    test('domain and core may import apsira_core', () {
      expect(
        lint({'domain/notes/note.dart': core, 'core/log.dart': core}),
        isEmpty,
      );
    });

    test('a feature and app/theme may import apsira_ui', () {
      expect(
        lint({'features/x/x_screen.dart': ui, 'app/theme/app_theme.dart': ui}),
        isEmpty,
      );
    });

    test('domain and data may not import apsira_ui: it is the theme layer', () {
      expect(lint({'domain/notes/note.dart': ui, 'data/notes_dao.dart': ui}), {
        'domain/notes/note.dart:1 package:apsira_ui/apsira_ui.dart '
            'domain-imports',
        'data/notes_dao.dart:1 package:apsira_ui/apsira_ui.dart data-imports',
      });
    });

    test('with shared_packages: [] apsira_core is a foreign package', () {
      const none = LayeringConfig(sharedPackages: {});
      expect(lint({'domain/notes/note.dart': core}, config: none), {
        'domain/notes/note.dart:1 package:apsira_core/apsira_core.dart '
            'domain-imports',
      });
    });
  });

  group('the source scan', () {
    List<String> scan(String file, String source) => [
      for (final v in checkSource(file, source))
        '${v.line} ${v.what} ${v.rule}',
    ];

    test('ignores comments and string literals', () {
      const source = '''
// DateTime.now() in a line comment, import 'dart:io';
/* Random() in a /* nested */ block comment */
const note = 'Uuid() in a string';
const raw = r"DateTime.now() in a raw string";
const multi = """
import 'package:flutter/widgets.dart';
""";
''';
      expect(scan('domain/a.dart', source), isEmpty);
    });

    test('finds calls inside string interpolation', () {
      const source = r"final s = 'at ${DateTime.now()} and ${'${Random()}'}';";
      expect(scan('domain/a.dart', source), [
        '1 DateTime.now() pure-calls',
        '1 Random() pure-calls',
      ]);
    });

    test('finds Random.secure(), DateTime.timestamp() and const Uuid()', () {
      const source = '''
final a = Random.secure();
final b = DateTime.timestamp();
const c = Uuid();
''';
      expect(scan('core/a.dart', source), [
        '1 Random.secure() pure-calls',
        '2 DateTime.timestamp() pure-calls',
        '3 Uuid() pure-calls',
      ]);
    });

    test('checks every URI of a conditional import', () {
      const source = '''
import 'stub.dart'
    if (dart.library.io) 'dart:io';
''';
      expect(scan('domain/a.dart', source), ['1 dart:io domain-imports']);
    });

    test('names an import that leaves lib/', () {
      expect(scan('domain/a.dart', "import '../../tool/x.dart';"), [
        '1 ../../tool/x.dart placement',
      ]);
    });
  });

  group('the command line', () {
    test('exits 2 on bad usage', () async {
      final (code, out) = await _run(['--nope']);
      expect(code, 2);
      expect(out, contains('usage:'));
    });

    test('exits 2 when the pubspec does not exist', () async {
      final (code, out) = await _run(['--pubspec', '$_fixtures/missing.yaml']);
      expect(code, 2);
      expect(out, contains('no such file'));
    });

    test('exits 2 when the root does not exist', () async {
      final (code, out) = await _run(['--root', '$_fixtures/missing']);
      expect(code, 2);
      expect(out, contains('no such directory'));
    });
  });
}
