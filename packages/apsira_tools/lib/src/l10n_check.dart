// From relay tool/l10n_check.dart @ 5f606e9
// The l10n check (07 P0-07, D-030, 08 §3 `l10n_complete`): fails when a key
// is missing from either language, when a key's placeholders differ between
// the languages, or when a `Text(` in `lib/` is given a string literal.
//
//   dart run apsira_tools:l10n_check [--config <file>]
//       [--l10n-config <l10n.yaml>] [--arb-dir <dir>] [--source-dir <dir>]
//
// `--l10n-config` (RELAY's `--config`, renamed by P-5) defaults to
// `l10n.config` of the tools file, lib/app/l10n/l10n.yaml, which gives the
// ARB directory and the template file. `--config` (default
// tool/apsira_tools.yaml, D-APK-002) also gives the required locales and
// the scan exemptions. `--arb-dir` and `--source-dir` (default `lib`) point
// the check at other inputs, such as test/fixtures/l10n/.
// Exit 0 when clean, 1 naming each file and key at fault, 2 on bad usage or
// when the gen-l10n file is absent (`l10n_check: no l10n config at <path>`).
//
// The source scan is the whole of the hard-coded-string guard for now (08 §3):
// it flags a string literal passed straight to `Text(`, outside generated
// code and the dev-only ThemePreview screen. An analyzer rule
// covering tooltips, labels and other parameters is deferred.
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'config.dart';

/// The languages every key must exist in (D-030).
const requiredLocales = ['en', 'es'];

/// Source paths the scan skips, relative to the scanned directory: generated
/// localisations; the dev-only ThemePreview screen, whose labels are token
/// names, not user-facing text (it never ships in prod).
const scanExemptions = ['app/l10n/generated/', 'features/theme_preview/'];

/// The calls `l10n.text_calls` may name (v0.2): `Text(` and
/// `SelectableText(` by their first argument, `TextSpan` by its `text:`
/// (the spans of `Text.rich` and `SelectableText.rich`). RELAY scans `Text(`
/// only; VIATICUM all three.
const textCallNames = ['Text', 'SelectableText', 'TextSpan'];

/// How a finding names each of [textCallNames].
const _callee = {
  'Text': 'Text(',
  'SelectableText': 'SelectableText(',
  'TextSpan': 'TextSpan(text:',
};

/// One finding: the file at fault, the key (or source line) and why.
class L10nProblem {
  const L10nProblem(this.file, this.message, {this.key, this.line});

  final String file;
  final String? key;
  final int? line;
  final String message;

  @override
  String toString() {
    final where = [file, if (line != null) '$line'].join(':');
    return key == null ? '$where: $message' : "$where: '$key' $message";
  }
}

/// The ARB directory and template file named by a gen-l10n config.
({String arbDir, String template}) readConfig(String path) {
  final yaml = loadYaml(File(path).readAsStringSync());
  if (yaml is! YamlMap) throw FormatException('$path is not a YAML map');
  return (
    arbDir: '${yaml['arb-dir'] ?? 'lib/l10n'}',
    template: '${yaml['template-arb-file'] ?? 'app_en.arb'}',
  );
}

