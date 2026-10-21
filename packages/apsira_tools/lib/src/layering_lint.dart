// From relay tool/layering_lint.dart @ 5f606e9
// The import-layering lint (07 P0-09, D-040, architecture §3, 08 §3
// `layering`): fails when a file in lib/ imports across a layer boundary,
// when domain or core code takes the time or an ID directly instead of from
// `Clock` and `IdGen`, or when a file sits outside every layer. No file in
// lib/ may import a package that pubspec.yaml lists only under
// `dev_dependencies`, or silence the `depend_on_referenced_packages` lint
// that such an import trips. Outside `app/theme/` and generated code, no
// file writes a colour literal (CLAUDE.md §1.7, 07 P1-00).
//
//   dart run apsira_tools:layering_lint [--config <file>] [--root <dir>]
//       [--pubspec <file>]
//
// `--root` (default `layering.root` of the config, `lib`) is the directory
// `package:<package>/` maps to, so the suite can point the lint at
// test/fixtures/layering/; `--pubspec` (default `pubspec.yaml`) names the
// dev-only packages and the default `package`. `--config` (default
// tool/apsira_tools.yaml, D-APK-002) holds the allowlists, the shared
// packages, the colour-literal exemptions and the disabled rules. Exit 0
// when clean, 1 naming each `file:line`, the import or call, and the rule;
// 2 on bad usage.
//
// The scan is lexical: comments and string literals are blanked first
// (interpolated expressions are kept), then import and export directives and
// the forbidden calls are matched. It needs no `pub get` and no analyzer.
import 'dart:io';

import 'config.dart';

export 'config.dart' show LayeringConfig;

/// Every rule, by the id a finding names, with what it requires.
const layeringRules = {
  'domain-imports':
      'domain imports only the pure dart: libraries, core/, domain/ and the '
      'allowlist (clock, collection, freezed_annotation, meta, path, rrule, '
      'time; D-043, D-108)',
  'core-imports':
      'core imports only the pure dart: libraries, core/ and the allowlist; '
      'it is as pure as domain and never reaches up',
  'pure-calls':
      'domain and core take time and IDs only from Clock and IdGen: no '
      'DateTime.now(), DateTime.timestamp(), Random() or Uuid(), and none '
      'of the clock and time packages\' readers of the system clock (D-043 addendum)',
  'data-imports':
      'data imports domain/, core/ and data/, never app/ or features/',
  'services-imports':
      'app/services imports domain/, data/, core/ and app/services/, never '
      'presentation',
  'theme-l10n-imports':
      'app/theme and app/l10n import only core/, app/theme/ and app/l10n/; '
      'app/l10n also reads domain/ models, to word them (a rule summary)',
  'app-imports':
      'only the composition roots (main.dart, app/bootstrap.dart) import '
      'data/, and only they and app/router.dart import features/',
  'feature-imports':
      'a feature imports app/services/, domain/, core/, app/theme/, '
      'app/l10n/ and its own folder, never data/ or the app shell',
  'feature-packages':
      'features never import Drift or plugins: only the packages on the '
      'features allowlist (layering.feature_packages)',
  'cross-feature': 'a feature never imports another feature',
  'dev-packages':
      'lib/ never imports a package pubspec.yaml lists only under '
      'dev_dependencies (Flutter leaves those out of release builds)',
  'lint-suppression':
      'no lib/ file silences depend_on_referenced_packages, the lint a '
      'dev-only package import trips',
  'placement':
      'every file sits in a known layer and imports only inside the package',
  'colour-literals':
      'colours come from the theme: no Color(…), Color.fromARGB(…), '
      'Color.fromRGBO(…), Color.from(…) or Colors.… outside '
      'layering.colour_literal_exempt (app/theme/) and generated code '
      '(*.g.dart, *.freezed.dart; CLAUDE.md §1.7)',
};

/// The `dart:` libraries domain and core may use: no I/O, isolates, FFI or
/// UI.
const pureDartLibraries = {
  'async',
  'collection',
  'convert',
  'core',
  'math',
  'typed_data',
};

/// Packages domain and core may import (architecture §3, D-043). Each
/// addition needs a decision-log entry. rrule and its closure (time, clock,
/// path) joined in the D-043 addendum; domain still takes time
/// only from the Clock port, so the clock package's time sources are
/// [_forbiddenCalls]. freezed_annotation joined in D-108 for the freezed
/// domain models (it re-exports json_annotation and meta); the freezed
/// builder and a direct json_annotation import stay out.
const domainPackages = {
  'clock',
  'collection',
  'freezed_annotation',
  'meta',
  'path',
  'rrule',
  'time',
};

