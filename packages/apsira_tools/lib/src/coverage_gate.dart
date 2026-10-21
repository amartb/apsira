// From relay tool/coverage_gate.dart @ 5f606e9
// Domain coverage gate (08 §5, 07 P0-03): the domain layer must keep
// at least 90 % line and 85 % branch coverage, and every domain file must
// appear in the report. The other layers are reported, never gated.
//
// Usage (run from the package root):
//
//     dart run apsira_tools:coverage_gate [--config <file>]
//         [--run <test dir>] [--lcov <file>] [--root .] [--min-lines 90]
//         [--min-branches 85]
//
// `--config` (default tool/apsira_tools.yaml, D-APK-002) gives the defaults
// of `--run` (`coverage.run`; none in RELAY), `--min-lines` and
// `--min-branches` (`coverage.min_lines`, `coverage.min_branches`); a flag
// on the command line wins.
//
// With --run (the `coverage` gate of .army.toml: `--run test/domain`), the
// gate first runs `flutter test --coverage --branch-coverage` on that
// directory, in --root, into a report of its own
// (coverage/coverage_gate.lcov.info unless --lcov names one), deleting any
// earlier report first; a failed test run or a missing directory fails the
// gate. Without --run it reads a report already written by
// `flutter test --coverage --branch-coverage` (default coverage/lcov.info).
//
// --root is the package whose lib/domain/ is listed (default: the working
// directory); --lcov is relative to the working directory.
//
// Domain code is every `.dart` file under lib/domain/ on disk, plus every
// lib/domain/ entry in the report; generated files (`*.g.dart`,
// `*.freezed.dart`) are left out of both. So is an export-only library on
// disk (a barrel such as lib/domain/query/syntax/power_syntax.dart: only
// comments, `library` and at least one `export` directive): it has no
// executable line, so lcov never lists it however many tests import it,
// and the gate names it in a notice instead of failing it as missing. With
// no domain code yet the gate passes with a notice.
//
// Exit codes, the same in both modes: 0 when the gate passes; 1 when
// coverage is below a threshold, a domain file is missing from the report,
// the report is missing while domain code exists, or (--run) the test
// directory is missing or its tests fail; 2 on a usage error.
import 'dart:io';

import 'config.dart';

const domainDir = 'lib/domain/';
const defaultMinLines = 90.0;
const defaultMinBranches = 85.0;

/// The report --run writes when --lcov names none: its own file, so a
/// gate run never overwrites a coverage/lcov.info made by hand.
const runReport = 'coverage_gate.lcov.info';

const _generatedSuffixes = ['.g.dart', '.freezed.dart'];

/// Line and branch counts for one source file of an lcov report.
class FileCoverage {
  const FileCoverage({
    required this.linesFound,
    required this.linesHit,
    required this.branchesFound,
    required this.branchesHit,
  });

  final int linesFound;
  final int linesHit;
  final int branchesFound;
  final int branchesHit;
}

/// The gate's decision and the lines it prints.
class GateResult {
  const GateResult(this.passed, this.messages);

  final bool passed;
  final List<String> messages;
}

/// Runs `flutter` with [arguments] in [workingDirectory] and returns its
/// exit code; the tests pass a fake.
typedef TestRunner = Future<int> Function(
  List<String> arguments,
  String workingDirectory,
);

