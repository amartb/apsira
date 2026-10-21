// The per-app configuration of the five tools (D-APK-002): every constant
// that was RELAY's is a key in tool/apsira_tools.yaml, read by every command
// with `--config <path>` (default tool/apsira_tools.yaml). An absent or
// empty file reproduces RELAY's values exactly; `package` defaults to the
// pubspec's `name:`. An unknown key, a wrong type or unparsable YAML is a
// usage error ([FormatException], exit 2) naming the key and the file, so a
// typo never falls back to RELAY's defaults in silence.
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'coverage_gate.dart' show defaultMinBranches, defaultMinLines;
import 'l10n_check.dart' as l10n show requiredLocales, scanExemptions;
import 'layering_lint.dart'
    as lint
    show LayerKind, domainPackages, featurePackages, layeringRules;

/// Where every command looks for its configuration.
const defaultConfigPath = 'tool/apsira_tools.yaml';

/// The packages `shared_packages` may name, and the layer an import of each
/// counts as (D-APK-002): `apsira_core` is as pure as core/, `apsira_ui` is
/// a theme-layer import.
const sharedPackageLayers = {
  'apsira_core': lint.LayerKind.core,
  'apsira_ui': lint.LayerKind.theme,
};

/// The `layering` section and the top-level `package`.
final class LayeringConfig {
  const LayeringConfig({
    this.package = 'relay',
    this.root = 'lib',
    this.domainPackages = lint.domainPackages,
    this.featurePackages = lint.featurePackages,
    this.sharedPackages = const {'apsira_core', 'apsira_ui'},
    this.colourLiteralExempt = const ['app/theme/'],
    this.disabledRules = const {},
  });

  /// RELAY's constants, with the two shared packages of D-APK-002.
  static const relay = LayeringConfig();

  /// The package whose `package:<package>/` URIs map to [root].
  final String package;
  final String root;
  final Set<String> domainPackages;
  final Set<String> featurePackages;

  /// Keys of [sharedPackageLayers].
  final Set<String> sharedPackages;

  /// Path prefixes, relative to [root], where colour literals may live.
  final List<String> colourLiteralExempt;

  /// Rule ids whose findings are dropped.
  final Set<String> disabledRules;
}

/// The `l10n` section.
final class L10nConfig {
  const L10nConfig({
    this.config = 'lib/app/l10n/l10n.yaml',
    this.requiredLocales = l10n.requiredLocales,
    this.scanExemptions = l10n.scanExemptions,
  });

  /// The gen-l10n file naming the ARB directory and the template.
  final String config;
  final List<String> requiredLocales;
  final List<String> scanExemptions;
}

/// The `coverage` section.
final class CoverageConfig {
  const CoverageConfig({
    this.run,
    this.minLines = defaultMinLines,
    this.minBranches = defaultMinBranches,
  });

  /// The test directory `--run` defaults to; RELAY's default is none.
  final String? run;
  final double minLines;
  final double minBranches;
}

/// The `privacy` section.
final class PrivacyConfig {
  const PrivacyConfig({
    this.allowlist = 'tool/privacy/dependency_allowlist.yaml',
    this.declaredPermissions = 'tool/privacy/declared_permissions.txt',
  });

  final String allowlist;
  final String declaredPermissions;
}

/// tool/apsira_tools.yaml.
final class ApsiraToolsConfig {
  const ApsiraToolsConfig({
    this.layering = LayeringConfig.relay,
    this.l10n = const L10nConfig(),
    this.coverage = const CoverageConfig(),
    this.privacy = const PrivacyConfig(),
  });

  /// RELAY's constants.
  static const relay = ApsiraToolsConfig();

  final LayeringConfig layering;
  final L10nConfig l10n;
  final CoverageConfig coverage;
  final PrivacyConfig privacy;

  String get package => layering.package;

  /// Reads [path]; an absent file is an empty one. `package` defaults to
  /// the `name:` of [pubspec] (RELAY's `relay` when there is no pubspec).
  /// Throws [FormatException] naming the key and [path] on a usage error.
  static ApsiraToolsConfig load({
    String path = defaultConfigPath,
    String pubspec = 'pubspec.yaml',
  }) {
    final file = File(path);
    final text = file.existsSync() ? file.readAsStringSync() : '';
    return parse(text, source: path, package: _pubspecName(pubspec));
  }