/// Packages features may import. Drift and plugins are never on it; a
/// pure-Dart or Flutter-only UI package joins it in the task that adds it
/// to pubspec.yaml.
const featurePackages = {
  'collection',
  'flutter',
  'flutter_localizations',
  'flutter_riverpod',
  'freezed_annotation',
  'go_router',
  'intl',
  'json_annotation',
  'meta',
  'riverpod',
  'riverpod_annotation',
};

/// The packages [pubspec] (the text of a pubspec.yaml) lists under
/// `dev_dependencies` and not under `dependencies`. Read line by line, as
/// pub writes the file: top-level keys at column 0, packages two spaces in.
Set<String> devOnlyPackages(String pubspec) {
  final sections = <String, Set<String>>{};
  Set<String>? current;
  for (final line in pubspec.split('\n')) {
    final top = RegExp(r'^([A-Za-z_]\w*)\s*:').firstMatch(line);
    if (top != null) {
      current = sections.putIfAbsent(top[1]!, () => {});
      continue;
    }
    final entry = RegExp(r'^  ([a-z0-9_]+)\s*:').firstMatch(line);
    if (entry != null) current?.add(entry[1]!);
  }
  return (sections['dev_dependencies'] ?? {}).difference(
    sections['dependencies'] ?? {},
  );
}

final _suppression = RegExp(
  r'//\s*ignore(?:_for_file)?\s*:[^\n]*\bdepend_on_referenced_packages\b',
);

/// The layers of architecture §3 and §4, plus the app shell of assumption
/// A3, and `stray` for a file outside all of them.
enum LayerKind {
  /// `main.dart` and `app/bootstrap.dart`: wire ports to their
  /// implementations, so they may import anything.
  root,

  /// `app/router.dart`: the go_router configuration, which names features.
  router,

  /// Other files directly in `app/` (the app widget, error handlers).
  shell,
  services,
  theme,
  l10n,
  core,
  domain,
  data,
  feature,
  stray,
}

/// A file's layer; [feature] names the folder under `features/`.
typedef Layer = ({LayerKind kind, String? feature});

/// The layer of [path], relative to the lint root, with `/` separators.
Layer layerOf(String path) {
  final parts = path.split('/');
  Layer of(LayerKind kind) => (kind: kind, feature: null);
  if (path == 'main.dart' || path == 'app/bootstrap.dart') {
    return of(LayerKind.root);
  }
  if (path == 'app/router.dart') return of(LayerKind.router);
  switch (parts.first) {
    case 'app' when parts.length == 2:
      return of(LayerKind.shell);
    case 'app':
      return switch (parts[1]) {
        'services' => of(LayerKind.services),
        'theme' => of(LayerKind.theme),
        'l10n' => of(LayerKind.l10n),
        _ => of(LayerKind.stray),
      };
    case 'core':
      return of(LayerKind.core);
    case 'domain':
      return of(LayerKind.domain);
    case 'data':
      return of(LayerKind.data);
    case 'features' when parts.length > 2:
      return (kind: LayerKind.feature, feature: parts[1]);
  }
  return of(LayerKind.stray);
}

/// One finding: where, what (an import URI, a call or the file itself) and
/// which rule of [layeringRules] it breaks.
class LayeringViolation {
  const LayeringViolation(
    this.file,
    this.line,
    this.what,
    this.rule, {
    this.directive,
  });

  final String file;
  final int line;
  final String what;
  final String rule;

  /// `import` or `export` when [what] is a URI.
  final String? directive;

  @override
  String toString() {
    final subject = directive == null ? what : "$directive '$what'";
    return '$file:$line: $subject breaks $rule: ${layeringRules[rule]}';
  }
}