Future<int> _flutter(List<String> arguments, String workingDirectory) async {
  final process = await Process.start(
    'flutter',
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}

/// A usage error on the command line.
class UsageError implements Exception {
  const UsageError(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Record {
  final lines = <int, int>{};
  final branches = <String, int>{};
  int? lf, lh, brf, brh;
}

/// Parses an lcov report into coverage per source file, keyed by path
/// relative to [root] with `/` separators. Repeated records of a file are
/// merged; the `DA`/`BRDA` details win over the `LF`/`LH`/`BRF`/`BRH`
/// summaries, which are used only when a record has no details.
Map<String, FileCoverage> parseLcov(String content, {String? root}) {
  final records = <String, _Record>{};
  _Record? current;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    final colon = line.indexOf(':');
    final tag = colon < 0 ? line : line.substring(0, colon);
    final value = colon < 0 ? '' : line.substring(colon + 1);
    switch (tag) {
      case 'SF':
        current = records.putIfAbsent(_relative(value, root), _Record.new);
      case 'DA':
        final parts = value.split(',');
        final number = int.tryParse(parts[0]);
        final hits = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (current != null && number != null && hits != null) {
          final previous = current.lines[number] ?? 0;
          current.lines[number] = hits > previous ? hits : previous;
        }
      case 'BRDA':
        final parts = value.split(',');
        if (current != null && parts.length == 4) {
          final key = parts.take(3).join(',');
          final taken = int.tryParse(parts[3]) ?? 0; // '-': never reached
          final previous = current.branches[key] ?? 0;
          current.branches[key] = taken > previous ? taken : previous;
        }
      case 'LF':
        current?.lf = int.tryParse(value);
      case 'LH':
        current?.lh = int.tryParse(value);
      case 'BRF':
        current?.brf = int.tryParse(value);
      case 'BRH':
        current?.brh = int.tryParse(value);
      case 'end_of_record':
        current = null;
    }
  }
  return {
    for (final MapEntry(:key, value: r) in records.entries)
      key: FileCoverage(
        linesFound: r.lines.isNotEmpty ? r.lines.length : r.lf ?? 0,
        linesHit: r.lines.isNotEmpty
            ? r.lines.values.where((hits) => hits > 0).length
            : r.lh ?? 0,
        branchesFound: r.branches.isNotEmpty ? r.branches.length : r.brf ?? 0,
        branchesHit: r.branches.isNotEmpty
            ? r.branches.values.where((taken) => taken > 0).length
            : r.brh ?? 0,
      ),
  };
}

String _relative(String path, String? root) {
  var result = path.replaceAll(r'\', '/');
  if (root != null) {
    var prefix = root.replaceAll(r'\', '/');
    if (!prefix.endsWith('/')) prefix = '$prefix/';
    if (result.startsWith(prefix)) result = result.substring(prefix.length);
  }
  return result.startsWith('./') ? result.substring(2) : result;
}

bool _isDomainSource(String path) =>
    path.startsWith(domainDir) &&
    path.endsWith('.dart') &&
    !_generatedSuffixes.any(path.endsWith);

final _blockComment = RegExp(r'/\*[\s\S]*?\*/');
final _lineComment = RegExp(r'//[^\n]*');
final _exportDirective = RegExp(r'^export\b');
final _libraryDirective = RegExp(r'^library\b');

/// Whether [source] is an export-only library (a barrel): nothing but
/// comments, `library` directives and at least one `export` directive. It
/// has no executable line, so there is nothing in it to cover. Anything
/// else (an import, an annotation, a declaration) makes it code.
bool isExportOnlyLibrary(String source) {
  final code = source
      .replaceAll(_blockComment, ' ')
      .replaceAll(_lineComment, ' ');
  var exports = 0;
  for (final raw in code.split(';')) {
    final statement = raw.trim();
    if (statement.isEmpty) continue;
    if (_exportDirective.hasMatch(statement)) {
      exports++;
    } else if (!_libraryDirective.hasMatch(statement)) {
      return false;
    }
  }
  return exports > 0;
}

/// Every hand-written `.dart` file under lib/domain/ in [root], relative
/// and `/`-separated, sorted, split into the files with code and the
/// export-only libraries.
({List<String> code, List<String> exportOnly}) _domainSources(String root) {
  final dir = Directory('$root/$domainDir');
  final code = <String>[], exportOnly = <String>[];
  if (!dir.existsSync()) return (code: code, exportOnly: exportOnly);
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = _relative(entity.path, root);
    if (!_isDomainSource(path)) continue;
    (isExportOnlyLibrary(entity.readAsStringSync()) ? exportOnly : code).add(
      path,
    );
  }
  return (code: code..sort(), exportOnly: exportOnly..sort());
}

/// Every hand-written `.dart` file under lib/domain/ in [root] that has
/// code to cover (export-only libraries are left out), relative and
/// `/`-separated, sorted.
List<String> listDomainFiles(String root) => _domainSources(root).code;

String _percent(int hit, int found) =>
    (found == 0 ? 100.0 : hit * 100 / found).toStringAsFixed(1);

/// Applies the gate to [report] for the domain files on disk.
GateResult evaluateDomainCoverage({
  required Map<String, FileCoverage> report,
  required List<String> domainFiles,
  double minLines = defaultMinLines,
  double minBranches = defaultMinBranches,
}) {
  final reported = {
    for (final MapEntry(:key, :value) in report.entries)
      if (_isDomainSource(key)) key: value,
  };
  final onDisk = domainFiles.where(_isDomainSource).toSet();
  if (reported.isEmpty && onDisk.isEmpty) {
    return const GateResult(true, [
      'coverage_gate: notice: no domain code yet; the domain gate passes',
    ]);
  }

  final messages = <String>[];
  var passed = true;
  final missing = onDisk.difference(reported.keys.toSet()).toList()..sort();
  for (final file in missing) {
    passed = false;
    messages.add(
      'coverage_gate: FAIL: domain file missing: $file '
      '(no test loads it; every domain file needs coverage)',
    );
  }

  var lf = 0, lh = 0, brf = 0, brh = 0;
  for (final file in reported.values) {
    lf += file.linesFound;
    lh += file.linesHit;
    brf += file.branchesFound;
    brh += file.branchesHit;
  }
  final lines = lf == 0 ? 100.0 : lh * 100 / lf;
  final branches = brf == 0 ? 100.0 : brh * 100 / brf;
  final min = (minLines.toStringAsFixed(0), minBranches.toStringAsFixed(0));
  final summary =
      '${_percent(lh, lf)}% lines ($lh/$lf), '
      '${_percent(brh, brf)}% branches ($brh/$brf) '
      'over ${reported.length} domain files';
  if (lines < minLines) {
    passed = false;
    messages.add(
      'coverage_gate: FAIL: domain ${_percent(lh, lf)}% lines < ${min.$1}%',
    );
  }
  if (branches < minBranches) {
    passed = false;
    messages.add(
      'coverage_gate: FAIL: domain ${_percent(brh, brf)}% branches '
      '< ${min.$2}%',
    );
  }
  if (brf == 0 && lf > 0) {
    messages.add(
      'coverage_gate: notice: no branch data; '
      'run flutter test with --branch-coverage',
    );
  }
  messages.add(
    'coverage_gate: ${passed ? 'pass' : 'FAIL'}: $summary '
    '(minimum ${min.$1}% lines, ${min.$2}% branches)',
  );
  return GateResult(passed, messages);
}

/// Runs the gate as the command line does and returns the exit code;
/// [runTests] runs `flutter` for --run (the real one by default).
Future<int> runCoverageGate(
  List<String> args, {
  StringSink? out,
  TestRunner? runTests,
}) async {
  final sink = out ?? stdout;
  try {
    final options = _parseArgs(args);
    final root = options['--root']!;
    final testDir = options['--run'];
    final lcovPath =
        options['--lcov'] ??
        (testDir == null ? 'coverage/lcov.info' : 'coverage/$runReport');
    final lcov = File(lcovPath); // relative to the working directory
    if (testDir != null) {
      if (!Directory('$root/$testDir').existsSync()) {
        sink.writeln(
          'coverage_gate: FAIL: no test directory $testDir in $root',
        );
        return 1;
      }
      if (lcov.existsSync()) lcov.deleteSync(); // a stale report never passes
      final code = await (runTests ?? _flutter)([
        'test',
        '--coverage',
        '--branch-coverage',
        '--coverage-path',
        lcov.absolute.path,
        testDir,
      ], root);
      if (code != 0) {
        sink.writeln('coverage_gate: FAIL: flutter test $testDir exited $code');
        return 1;
      }
    }
    final (code: domainFiles, :exportOnly) = _domainSources(root);
    for (final file in exportOnly) {
      sink.writeln(
        'coverage_gate: notice: export-only library, nothing to cover: $file',
      );
    }
    final source = lcov.existsSync() ? lcov : null;
    if (source == null && domainFiles.isNotEmpty) {
      sink.writeln(
        'coverage_gate: FAIL: no coverage report at $lcovPath; '
        'run flutter test --coverage --branch-coverage first',
      );
      return 1;
    }
    final result = evaluateDomainCoverage(
      report: source == null
          ? const {}
          : parseLcov(
              await source.readAsString(),
              root: Directory(root).absolute.path,
            ),
      domainFiles: domainFiles,
      minLines: _number(options, '--min-lines'),
      minBranches: _number(options, '--min-branches'),
    );
    result.messages.forEach(sink.writeln);
    return result.passed ? 0 : 1;
  } on UsageError catch (e) {
    sink
      ..writeln('coverage_gate: $e')
      ..writeln(
        'usage: dart run apsira_tools:coverage_gate [--config <file>] '
        '[--run <test dir>] [--lcov <file>] [--root <dir>] [--min-lines <n>] '
        '[--min-branches <n>]',
      );
    return 2;
  }
}

/// The options of [args] over the defaults the `--config` file gives.
Map<String, String?> _parseArgs(List<String> args) {
  final given = <String, String?>{};
  const known = {
    '--config',
    '--run',
    '--lcov',
    '--root',
    '--min-lines',
    '--min-branches',
  };
  for (var i = 0; i < args.length; i += 2) {
    final name = args[i];
    if (!known.contains(name)) throw UsageError('unknown option $name');
    if (i + 1 >= args.length) throw UsageError('$name needs a value');
    given[name] = args[i + 1];
  }
  final CoverageConfig config;
  try {
    config = ApsiraToolsConfig.load(
      path: given['--config'] ?? defaultConfigPath,
    ).coverage;
  } on FormatException catch (e) {
    throw UsageError(e.message);
  }
  return {
    '--run': config.run,
    '--lcov': null,
    '--root': '.',
    '--min-lines': '${config.minLines}',
    '--min-branches': '${config.minBranches}',
    ...given,
  };
}

double _number(Map<String, String?> options, String name) {
  final value = double.tryParse(options[name]!);
  if (value == null || value < 0 || value > 100) {
    throw UsageError('$name must be a percentage, not "${options[name]}"');
  }
  return value;
}
