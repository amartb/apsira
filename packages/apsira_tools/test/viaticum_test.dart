// The v0.2 knobs (D-APK-002 "config knob in v0.2"): VIATICUM @ 20f05f6 as
// configuration. test/fixtures/viaticum/apsira_tools.yaml sets every key
// whose value differs from RELAY's; each knob has a passing case and a
// failing one in test/fixtures/viaticum/ (its README maps them), and the
// passing cases that RELAY's defaults refuse show that the knob, not the
// fixture, decides. The VIATICUM-specific items (the Spike lab layer and
// `lab-imports`, the archival terms, the backup attributes, the printed
// network-exception paths) stay in VIATICUM. Tests run from the package root.
import 'package:apsira_tools/src/config.dart';
import 'package:apsira_tools/src/coverage_gate.dart';
import 'package:apsira_tools/src/deps_check.dart';
import 'package:apsira_tools/src/l10n_check.dart';
import 'package:apsira_tools/src/layering_lint.dart';
import 'package:apsira_tools/src/manifest_check.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/viaticum';
const _config = '$_fixtures/apsira_tools.yaml';
const _pubspec = '$_fixtures/privacy/pubspec.yaml';

typedef _Runner = Future<int> Function(List<String> args, {StringSink? out});

Future<(int, String)> _run(_Runner run, List<String> args) async {
  final out = StringBuffer();
  final code = await run(args, out: out);
  return (code, out.toString());
}

final _viaticum = ApsiraToolsConfig.load(path: _config, pubspec: _pubspec);

/// RELAY's defaults for the same package name.
final _relay = ApsiraToolsConfig.parse('package: viaticum');

/// A finding reduced to where, what and which rule.
Set<String> _lint(String tree, ApsiraToolsConfig config) => {
  for (final v in checkLayering(
    '$_fixtures/layering/$tree',
    config: config.layering,
  ))
    '${v.file.substring('$_fixtures/layering/$tree/'.length)}:${v.line} '
        '${v.what} ${v.rule}',
};