/// The placeholder names an ICU message refers to: `{name}`, and the
/// argument of `{name, plural|select|selectordinal, …}`, at any depth.
/// Throws [FormatException] on unbalanced braces or a malformed argument.
Set<String> placeholdersIn(String message) {
  final names = <String>{};
  var i = 0;

  void skipSpace() {
    while (i < message.length && message[i].trim().isEmpty) {
      i++;
    }
  }

  String word(String what) {
    final start = i;
    while (i < message.length && !' \t\r\n{},'.contains(message[i])) {
      i++;
    }
    if (i == start) throw FormatException('expected $what at $start');
    return message.substring(start, i);
  }

  void expect(String char) {
    if (i >= message.length || message[i] != char) {
      throw FormatException("expected '$char' at $i");
    }
    i++;
  }

  late void Function({required bool nested}) text;

  // At a '{': one argument, up to and including its '}'.
  void argument() {
    expect('{');
    skipSpace();
    names.add(word('a placeholder name'));
    skipSpace();
    if (i < message.length && message[i] == ',') {
      i++;
      skipSpace();
      final type = word('an argument type');
      skipSpace();
      if (i < message.length && message[i] == ',') {
        i++;
        if (const ['plural', 'select', 'selectordinal'].contains(type)) {
          for (skipSpace(); i < message.length && message[i] != '}';) {
            word('a case selector');
            skipSpace();
            expect('{');
            text(nested: true);
            expect('}');
            skipSpace();
          }
        } else {
          while (i < message.length && message[i] != '}') {
            i++;
          }
        }
      }
    }
    expect('}');
  }

  text = ({required bool nested}) {
    while (i < message.length) {
      if (message[i] == '{') {
        argument();
      } else if (message[i] == '}') {
        if (nested) return;
        throw FormatException("unmatched '}' at $i");
      } else {
        i++;
      }
    }
  };

  text(nested: false);
  return names;
}

/// Checks every ARB file in [arbDir] against [template]: each language has
/// every key, no extra keys, and the same placeholders as the template;
/// each of [locales] has a file.
List<L10nProblem> checkArbDir(
  String arbDir, {
  String template = 'app_en.arb',
  List<String> locales = requiredLocales,
}) {
  final problems = <L10nProblem>[];
  final dir = Directory(arbDir);
  if (!dir.existsSync()) return [L10nProblem(arbDir, 'no such directory')];

  final prefix = template.substring(0, template.lastIndexOf('_') + 1);
  final at = arbDir.replaceFirst(RegExp(r'/$'), '');
  final files = <String, Map<String, Object?>>{};
  final found = <String, String>{};
  for (final entity in dir.listSync()) {
    final name = entity.uri.pathSegments.last;
    if (entity is! File || !name.endsWith('.arb')) continue;
    try {
      final content = jsonDecode(entity.readAsStringSync());
      if (content is! Map<String, Object?>) {
        problems.add(L10nProblem('$at/$name', 'is not a JSON object'));
        continue;
      }
      files[name] = content;
      found[name] =
          '${content['@@locale'] ?? name.substring(prefix.length, name.length - 4)}';
    } on FormatException catch (e) {
      problems.add(L10nProblem('$at/$name', 'is not valid JSON: ${e.message}'));
    }
  }
  final needed = locales.map((l) => l.toUpperCase()).join(' and ');
  for (final locale in locales) {
    if (!found.containsValue(locale)) {
      problems.add(
        L10nProblem(
          '$at/$prefix$locale.arb',
          'is missing (D-030 needs $needed)',
        ),
      );
    }
  }
  final base = files[template];
  if (base == null) return problems;

  Set<String>? placeholders(String file, String key) {
    final message = files[file]![key];
    if (message is! String) {
      problems.add(L10nProblem('$at/$file', 'is not a string', key: key));
      return null;
    }
    final meta = files[file]!['@$key'];
    final declared = meta is Map && meta['placeholders'] is Map
        ? (meta['placeholders'] as Map).keys.map((k) => '$k')
        : const <String>[];
    try {
      return {...placeholdersIn(message), ...declared};
    } on FormatException catch (e) {
      problems.add(
        L10nProblem('$at/$file', 'is malformed: ${e.message}', key: key),
      );
      return null;
    }
  }

  String show(Set<String> names) => '{${(names.toList()..sort()).join(', ')}}';

  final keys = base.keys.where((k) => !k.startsWith('@')).toList()..sort();
  final expected = {for (final key in keys) key: placeholders(template, key)};
  for (final file in files.keys.toList()..sort()) {
    if (file == template) continue;
    final content = files[file]!;
    for (final key in keys) {
      if (!content.containsKey(key)) {
        problems.add(
          L10nProblem('$at/$file', 'is missing ($template has it)', key: key),
        );
        continue;
      }
      final want = expected[key];
      final have = placeholders(file, key);
      if (want != null &&
          have != null &&
          (want.length != have.length || !want.containsAll(have))) {
        problems.add(
          L10nProblem(
            '$at/$file',
            'has placeholders ${show(have)}, $template has ${show(want)}',
            key: key,
          ),
        );
      }
    }
    for (final key in content.keys) {
      if (!key.startsWith('@') && !base.containsKey(key)) {
        problems.add(L10nProblem('$at/$file', 'is not in $template', key: key));
      }
    }
  }
  return problems;
}