/// The `.dart` files under [root], relative to it, sorted.
List<String> dartFilesUnder(String root) {
  final prefix = Directory(root).absolute.path.length + 1;
  return [
    for (final entity in Directory(root).listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        entity.absolute.path.substring(prefix).replaceAll(r'\', '/'),
  ]..sort();
}

/// Every violation in the `.dart` files under [root]; [devOnly] names the
/// packages no file may import ([devOnlyPackages]); [config] holds the
/// package name, the allowlists and the exemptions.
List<LayeringViolation> checkLayering(
  String root, {
  Set<String> devOnly = const {},
  LayeringConfig config = LayeringConfig.relay,
}) {
  final base = root.endsWith('/') ? root.substring(0, root.length - 1) : root;
  return [
    for (final path in dartFilesUnder(base))
      ...checkSource(
        path,
        File('$base/$path').readAsStringSync(),
        root: base,
        devOnly: devOnly,
        config: config,
      ),
  ];
}

/// Every violation in [source], the file at [path] relative to the lint
/// root. Findings name the file as `<root>/<path>`.
List<LayeringViolation> checkSource(
  String path,
  String source, {
  String root = '',
  Set<String> devOnly = const {},
  LayeringConfig config = LayeringConfig.relay,
}) {
  final file = root.isEmpty ? path : '$root/$path';
  final layer = layerOf(path);
  final disabled = config.disabledRules;
  if (layer.kind == LayerKind.stray) {
    return [
      if (!disabled.contains('placement'))
        LayeringViolation(file, 1, path, 'placement'),
    ];
  }
  final code = blankSource(source, strings: false);
  final withStrings = blankSource(source, strings: true);
  final found = <(int, LayeringViolation)>[];

  for (final match in _directive.allMatches(code)) {
    final keyword = match[1]!;
    final offset = match.start + match[0]!.indexOf(keyword);
    final text = withStrings.substring(match.start, match.end);
    for (final uri in _quoted.allMatches(text)) {
      final rule = _importRule(path, layer, uri[2]!, devOnly, config);
      if (rule == null) continue;
      final line = _lineAt(source, offset);
      found.add((
        offset,
        LayeringViolation(file, line, uri[2]!, rule, directive: keyword),
      ));
    }
  }

  for (final match in _suppression.allMatches(source)) {
    found.add((
      match.start,
      LayeringViolation(
        file,
        _lineAt(source, match.start),
        'depend_on_referenced_packages',
        'lint-suppression',
      ),
    ));
  }

  if (layer.kind == LayerKind.domain || layer.kind == LayerKind.core) {
    for (final (pattern, name) in _forbiddenCalls) {
      for (final match in pattern.allMatches(code)) {
        final line = _lineAt(source, match.start);
        final text = match[0]!.replaceAll(RegExp(r'\s'), '');
        final what = name ?? (text.endsWith('(') ? '$text)' : text);
        found.add((
          match.start,
          LayeringViolation(file, line, what, 'pure-calls'),
        ));
      }
    }
  }

  if (!config.colourLiteralExempt.any(path.startsWith) && !_isGenerated(path)) {
    for (final (pattern, name) in _colourLiterals) {
      for (final match in pattern.allMatches(code)) {
        found.add((
          match.start,
          LayeringViolation(
            file,
            _lineAt(source, match.start),
            name ?? match[0]!.replaceAll(RegExp(r'\s'), ''),
            'colour-literals',
          ),
        ));
      }
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final (_, violation) in found)
      if (!disabled.contains(violation.rule)) violation,
  ];
}

/// Generated code (D-089) is the generator's, not a widget's: exempt from
/// `colour-literals`.
bool _isGenerated(String path) =>
    path.endsWith('.g.dart') || path.endsWith('.freezed.dart');

/// The colour literals `colour-literals` finds in code (comments and
/// strings blanked): the `Color` constructors and the `Colors` palette. A
/// `Color` type, `ColoredBox` or `MyColors.x` is not one. A finding names
/// the constructor, or the matched `Colors.<name>`.
final _colourLiterals = <(RegExp, String?)>[
  (RegExp(r'\bColor\s*\('), 'Color(…)'),
  (RegExp(r'\bColor\s*\.\s*fromARGB\s*\('), 'Color.fromARGB(…)'),
  (RegExp(r'\bColor\s*\.\s*fromRGBO\s*\('), 'Color.fromRGBO(…)'),
  (RegExp(r'\bColor\s*\.\s*from\s*\('), 'Color.from(…)'),
  (RegExp(r'\bColors\s*\.\s*\w+'), null),
];

final _directive = RegExp(r'^[ \t]*(import|export)\b[^;]*;', multiLine: true);
final _quoted = RegExp(r'''(['"])(.*?)\1''');

final _forbiddenCalls = <(RegExp, String?)>[
  (RegExp(r'\bDateTime\s*\.\s*now\s*\('), 'DateTime.now()'),
  (RegExp(r'\bDateTime\s*\.\s*timestamp\s*\('), 'DateTime.timestamp()'),
  (RegExp(r'\bRandom\s*\.\s*secure\s*\('), 'Random.secure()'),
  (RegExp(r'\bRandom\s*\('), 'Random()'),
  (RegExp(r'\bUuid\s*\('), 'Uuid()'),
  // The clock and time packages are on the domain allowlist (D-043 addendum), but not
  // as a source of time: the clock package's global `clock` and its system
  // `Clock()` (the port is an interface, never constructed), and the time
  // package's getters that read it. A finding names the matched text.
  (
    RegExp(
      r'\bclock\s*\.\s*(?:now|agoBy|fromNowBy|ago|fromNow|\w+Ago|\w+FromNow|'
      r'stopwatch|getStopwatch)\s*\(',
    ),
    null,
  ),
  (RegExp(r'\bClock\s*\('), 'Clock()'),
  (
    RegExp(r'\.\s*(?:fromNow|ago|isToday|isTomorrow|wasYesterday)\b(?!\s*\()'),
    null,
  ),
];

/// The relative [uri] resolved against the file at [path], or null when it
/// leaves the lint root.
String? _resolve(String path, String uri) {
  final parts = path.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else if (part != '.' && part.isNotEmpty) {
      parts.add(part);
    }
  }
  return parts.join('/');
}

int _lineAt(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

/// The rule [uri], imported by the file at [path] in [layer], breaks, or
/// null. A package of [LayeringConfig.sharedPackages] is imported as the
/// layer [sharedPackageLayers] gives it (D-APK-002).
String? _importRule(
  String path,
  Layer layer,
  String uri,
  Set<String> devOnly,
  LayeringConfig config,
) {
  final kind = layer.kind;
  final pure = kind == LayerKind.domain || kind == LayerKind.core;
  final pureRule = kind == LayerKind.domain ? 'domain-imports' : 'core-imports';

  if (uri.startsWith('dart:')) {
    if (!pure) return null;
    return pureDartLibraries.contains(uri.substring(5)) ? null : pureRule;
  }
  final Layer to;
  if (uri.startsWith('package:')) {
    final slash = uri.indexOf('/');
    final package = uri.substring(8, slash < 0 ? uri.length : slash);
    final shared = config.sharedPackages.contains(package)
        ? sharedPackageLayers[package]
        : null;
    if (shared != null) {
      to = (kind: shared, feature: null);
    } else if (package != config.package) {
      if (pure) {
        return config.domainPackages.contains(package) ? null : pureRule;
      }
      if (devOnly.contains(package)) return 'dev-packages';
      if (kind == LayerKind.feature) {
        return config.featurePackages.contains(package)
            ? null
            : 'feature-packages';
      }
      return null;
    } else {
      to = layerOf(uri.substring(slash + 1));
    }
  } else {
    final resolved = uri.contains(':') ? null : _resolve(path, uri);
    if (resolved == null) return 'placement';
    to = layerOf(resolved);
  }

  bool inside(Set<LayerKind> kinds) => kinds.contains(to.kind);
  return switch (kind) {
    LayerKind.domain =>
      inside({LayerKind.core, LayerKind.domain}) ? null : pureRule,
    LayerKind.core => inside({LayerKind.core}) ? null : pureRule,
    LayerKind.data =>
      inside({LayerKind.core, LayerKind.domain, LayerKind.data})
          ? null
          : 'data-imports',
    LayerKind.services =>
      inside({
            LayerKind.core,
            LayerKind.domain,
            LayerKind.data,
            LayerKind.services,
          })
          ? null
          : 'services-imports',
    LayerKind.theme =>
      inside({LayerKind.core, LayerKind.theme, LayerKind.l10n})
          ? null
          : 'theme-l10n-imports',
    LayerKind.l10n =>
      inside({
            LayerKind.core,
            LayerKind.domain,
            LayerKind.theme,
            LayerKind.l10n,
          })
          ? null
          : 'theme-l10n-imports',
    LayerKind.root => null,
    LayerKind.router => inside({LayerKind.data}) ? 'app-imports' : null,
    LayerKind.shell =>
      inside({LayerKind.data, LayerKind.feature}) ? 'app-imports' : null,
    LayerKind.feature when to.kind == LayerKind.feature =>
      to.feature == layer.feature ? null : 'cross-feature',
    LayerKind.feature =>
      inside({
            LayerKind.core,
            LayerKind.domain,
            LayerKind.services,
            LayerKind.theme,
            LayerKind.l10n,
          })
          ? null
          : 'feature-imports',
    LayerKind.stray => 'placement',
  };
}

/// [source] with comments replaced by spaces and, unless [strings], string
/// literals too; expressions interpolated with `${…}` are kept as code.
/// Offsets and line breaks are preserved.
String blankSource(String source, {required bool strings}) {
  final out = source.codeUnits.toList();
  final n = source.length;
  const newline = 0x0A;
  const space = 0x20;

  void wipe(int from, int to) {
    for (var k = from; k < to && k < n; k++) {
      if (out[k] != newline) out[k] = space;
    }
  }

  bool isIdentifier(int at) =>
      at >= 0 && RegExp(r'[A-Za-z0-9_$]').hasMatch(source[at]);

  int blockCommentEnd(int start) {
    var depth = 0;
    var i = start;
    while (i < n) {
      if (source.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (source.startsWith('*/', i)) {
        depth--;
        i += 2;
        if (depth == 0) return i;
      } else {
        i++;
      }
    }
    return n;
  }

  late int Function(int, {required bool raw}) literal;

  // Scans code from [start]; when [nested], stops after the `}` closing an
  // interpolation and returns the index after it.
  int code(int start, {required bool nested}) {
    var depth = 0;
    var i = start;
    while (i < n) {
      final c = source[i];
      if (source.startsWith('//', i)) {
        final end = source.indexOf('\n', i);
        final stop = end < 0 ? n : end;
        wipe(i, stop);
        i = stop;
      } else if (source.startsWith('/*', i)) {
        final end = blockCommentEnd(i);
        wipe(i, end);
        i = end;
      } else if (c == "'" || c == '"') {
        i = literal(i, raw: false);
      } else if ((c == 'r' || c == 'R') &&
          i + 1 < n &&
          (source[i + 1] == "'" || source[i + 1] == '"') &&
          !isIdentifier(i - 1)) {
        i = literal(i + 1, raw: true);
      } else {
        if (c == '{') depth++;
        if (c == '}') {
          if (nested && depth == 0) return i + 1;
          depth--;
        }
        i++;
      }
    }
    return n;
  }

  literal = (int start, {required bool raw}) {
    final quote = source[start];
    final triple = source.startsWith(quote * 3, start);
    final delimiter = triple ? quote * 3 : quote;
    var segment = start;
    var i = start + delimiter.length;
    while (i < n) {
      if (!raw && source[i] == r'\') {
        i += 2;
      } else if (source.startsWith(delimiter, i)) {
        i += delimiter.length;
        if (!strings) wipe(segment, i);
        return i;
      } else if (!triple && source[i] == '\n') {
        break; // unterminated: stop at the line end
      } else if (!raw && source.startsWith(r'${', i)) {
        if (!strings) wipe(segment, i + 2);
        i = code(i + 2, nested: true);
        segment = i - 1;
      } else {
        i++;
      }
    }
    if (!strings) wipe(segment, i);
    return i;
  };

  code(0, nested: false);
  return String.fromCharCodes(out);
}

const _usage =
    'usage: dart run apsira_tools:layering_lint [--config <file>] '
    '[--root <dir>] [--pubspec <file>]';

/// Runs the lint with command-line [args]; returns the exit code.
Future<int> runLayeringLint(List<String> args, {StringSink? out}) async {
  final sink = out ?? stdout;
  String? root;
  var pubspec = 'pubspec.yaml';
  var configPath = defaultConfigPath;
  for (var i = 0; i < args.length; i += 2) {
    if (i + 1 >= args.length) {
      sink.writeln(_usage);
      return 2;
    }
    switch (args[i]) {
      case '--config':
        configPath = args[i + 1];
      case '--root':
        root = args[i + 1];
      case '--pubspec':
        pubspec = args[i + 1];
      default:
        sink.writeln(_usage);
        return 2;
    }
  }
  final LayeringConfig config;
  try {
    config = ApsiraToolsConfig.load(
      path: configPath,
      pubspec: pubspec,
    ).layering;
  } on FormatException catch (e) {
    sink.writeln('layering: ${e.message}');
    return 2;
  }
  root ??= config.root;
  if (!Directory(root).existsSync()) {
    sink.writeln('layering: no such directory: $root');
    return 2;
  }
  if (!File(pubspec).existsSync()) {
    sink.writeln('layering: no such file: $pubspec');
    return 2;
  }
  final violations = checkLayering(
    root,
    devOnly: devOnlyPackages(File(pubspec).readAsStringSync()),
    config: config,
  );
  for (final violation in violations) {
    sink.writeln('layering: $violation');
  }
  if (violations.isNotEmpty) {
    sink.writeln(
      'layering: ${violations.length} violation(s); see architecture §3',
    );
    return 1;
  }
  sink.writeln(
    'layering: $root clean (${dartFilesUnder(root).length} files, '
    '${layeringRules.length} rules)',
  );
  return 0;
}