void main() {
  group('the fixture config', () {
    test('an empty file keeps RELAY\'s values for every v0.2 key', () {
      final relay = ApsiraToolsConfig.relay;
      expect(relay.layering.forbiddenCalls, forbiddenCallGroups.keys.toSet());
      expect(relay.layering.extraLayers, isEmpty);
      expect(relay.layering.forbiddenPackages, isEmpty);
      expect(relay.layering.mayImport, isEmpty);
      expect(relay.l10n.textCalls, ['Text']);
      expect(relay.coverage.exemptExportOnly, isTrue);
      expect(relay.privacy.dependenciesDoc, isNull);
      expect(relay.privacy.manifest, isNull);
      expect(relay.privacy.approvedPermissions, isNull);
      expect(relay.privacy.approvedHeading, '### 11.1');
      expect(ApsiraToolsConfig.parse('').layering.forbiddenCalls, {
        'system-time',
        'random',
        'uuid',
        'clock-package',
      });
    });

    for (final (yaml, error) in [
      ('layering: {forbidden_calls: [sundial]}', 'unknown call group sundial'),
      ('layering: {extra_layers: {app/x/: lab}}', 'unknown layer lab'),
      ('layering: {extra_layers: [app/x/]}', 'extra_layers must be a map'),
      (
        'layering: {forbidden_packages: {app/x/: riverpod}}',
        'a list of strings',
      ),
      ('layering: {may_import: {router: [data]}}', 'may_import: router'),
      ('layering: {may_import: {l10n: [moon]}}', 'unknown layer moon'),
      ('layering: {disabled_rules: [layer-packages]}', null),
      ('l10n: {text_calls: [RichText]}', 'unknown call RichText'),
      ('coverage: {exempt_export_only: false}', null),
      ('coverage: {exempt_export_only: maybe}', 'must be true or false'),
    ]) {
      test('${error == null ? 'accepts' : 'refuses'} $yaml', () {
        if (error == null) {
          expect(() => ApsiraToolsConfig.parse(yaml), returnsNormally);
        } else {
          expect(
            () => ApsiraToolsConfig.parse(yaml, source: 'tools.yaml'),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                allOf(startsWith('tools.yaml: '), contains(error)),
              ),
            ),
          );
        }
      });
    }

    test("the worked example sets every v0.2 key to RELAY's value", () {
      final example = ApsiraToolsConfig.load(path: 'tool/apsira_tools.yaml');
      const relay = ApsiraToolsConfig.relay;
      expect(example.layering.forbiddenCalls, relay.layering.forbiddenCalls);
      expect(example.layering.extraLayers, isEmpty);
      expect(example.layering.forbiddenPackages, isEmpty);
      expect(example.layering.mayImport, isEmpty);
      expect(example.l10n.textCalls, relay.l10n.textCalls);
      expect(example.coverage.exemptExportOnly, isTrue);
      expect(example.privacy.dependenciesDoc, isNull);
      expect(example.privacy.manifest, isNull);
      expect(example.privacy.approvedPermissions, isNull);
      expect(example.privacy.approvedHeading, relay.privacy.approvedHeading);
    });

    test('reads every v0.2 key', () {
      final layering = _viaticum.layering;
      expect(layering.forbiddenCalls, {'system-time', 'random', 'uuid'});
      expect(layering.extraLayers, {'app/tutorial/': LayerKind.router});
      expect(layering.forbiddenPackages, {
        'app/tutorial/': {
          'flutter_riverpod',
          'riverpod',
          'riverpod_annotation',
        },
      });
      expect(layering.mayImport, {
        LayerKind.l10n: {LayerKind.core, LayerKind.theme, LayerKind.l10n},
      });
      expect(_viaticum.l10n.textCalls, ['Text', 'SelectableText', 'TextSpan']);
      expect(_viaticum.coverage.exemptExportOnly, isFalse);
      expect(
        _viaticum.privacy.dependenciesDoc,
        '$_fixtures/privacy/dependencies.md',
      );
      expect(
        _viaticum.privacy.manifest,
        '$_fixtures/privacy/manifest_approved.xml',
      );
      expect(
        _viaticum.privacy.approvedPermissions,
        '$_fixtures/privacy/architecture.md',
      );
      expect(_viaticum.privacy.approvedHeading, '### 11.1');
    });
  });

  group('layering_lint', () {
    test('the clean tree passes every knob', () {
      expect(_lint('clean', _viaticum), isEmpty);
    });

    test("RELAY's defaults refuse the clean tree where a knob decides", () {
      expect(_lint('clean', _relay), {
        // domain_packages: crypto is not on RELAY's list.
        'core/log.dart:2 package:crypto/crypto.dart core-imports',
        // forbidden_calls: RELAY's clock-package group.
        'domain/trips/trip.dart:8 .isToday pure-calls',
        // disabled_rules: RELAY's colour-literals rule.
        'features/trips/trips_screen.dart:4 Color(…) colour-literals',
        // extra_layers: app/tutorial/ is no layer of RELAY's.
        'app/tutorial/tour.dart:1 app/tutorial/tour.dart placement',
      });
    });

    test('each knob fails its breaking case', () {
      expect(_lint('violations', _viaticum), {
        // forbidden_packages: layer-packages.
        'app/tutorial/tour.dart:2 '
            'package:flutter_riverpod/flutter_riverpod.dart layer-packages',
        // extra_layers: app/tutorial/ is router-like, so never data/.
        'app/tutorial/tour.dart:4 package:viaticum/data/trips_dao.dart '
            'app-imports',
        // may_import: l10n does not read domain/ here.
        'app/l10n/strings.dart:2 package:viaticum/domain/trips/trip.dart '
            'theme-l10n-imports',
        // domain_packages: clock is not on VIATICUM's list.
        'domain/trips/trip.dart:2 package:clock/clock.dart domain-imports',
        // forbidden_calls: the system-time group.
        'domain/trips/trip.dart:5 DateTime.now() pure-calls',
        // feature_packages: no json_annotation.
        'features/trips/trips_screen.dart:2 '
            'package:json_annotation/json_annotation.dart feature-packages',
      });
    });

    test('the command line counts the configured rule and names it', () async {
      final clean = await _run(runLayeringLint, [
        '--config',
        _config,
        '--pubspec',
        _pubspec,
        '--root',
        '$_fixtures/layering/clean',
      ]);
      expect(clean.$1, 0);
      expect(clean.$2, contains('(8 files, 15 rules)'));

      final (code, out) = await _run(runLayeringLint, [
        '--config',
        _config,
        '--pubspec',
        _pubspec,
        '--root',
        '$_fixtures/layering/violations',
      ]);
      expect(code, 1);
      expect(
        out,
        contains(
          "tour.dart:2: import 'package:flutter_riverpod/flutter_riverpod.dart' "
          'breaks layer-packages: ',
        ),
      );
      expect(out, contains('layering: 6 violation(s)'));
    });
  });

  group('l10n_check', () {
    Future<(int, String)> l10n(String dir, {String config = _config}) => _run(
      runL10nCheck,
      ['--config', config, '--source-dir', '$_fixtures/l10n/$dir'],
    );

    test('text_calls: the clean tree passes', () async {
      final (code, out) = await l10n('clean');
      expect(code, 0, reason: out);
      expect(
        out,
        contains(
          'no string literal passed to Text(, SelectableText( or '
          'TextSpan(text: in $_fixtures/l10n/clean',
        ),
      );
    });

    test('text_calls: a literal to each scanned call fails', () async {
      final problems = scanHardCodedText(
        '$_fixtures/l10n/violations',
        calls: _viaticum.l10n.textCalls,
      );
      expect(problems.map((p) => '${p.line} ${p.message}'), [
        "4 passes 'Plain' to Text(: use AppLocalizations (D-030)",
        "5 passes 'Trip' to SelectableText(: use AppLocalizations (D-030)",
        "6 passes 'Day' to TextSpan(text:: use AppLocalizations (D-030)",
      ]);
      final (code, _) = await l10n('violations');
      expect(code, 1);
    });

    test("RELAY's default scans Text( only", () {
      final problems = scanHardCodedText('$_fixtures/l10n/violations');
      expect(problems.map((p) => p.line), [4]);
    });

    test('scan_exemptions: the Spike lab is skipped only when listed', () {
      expect(
        scanHardCodedText(
          '$_fixtures/l10n/clean',
          exemptions: const [],
          calls: _viaticum.l10n.textCalls,
        ).map((p) => p.file),
        ['$_fixtures/l10n/clean/features/spike_lab/lab.dart'],
      );
    });
  });

  group('coverage_gate', () {
    Future<(int, String)> gate(String root, {String config = _config}) =>
        _run(runCoverageGate, [
          '--config',
          config,
          '--root',
          '$_fixtures/coverage/$root',
          '--lcov',
          '$_fixtures/coverage/trip_only.info',
        ]);

    test(
      'exempt_export_only false: a barrel missing from lcov fails',
      () async {
        final (code, out) = await gate('barrel');
        expect(code, 1);
        expect(
          out,
          contains(
            'FAIL: domain file missing: lib/domain/viaticum_domain.dart',
          ),
        );
      },
    );

    test('exempt_export_only false: a tree whose files are all covered '
        'passes', () async {
      final (code, out) = await gate('no_barrel');
      expect(code, 0, reason: out);
    });

    test("RELAY's default exempts the barrel with a notice", () async {
      final (code, out) = await gate(
        'barrel',
        config: '$_fixtures/absent.yaml',
      );
      expect(code, 0, reason: out);
      expect(out, contains('export-only library, nothing to cover'));
    });
  });

  group('deps_check', () {
    Future<(int, String)> deps(List<String> extra) => _run(runDepsCheck, [
      '--config',
      _config,
      '--deps-json',
      '$_fixtures/privacy/deps.json',
      '--lib',
      '$_fixtures/layering/clean',
      '--pubspec',
      _pubspec,
      ...extra,
    ]);

    test(
      'dependencies_doc: every direct dependency with a row passes',
      () async {
        final (code, out) = await deps(const []);
        expect(code, 0, reason: out);
        expect(
          out,
          contains(
            'every direct dependency has its row in '
            '$_fixtures/privacy/dependencies.md',
          ),
        );
      },
    );

    test('dependencies_doc: a dependency with no row fails', () async {
      final missing = '$_fixtures/privacy/dependencies_missing_row.md';
      final (code, out) = await deps(['--dependencies-doc', missing]);
      expect(code, 1);
      expect(out, contains('deps: no row in $missing: crypto'));
    });

    test('missingRows skips the SDK and reads both sections', () {
      expect(
        missingRows(
          'dependencies:\n  flutter:\n    sdk: flutter\n  a: any\n'
              'dev_dependencies:\n  b: any\n',
          '| a | runtime |\n',
        ),
        ['b'],
      );
    });

    test("RELAY's default runs no table check", () async {
      final (code, out) = await _run(runDepsCheck, [
        '--config',
        '$_fixtures/absent.yaml',
        '--allowlist',
        '$_fixtures/privacy/dependency_allowlist.yaml',
        '--deps-json',
        '$_fixtures/privacy/deps.json',
        '--lib',
        '$_fixtures/layering/clean',
      ]);
      expect(code, 0, reason: out);
      expect(out, isNot(contains('row')));
    });
  });

  group('manifest_check', () {
    test('approved_permissions: every permission approved or the app\'s own, '
        'from the configured manifest', () async {
      final (code, out) = await _run(runManifestCheck, ['--config', _config]);
      expect(code, 0, reason: out);
      expect(
        out,
        contains(
          'each in $_fixtures/privacy/architecture.md '
          "### 11.1 or the app's own",
        ),
      );
    });

    test('approved_permissions: a permission outside the section, and a '
        'declared one without a reason, fail', () async {
      final (code, out) = await _run(runManifestCheck, [
        '--config',
        _config,
        '$_fixtures/privacy/manifest_outside.xml',
        '--declared',
        '$_fixtures/privacy/declared_outside.txt',
      ]);
      expect(code, 1);
      final outside =
          'outside $_fixtures/privacy/architecture.md ### 11.1: '
          'android.permission.CAMERA';
      expect(out, contains('manifest: $outside'));
      expect(
        out,
        contains(
          'manifest: the declared list holds android.permission.CAMERA, '
          'which is outside $_fixtures/privacy/architecture.md ### 11.1',
        ),
      );
      expect(
        out,
        contains(
          'manifest: declared without a reason: '
          'android.permission.WAKE_LOCK',
        ),
      );
    });

    test('--architecture names the source on the command line', () async {
      final (code, out) = await _run(runManifestCheck, [
        '--config',
        '$_fixtures/absent.yaml',
        '--declared',
        '$_fixtures/privacy/declared_permissions.txt',
        '--architecture',
        '$_fixtures/privacy/architecture.md',
        '$_fixtures/privacy/manifest_outside.xml',
      ]);
      expect(code, 1);
      expect(out, contains('android.permission.CAMERA'));
    });

    test('a source with no such section exits 2', () async {
      final (code, out) = await _run(runManifestCheck, [
        '--config',
        _config,
        '--architecture',
        '$_fixtures/privacy/dependencies.md',
      ]);
      expect(code, 2);
      expect(
        out,
        contains(
          'manifest: no ### 11.1 permission table in '
          '$_fixtures/privacy/dependencies.md',
        ),
      );
    });

    test('the manifest may be positional, as --manifest', () async {
      final manifest = '$_fixtures/privacy/manifest_approved.xml';
      final declared = '$_fixtures/privacy/declared_permissions.txt';
      final config = '$_fixtures/absent.yaml';
      final positional = await _run(runManifestCheck, [
        '--config',
        config,
        manifest,
        '--declared',
        declared,
      ]);
      final flag = await _run(runManifestCheck, [
        '--config',
        config,
        '--manifest',
        manifest,
        '--declared',
        declared,
      ]);
      expect(positional, flag);
      expect(positional.$1, 0, reason: positional.$2);
      final twice = await _run(runManifestCheck, [
        '--config',
        config,
        manifest,
        manifest,
      ]);
      expect(twice.$1, 2);
    });

    test("RELAY's default checks no approved source", () async {
      final (code, out) = await _run(runManifestCheck, [
        '--config',
        '$_fixtures/absent.yaml',
        '--manifest',
        '$_fixtures/privacy/manifest_outside.xml',
        '--declared',
        '$_fixtures/privacy/declared_outside.txt',
      ]);
      expect(code, 0, reason: out);
    });
  });
}