  /// Parses [text], the content of [source]; [package] is the default of
  /// the `package` key.
  static ApsiraToolsConfig parse(
    String text, {
    String source = defaultConfigPath,
    String? package,
  }) {
    final Object? doc;
    try {
      doc = loadYaml(text, sourceUrl: Uri.file(source));
    } on YamlException catch (e) {
      throw FormatException('$source: not valid YAML: ${e.message}');
    }
    if (doc == null) {
      return ApsiraToolsConfig(
        layering: _layering(
          null,
          source,
          package ?? LayeringConfig.relay.package,
        ),
      );
    }
    if (doc is! YamlMap) throw FormatException('$source: is not a map');
    final top = _Section(doc, '', source)
      ..only(const {'package', 'layering', 'l10n', 'coverage', 'privacy'});
    final name =
        top.string('package') ?? package ?? LayeringConfig.relay.package;
    return ApsiraToolsConfig(
      layering: _layering(top.section('layering'), source, name),
      l10n: _l10n(top.section('l10n')),
      coverage: _coverage(top.section('coverage')),
      privacy: _privacy(top.section('privacy')),
    );
  }

  static LayeringConfig _layering(_Section? s, String source, String package) {
    const d = LayeringConfig.relay;
    s?.only(const {
      'root',
      'domain_packages',
      'feature_packages',
      'shared_packages',
      'colour_literal_exempt',
      'disabled_rules',
    });
    final shared = s?.strings('shared_packages')?.toSet();
    for (final name in shared ?? const <String>{}) {
      if (!sharedPackageLayers.containsKey(name)) {
        throw FormatException(
          '$source: layering.shared_packages: unknown package $name '
          '(known: ${sharedPackageLayers.keys.join(', ')})',
        );
      }
    }
    final disabled = s?.strings('disabled_rules')?.toSet();
    for (final rule in disabled ?? const <String>{}) {
      if (!lint.layeringRules.containsKey(rule)) {
        throw FormatException(
          '$source: layering.disabled_rules: unknown rule $rule',
        );
      }
    }
    return LayeringConfig(
      package: package,
      root: s?.string('root') ?? d.root,
      domainPackages:
          s?.strings('domain_packages')?.toSet() ?? d.domainPackages,
      featurePackages:
          s?.strings('feature_packages')?.toSet() ?? d.featurePackages,
      sharedPackages: shared ?? d.sharedPackages,
      colourLiteralExempt:
          s?.strings('colour_literal_exempt') ?? d.colourLiteralExempt,
      disabledRules: disabled ?? d.disabledRules,
    );
  }

  static L10nConfig _l10n(_Section? s) {
    const d = L10nConfig();
    s?.only(const {'config', 'required_locales', 'scan_exemptions'});
    return L10nConfig(
      config: s?.string('config') ?? d.config,
      requiredLocales: s?.strings('required_locales') ?? d.requiredLocales,
      scanExemptions: s?.strings('scan_exemptions') ?? d.scanExemptions,
    );
  }

  static CoverageConfig _coverage(_Section? s) {
    const d = CoverageConfig();
    s?.only(const {'run', 'min_lines', 'min_branches'});
    return CoverageConfig(
      run: s?.string('run') ?? d.run,
      minLines: s?.percentage('min_lines') ?? d.minLines,
      minBranches: s?.percentage('min_branches') ?? d.minBranches,
    );
  }

  static PrivacyConfig _privacy(_Section? s) {
    const d = PrivacyConfig();
    s?.only(const {'allowlist', 'declared_permissions'});
    return PrivacyConfig(
      allowlist: s?.string('allowlist') ?? d.allowlist,
      declaredPermissions:
          s?.string('declared_permissions') ?? d.declaredPermissions,
    );
  }
}

/// The `name:` of the pubspec at [path], or null when it cannot be read.
String? _pubspecName(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final match = RegExp(
    r'^name:\s*([A-Za-z_]\w*)',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  return match?[1];
}

/// One map of the file, with typed readers that name `<prefix><key>`.
final class _Section {
  _Section(this.map, this.prefix, this.source);

  final YamlMap map;
  final String prefix;
  final String source;

  Never _wrong(String key, String want) => throw FormatException(
    '$source: $prefix$key must be $want, not ${map[key]}',
  );

  /// Rejects any key outside [known].
  void only(Set<String> known) {
    for (final key in map.keys) {
      if (!known.contains('$key')) {
        throw FormatException('$source: unknown key $prefix$key');
      }
    }
  }

  /// The section under [key]; null when absent or empty.
  _Section? section(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! YamlMap) _wrong(key, 'a map');
    return _Section(value, '$prefix$key.', source);
  }

  String? string(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String) _wrong(key, 'a string');
    return value;
  }

  List<String>? strings(String key) {
    if (!map.containsKey(key)) return null;
    final value = map[key];
    if (value is! YamlList || value.any((e) => e is! String)) {
      _wrong(key, 'a list of strings');
    }
    return [for (final e in value) e as String];
  }

  double? percentage(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! num || value < 0 || value > 100) {
      _wrong(key, 'a percentage');
    }
    return value.toDouble();
  }
}
