// The public libraries of apsira_tools (F6): every symbol RELAY's, VIATICUM's
// and LYCEUM's tool wrappers took from `package:apsira_tools/src/…` in their
// v0.2.0 adoption is reachable through `package:apsira_tools/<check>.dart`
// and through the barrel `package:apsira_tools/apsira_tools.dart`, and each
// per-check library re-exports its whole src/ library (RELAY's wrappers
// re-export all of it). This file imports no src/ library.
import 'dart:io';

import 'package:apsira_tools/apsira_tools.dart' as barrel;
import 'package:apsira_tools/config.dart';
import 'package:apsira_tools/coverage_gate.dart';
import 'package:apsira_tools/deps_check.dart';
import 'package:apsira_tools/l10n_check.dart';
import 'package:apsira_tools/layering_lint.dart';
import 'package:apsira_tools/manifest_check.dart';
import 'package:test/test.dart';

const _checks = [
  'config',
  'coverage_gate',
  'deps_check',
  'l10n_check',
  'layering_lint',
  'manifest_check',
];

void main() {
  test('each per-check library re-exports its whole src/ library', () {
    for (final check in _checks) {
      final source = File('lib/$check.dart').readAsStringSync();
      expect(
        source,
        contains("export 'src/$check.dart';"),
        reason: 'lib/$check.dart exports src/$check.dart without show/hide',
      );
    }
    final barrelSource = File('lib/apsira_tools.dart').readAsStringSync();
    for (final check in _checks) {
      expect(barrelSource, contains("export '$check.dart';"));
    }
  });

  test('config: what VIATICUM and LYCEUM read from ApsiraToolsConfig', () {
    const ApsiraToolsConfig config = ApsiraToolsConfig.relay;
    final L10nConfig l10n = config.l10n;
    final LayeringConfig layering = config.layering;
    final PrivacyConfig privacy = config.privacy;
    expect(l10n.requiredLocales, ['en', 'es']);
    expect(l10n.scanExemptions, isNotEmpty);
    expect(l10n.textCalls, isNotEmpty);
    expect(l10n.config, isNotEmpty);
    expect(layering.root, 'lib');
    expect(layering.disabledRules, isEmpty);
    expect(layering.extraLayers, isEmpty);
    expect(privacy.declaredPermissions, isNotEmpty);
    expect(privacy.holdsNetwork, isFalse);
    expect(ApsiraToolsConfig.load, isA<Function>());
    expect(barrel.ApsiraToolsConfig.relay, same(config));
  });

  test('coverage_gate: RELAY and VIATICUM run and re-export it', () async {
    final out = StringBuffer();
    expect(await runCoverageGate(['--bogus'], out: out), 2);
    expect(parseLcov(''), isEmpty);
    expect(defaultMinLines, 90.0);
    expect(defaultMinBranches, 85.0);
    expect(domainDir, 'lib/domain/');
    expect(isExportOnlyLibrary("export 'a.dart';"), isTrue);
    expect(const GateResult(true, []).passed, isTrue);
    expect(const UsageError('x').toString(), 'x');
    expect(barrel.runCoverageGate, same(runCoverageGate));
  });

  test('l10n_check: what the wrappers call and re-export', () async {
    expect(await runL10nCheck(['--bogus'], out: StringBuffer()), 2);
    expect(placeholdersIn('Hi {name}'), {'name'});
    expect(L10nProblem('f', 'm', key: 'k').key, 'k');
    expect(checkArbDir, isA<Function>());
    expect(readConfig, isA<Function>());
    expect(scanHardCodedText, isA<Function>());
    expect(
      textCallLiterals("Text('Hello')", const ['Text']).single.$2,
      "'Hello'",
    );
    expect(barrel.placeholdersIn, same(placeholdersIn));
  });

  test('layering_lint: what the wrappers call and re-export', () async {
    expect(await runLayeringLint(['--bogus'], out: StringBuffer()), 2);
    final Layer layer = layerOf('domain/notes/note.dart');
    expect(layer.kind, LayerKind.domain);
    expect(layeringRules, isNotEmpty);
    expect(optionalRules, isNotEmpty);
    expect(pureDartLibraries, isNotEmpty);
    expect(devOnlyPackages('name: x\n'), isEmpty);
    expect(dartFilesUnder, isA<Function>());
    expect(
      checkSource(
        'domain/a.dart',
        "import 'package:flutter/material.dart';\n",
        config: LayeringConfig.relay,
      ),
      isNotEmpty,
    );
    final LayeringViolation violation = LayeringViolation('f', 1, 'w', 'r');
    expect(violation.rule, 'r');
    expect(barrel.layerOf, same(layerOf));
  });

  test('deps_check and manifest_check: what LYCEUM calls', () async {
    expect(await runDepsCheck(['--bogus'], out: StringBuffer()), 2);
    const manifest =
        '<manifest xmlns:tools="http://schemas.android.com/tools">'
        '<uses-permission android:name="a.B"/>'
        '<uses-permission android:name="a.C" tools:node="remove"/>'
        '</manifest>';
    expect(usesPermissions(manifest), {'a.B', 'a.C'});
    expect(removedPermissions(manifest), {'a.C'});
    expect(requestedPermissions(manifest), {'a.B'});
    expect(barrel.requestedPermissions, same(requestedPermissions));
    expect(forbiddenPermissions, contains('android.permission.INTERNET'));
    expect(parseDeclaredPermissions('a.B: reason\n'), {'a.B': 'reason'});
    expect(barrel.runDepsCheck, same(runDepsCheck));
    expect(barrel.runManifestCheck, isA<Function>());
  });
}