/// Reports every call of [calls] ([textCallNames]; RELAY's `Text(` by
/// default) in the Dart files under [sourceDir] given a string literal with
/// a letter outside its interpolations.
/// Skips `*.g.dart`, `*.freezed.dart` and the [exemptions] (paths relative
/// to [sourceDir]). Comments are ignored.
List<L10nProblem> scanHardCodedText(
  String sourceDir, {
  List<String> exemptions = scanExemptions,
  List<String> calls = const ['Text'],
}) {
  final root = Directory(sourceDir);
  if (!root.existsSync()) return [L10nProblem(sourceDir, 'no such directory')];
  final problems = <L10nProblem>[];
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final relative = file.path
        .substring(root.path.length)
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp('^/'), '');
    if (relative.endsWith('.g.dart') ||
        relative.endsWith('.freezed.dart') ||
        exemptions.any(relative.startsWith)) {
      continue;
    }
    final source = file.readAsStringSync();
    for (final (offset, literal, callee) in textCallLiterals(source, calls)) {
      final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
      problems.add(
        L10nProblem(
          '${root.path.replaceFirst(RegExp(r'/$'), '')}/$relative',
          'passes $literal to $callee: use AppLocalizations (D-030)',
          line: line,
        ),
      );
    }
  }
  return problems;
}

final _letter = RegExp(r'\p{L}', unicode: true);
final _interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*');
final _textCall = RegExp(r'(?<![A-Za-z0-9_$])(Selectable)?Text\s*\(\s*$');
final _spanText = RegExp(r'(?<![A-Za-z0-9_$])text\s*:\s*$');
final _spanCall = RegExp(r'(?<![A-Za-z0-9_$])TextSpan\s*$');

/// The call [code] (comments and strings blanked) is inside at its end:
/// the text before the innermost `(` still open.
String _openCall(String code) {
  var depth = 0;
  for (var j = code.length - 1; j >= 0; j--) {
    final c = code[j];
    if (c == ')' || c == ']' || c == '}') depth++;
    if (c == '(' || c == '[' || c == '{') {
      if (depth == 0) return c == '(' ? code.substring(0, j) : '';
      depth--;
    }
  }
  return '';
}

/// The string literals passed as the first argument of `Text(` in
/// [source], with their offsets, ignoring comments and literals made only
/// of interpolations, digits and punctuation.
List<(int, String)> textLiterals(String source) => [
  for (final (offset, literal, _) in textCallLiterals(source, const ['Text']))
    (offset, literal),
];

