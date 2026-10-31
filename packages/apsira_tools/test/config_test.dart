// The per-app configuration (D-APK-002): tool/apsira_tools.yaml replaces
// RELAY's constants. An absent or empty file reproduces RELAY exactly, with
// `package` taken from the pubspec's name; an unknown key, a wrong type or
// unparsable YAML is a usage error naming the key and the file; every
// command reads `--config <path>`, and l10n_check's RELAY `--config` (the
// gen-l10n file) is `--l10n-config` (P-5). Tests run from the package root.
import 'dart:io';

import 'package:apsira_tools/src/config.dart';
import 'package:apsira_tools/src/coverage_gate.dart';
import 'package:apsira_tools/src/deps_check.dart';
import 'package:apsira_tools/src/l10n_check.dart';
import 'package:apsira_tools/src/layering_lint.dart';
import 'package:apsira_tools/src/manifest_check.dart';
import 'package:test/test.dart';

typedef _Runner = Future<int> Function(List<String> args, {StringSink? out});

Future<(int, String)> _run(_Runner run, List<String> args) async {
  final out = StringBuffer();
  final code = await run(args, out: out);
  return (code, out.toString());
}

void main() {
  late Directory dir;
  late String pubspec;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_tools_config_');
    pubspec = '${dir.path}/pubspec.yaml';
    File(pubspec).writeAsStringSync('name: relay\nversion: 1.0.0\n');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, String text) =>
      (File('${dir.path}/$name')..writeAsStringSync(text)).path;

  ApsiraToolsConfig load(String yaml) =>
      ApsiraToolsConfig.load(path: write('tools.yaml', yaml), pubspec: pubspec);

  void expectRelay(ApsiraToolsConfig config) {
    expect(config.package, 'relay');
    final layering = config.layering;
    expect(layering.package, 'relay');
    expect(layering.root, 'lib');
    expect(layering.domainPackages, domainPackages);
    expect(layering.featurePackages, featurePackages);
    expect(layering.sharedPackages, {'apsira_core', 'apsira_ui'});
    expect(layering.colourLiteralExempt, ['app/theme/']);
    expect(layering.disabledRules, isEmpty);
    expect(config.l10n.config, 'lib/app/l10n/l10n.yaml');
    expect(config.l10n.requiredLocales, requiredLocales);
    expect(config.l10n.requiredLocales, ['en', 'es']);
    expect(config.l10n.scanExemptions, scanExemptions);
    expect(config.l10n.scanExemptions, [
      'app/l10n/generated/',
      'features/theme_preview/',
    ]);
    expect(config.coverage.run, isNull);
    expect(config.coverage.minLines, defaultMinLines);
    expect(config.coverage.minBranches, defaultMinBranches);
    expect(config.privacy.allowlist, 'tool/privacy/dependency_allowlist.yaml');
    expect(
      config.privacy.declaredPermissions,
      'tool/privacy/declared_permissions.txt',
    );
    expect(config.privacy.holdsNetwork, isFalse);
  }

  group('defaults', () {
    test('an absent file is RELAY, field by field', () {
      expectRelay(
        ApsiraToolsConfig.load(
          path: '${dir.path}/missing.yaml',
          pubspec: pubspec,
        ),
      );
    });

    test('an empty file, or one holding only comments, is RELAY', () {
      expectRelay(load(''));
      expectRelay(load('# nothing set\n'));
      expectRelay(load('layering:\nl10n:\n'));
    });

    test('the const RELAY configuration is the one the tools default to', () {
      expectRelay(ApsiraToolsConfig.relay);
      expect(LayeringConfig.relay.package, 'relay');
    });

    test('package defaults to the pubspec name', () {
      File(pubspec).writeAsStringSync('name: lyceum\n');
      final config = load('');
      expect(config.package, 'lyceum');
      expect(config.layering.package, 'lyceum');
    });

    test('the package\'s own tool/apsira_tools.yaml is RELAY too', () {
      expectRelay(ApsiraToolsConfig.load());
    });
  });

  group('values', () {
    test('every key is read', () {
      final config = load('''
package: lyceum
layering:
  root: src
  domain_packages: [meta]
  feature_packages: [flutter, meta]
  shared_packages: [apsira_core]
  colour_literal_exempt: [app/theme/, app/brand/]
  disabled_rules: [colour-literals]
l10n:
  config: l10n.yaml
  required_locales: [en, es, ca]
  scan_exemptions: [app/l10n/generated/]
coverage: { run: test/domain, min_lines: 80, min_branches: 70.5 }
privacy:
  allowlist: tool/allow.yaml
  declared_permissions: tool/perms.txt
''');
      expect(config.package, 'lyceum');
      expect(config.layering.package, 'lyceum');
      expect(config.layering.root, 'src');
      expect(config.layering.domainPackages, {'meta'});
      expect(config.layering.featurePackages, {'flutter', 'meta'});
      expect(config.layering.sharedPackages, {'apsira_core'});
      expect(config.layering.colourLiteralExempt, ['app/theme/', 'app/brand/']);
      expect(config.layering.disabledRules, {'colour-literals'});
      expect(config.l10n.config, 'l10n.yaml');
      expect(config.l10n.requiredLocales, ['en', 'es', 'ca']);
      expect(config.l10n.scanExemptions, ['app/l10n/generated/']);
      expect(config.coverage.run, 'test/domain');
      expect(config.coverage.minLines, 80);
      expect(config.coverage.minBranches, 70.5);
      expect(config.privacy.allowlist, 'tool/allow.yaml');
      expect(config.privacy.declaredPermissions, 'tool/perms.txt');
    });

    test('privacy.holds_network: true is read (v0.6, D-APK-024)', () {
      expect(
        load('privacy:\n  holds_network: true\n').privacy.holdsNetwork,
        isTrue,
      );
      expect(
        load('privacy:\n  holds_network: false\n').privacy.holdsNetwork,
        isFalse,
      );
    });

    test('an empty list is a value, not the default', () {
      final config = load('layering:\n  shared_packages: []\n');
      expect(config.layering.sharedPackages, isEmpty);
    });
  });

  group('usage errors name the key and the file', () {
    void rejects(String yaml, String what) {
      expect(
        () => load(yaml),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains(what))
              .having((e) => e.message, 'message', contains('tools.yaml')),
        ),
        reason: yaml,
      );
    }

    test('an unknown key, at the top or in a section', () {
      rejects('pakage: lyceum\n', 'pakage');
      rejects(
        'layering:\n  domain_package: [meta]\n',
        'layering.domain_package',
      );
      rejects('coverage:\n  min_line: 80\n', 'coverage.min_line');
    });

    test('a wrong type', () {
      rejects('package: [a]\n', 'package');
      rejects('layering: lib\n', 'layering');
      rejects(
        'layering:\n  domain_packages: meta\n',
        'layering.domain_packages',
      );
      rejects(
        'layering:\n  domain_packages: [[meta]]\n',
        'layering.domain_packages',
      );
      rejects('coverage:\n  min_lines: lots\n', 'coverage.min_lines');
      rejects('coverage:\n  min_lines: 101\n', 'coverage.min_lines');
      rejects('coverage:\n  run: 3\n', 'coverage.run');
      rejects(
        'privacy:\n  holds_network: yes please\n',
        'privacy.holds_network',
      );
      rejects('privacy:\n  holds_network: 1\n', 'privacy.holds_network');
      rejects('- a list\n', 'is not a map');
    });

    test('unparsable YAML', () {
      rejects('layering: [unclosed\n', 'tools.yaml');
    });

    test('an unknown rule in disabled_rules', () {
      rejects(
        'layering:\n  disabled_rules: [colour-literal]\n',
        'colour-literal',
      );
    });

    test('an unknown shared package', () {
      rejects('layering:\n  shared_packages: [apsira_kit]\n', 'apsira_kit');
    });
  });

  group('the command lines', () {
    const runners = <String, _Runner>{
      'layering_lint': runLayeringLint,
      'l10n_check': runL10nCheck,
      'coverage_gate': runCoverageGate,
      'deps_check': runDepsCheck,
      'manifest_check': runManifestCheck,
    };

    test('each exits 2 naming an unknown key in its --config', () async {
      final bad = write('bad.yaml', 'layering:\n  nope: 1\n');
      for (final MapEntry(key: name, value: run) in runners.entries) {
        final (code, out) = await _run(run, ['--config', bad]);
        expect(code, 2, reason: '$name: $out');
        expect(out, contains('layering.nope'), reason: name);
        expect(out, contains(bad), reason: name);
      }
    });

    test('each treats a missing --config like an empty one', () async {
      final empty = write('empty.yaml', '');
      final args = <String, List<String>>{
        'layering_lint': ['--root', 'test/fixtures/layering/violations'],
        'l10n_check': [
          '--l10n-config',
          write('l10n.yaml', 'arb-dir: lib/app/l10n\n'),
          '--arb-dir',
          'test/fixtures/l10n/missing_key',
          '--source-dir',
          'test/fixtures/l10n/hard_coded_text',
        ],
        'coverage_gate': [
          '--lcov',
          'test/fixtures/coverage/no_domain.info',
          '--root',
          dir.path,
        ],
        'deps_check': [
          '--deps-json',
          'test/fixtures/privacy/deps_with_http.json',
          '--lib',
          dir.path,
        ],
        'manifest_check': [
          '--manifest',
          'test/fixtures/privacy/manifest_with_internet.xml',
        ],
      };
      for (final MapEntry(key: name, value: run) in runners.entries) {
        final missing = await _run(run, [
          '--config',
          '${dir.path}/missing.yaml',
          ...args[name]!,
        ]);
        final absent = await _run(run, ['--config', empty, ...args[name]!]);
        expect(missing, absent, reason: name);
      }
    });

    test(
      'layering_lint reads package and disabled_rules from --config',
      () async {
        const root = 'test/fixtures/layering/violations';
        final relay = write('relay.yaml', 'package: relay\n');
        final (code, out) = await _run(runLayeringLint, [
          '--config',
          relay,
          '--root',
          root,
        ]);
        expect(code, 1);
        expect(out, contains('layering: 21 violation(s)'));
        final quiet = write('quiet.yaml', '''
package: relay
layering:
  disabled_rules: [colour-literals, placement]
''');
        final (_, fewer) = await _run(runLayeringLint, [
          '--config',
          quiet,
          '--root',
          root,
        ]);
        expect(fewer, contains('layering: 18 violation(s)'));
        expect(fewer, isNot(contains('colour-literals')));
      },
    );

    test('layering_lint takes root from --config; --root still wins', () async {
      final config = write('root.yaml', '''
package: relay
layering:
  root: test/fixtures/layering/clean
''');
      final (code, out) = await _run(runLayeringLint, ['--config', config]);
      expect(code, 0, reason: out);
      expect(out, contains('layering: test/fixtures/layering/clean clean'));
      final (overridden, _) = await _run(runLayeringLint, [
        '--config',
        config,
        '--root',
        'test/fixtures/layering/violations',
      ]);
      expect(overridden, 1);
    });

    test('l10n_check reads --l10n-config for the gen-l10n file and '
        '--config for the tools file', () async {
      final l10n = write('l10n.yaml', '''
arb-dir: test/fixtures/l10n/missing_key
template-arb-file: app_en.arb
''');
      final (code, out) = await _run(runL10nCheck, [
        '--l10n-config',
        l10n,
        '--source-dir',
        dir.path,
      ]);
      expect(code, 1);
      expect(out, contains("missing_key/app_es.arb: 'noteDeleted' is missing"));

      final tools = write('tools.yaml', 'l10n:\n  config: $l10n\n');
      final (viaTools, out2) = await _run(runL10nCheck, [
        '--config',
        tools,
        '--source-dir',
        dir.path,
      ]);
      expect(viaTools, 1);
      expect(out2, out);

      final catalan = write('ca.yaml', '''
l10n:
  config: $l10n
  required_locales: [en, es, ca]
''');
      final (_, out3) = await _run(runL10nCheck, [
        '--config',
        catalan,
        '--source-dir',
        dir.path,
      ]);
      expect(out3, contains('missing_key/app_ca.arb: is missing'));
    });

    test('l10n_check takes scan_exemptions from --config', () async {
      final source = '${dir.path}/src';
      File('$source/features/x/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("final w = Text('Hello');\n");
      final l10n = write('l10n.yaml', '''
arb-dir: test/fixtures/l10n/missing_key
''');
      final exempt = write('exempt.yaml', '''
l10n:
  config: $l10n
  scan_exemptions: [features/x/]
''');
      final (_, flagged) = await _run(runL10nCheck, [
        '--l10n-config',
        l10n,
        '--source-dir',
        source,
      ]);
      expect(flagged, contains('a.dart:1'));
      final (_, quiet) = await _run(runL10nCheck, [
        '--config',
        exempt,
        '--source-dir',
        source,
      ]);
      expect(quiet, isNot(contains('a.dart:1')));
    });

    test(
      'coverage_gate takes its thresholds from --config; flags win',
      () async {
        final lcov = 'test/fixtures/coverage/domain_below.info';
        final low = write('low.yaml', 'coverage: { min_lines: 80 }\n');
        final (code, out) = await _run(runCoverageGate, [
          '--config',
          low,
          '--lcov',
          lcov,
        ]);
        expect(code, 0, reason: out);
        expect(out, contains('minimum 80% lines, 85% branches'));
        final (strict, _) = await _run(runCoverageGate, [
          '--config',
          low,
          '--lcov',
          lcov,
          '--min-lines',
          '90',
        ]);
        expect(strict, 1);
      },
    );

    test('coverage_gate takes --run from --config', () async {
      final config = write('run.yaml', 'coverage: { run: test/domain }\n');
      final out = StringBuffer();
      final code = await runCoverageGate(
        ['--config', config, '--root', dir.path],
        out: out,
        runTests: (args, workingDirectory) async => 0,
      );
      expect(code, 1);
      expect('$out', contains('no test directory test/domain'));
    });

    test(
      'deps_check and manifest_check take their files from --config',
      () async {
        final allow = write('allow.yaml', 'allowed:\n  meta: test\n');
        final deps = write('deps.yaml', 'privacy: { allowlist: $allow }\n');
        final (code, out) = await _run(runDepsCheck, [
          '--config',
          deps,
          '--deps-json',
          'test/fixtures/privacy/deps_network_dev_only.json',
          '--lib',
          dir.path,
        ]);
        expect(code, 1, reason: out);
        expect(out, contains('not on the allowlist: collection'));
        expect(out, contains(allow));

        final declared = write('perms.txt', '');
        final perms = write(
          'perms.yaml',
          'privacy: { declared_permissions: $declared }\n',
        );
        final (code2, out2) = await _run(runManifestCheck, [
          '--config',
          perms,
          '--manifest',
          'test/fixtures/privacy/manifest_extra_permission.xml',
        ]);
        expect(code2, 1);
        expect(
          out2,
          contains('undeclared permission: android.permission.CAMERA'),
        );
        expect(out2, contains(declared));
      },
    );
  });
}