/// The string literals given to the calls of [calls] ([textCallNames]) in
/// [source], with their offsets and how the call is named (`Text(`,
/// `SelectableText(`, `TextSpan(text:`), as [textLiterals]. From viaticum
/// tool/l10n_check.dart @ 20f05f6.
List<(int, String, String)> textCallLiterals(
  String source,
  List<String> calls,
) {
  final found = <(int, String, String)>[];
  // Code with comments and string contents blanked out, to find calls in.
  final code = StringBuffer();
  var i = 0;

  // Skips a string literal starting at [start]; returns the index after it.
  int skipString(int start) {
    var j = start;
    final raw = source[j] == 'r' || source[j] == 'R';
    if (raw) j++;
    final quote = source[j];
    final triple = source.startsWith(quote * 3, j);
    final close = triple ? quote * 3 : quote;
    j += close.length;
    while (j < source.length && !source.startsWith(close, j)) {
      if (!raw && source[j] == r'\') {
        j += 2;
      } else if (!raw && source.startsWith(r'${', j)) {
        var depth = 1;
        j += 2;
        while (j < source.length && depth > 0) {
          final c = source[j];
          if (c == '{') depth++;
          if (c == '}') depth--;
          if (c == "'" || c == '"') {
            j = skipString(j);
          } else {
            j++;
          }
        }
      } else if (!triple && source[j] == '\n') {
        break;
      } else {
        j++;
      }
    }
    return (j + close.length).clamp(0, source.length);
  }

  while (i < source.length) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
    } else if (source.startsWith('/*', i)) {
      var depth = 1;
      var j = i + 2;
      while (j < source.length && depth > 0) {
        if (source.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (source.startsWith('*/', j)) {
          depth--;
          j += 2;
        } else {
          j++;
        }
      }
      code.write(source.substring(i, j).replaceAll(RegExp(r'[^\n]'), ' '));
      i = j;
    } else if (c == "'" ||
        c == '"' ||
        ((c == 'r' || c == 'R') &&
            i + 1 < source.length &&
            (source[i + 1] == "'" || source[i + 1] == '"') &&
            (i == 0 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(source[i - 1])))) {
      final end = skipString(i);
      final literal = source.substring(i, end);
      final before = code.toString();
      final tail = before.substring(
        before.length < 80 ? 0 : before.length - 80,
      );
      final call = _textCall.firstMatch(tail);
      final String? name;
      if (call != null) {
        name = call[1] == null ? 'Text' : 'SelectableText';
      } else if (_spanText.hasMatch(tail) &&
          _spanCall.hasMatch(_openCall(before))) {
        name = 'TextSpan';
      } else {
        name = null;
      }
      if (name != null && calls.contains(name)) {
        final text = literal.replaceAll(_interpolation, '');
        if (_letter.hasMatch(text)) found.add((i, literal, _callee[name]!));
      }
      code.write(literal.replaceAll(RegExp(r'[^\n]'), ' '));
      i = end;
    } else {
      code.write(c);
      i++;
    }
  }
  return found;
}

/// Runs the check with command-line [args]; returns the exit code.
Future<int> runL10nCheck(List<String> args, {StringSink? out}) async {
  final sink = out ?? stdout;
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    const known = ['--config', '--l10n-config', '--arb-dir', '--source-dir'];
    if (!known.contains(args[i]) || i + 1 >= args.length) {
      sink.writeln(
        'usage: dart run apsira_tools:l10n_check [--config <file>] '
        '[--l10n-config <l10n.yaml>] [--arb-dir <dir>] [--source-dir <dir>]',
      );
      return 2;
    }
    options[args[i]] = args[++i];
  }
  final L10nConfig tools;
  try {
    tools = ApsiraToolsConfig.load(
      path: options['--config'] ?? defaultConfigPath,
    ).l10n;
  } on FormatException catch (e) {
    sink.writeln('l10n: ${e.message}');
    return 2;
  }
  final configPath = options['--l10n-config'] ?? tools.config;
  if (!File(configPath).existsSync()) {
    sink.writeln('l10n_check: no l10n config at $configPath');
    return 2;
  }
  final config = readConfig(configPath);
  final arbDir = options['--arb-dir'] ?? config.arbDir;
  final sourceDir = options['--source-dir'] ?? 'lib';

  final problems = [
    ...checkArbDir(
      arbDir,
      template: config.template,
      locales: tools.requiredLocales,
    ),
    ...scanHardCodedText(
      sourceDir,
      exemptions: tools.scanExemptions,
      calls: tools.textCalls,
    ),
  ];
  for (final problem in problems) {
    sink.writeln('l10n: $problem');
  }
  if (problems.isNotEmpty) {
    sink.writeln(
      'l10n: ${problems.length} problem(s); see 08 §3 l10n_complete',
    );
    return 1;
  }
  sink.writeln(
    'l10n: $arbDir complete in ${tools.requiredLocales.join(' and ')}; '
    'no string literal passed to ${_callList(tools.textCalls)} in $sourceDir',
  );
  return 0;
}

/// `Text(`, or `Text(, SelectableText( or TextSpan(text:`.
String _callList(List<String> calls) {
  final names = [for (final call in calls) _callee[call]!];
  return names.length < 2
      ? names.join()
      : '${names.take(names.length - 1).join(', ')} or ${names.last}';
}
