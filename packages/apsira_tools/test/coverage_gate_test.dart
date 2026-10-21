// From relay test/tool/coverage_gate_test.dart @ 5f606e9
// Tests the domain coverage gate of 08 §5 (07 P0-03): the domain layer
// fails below 90 % lines or 85 % branches. The lcov reports are the
// hand-written fixtures in test/fixtures/coverage/ (see its README). The
// --run mode (the `coverage` gate of .army.toml, P1-02e) is tested with a
// fake `flutter test` that writes a fixture where it was told to.
// Tests run from the package root.
import 'dart:io';

import 'package:apsira_tools/src/coverage_gate.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/coverage';
const _note = 'lib/domain/notes/note.dart';
const _tag = 'lib/domain/tags/tag.dart';

Map<String, FileCoverage> _report(String name) =>
    parseLcov(File('$_fixtures/$name').readAsStringSync());

GateResult _gate(String name, {List<String> onDisk = const [_note, _tag]}) =>
    evaluateDomainCoverage(report: _report(name), domainFiles: onDisk);

/// An export-only library (a barrel), as lib/domain/query/syntax/
/// power_syntax.dart is: comments, `library;` and `export` directives.
const _barrelSource = '''
/// The notes barrel: one import for the notes domain.
library;

// The note itself.
export 'note.dart' show Note, NoteId;
/* and its tags */
export 'tag.dart'
    hide TagPath;
''';

/// Runs the command line in a scratch package root holding [domainFiles]
/// and the export-only [barrels].
Future<(int, String)> _run(
  List<String> args, {
  List<String> domainFiles = const [],
  List<String> barrels = const [],
}) async {
  final root = Directory.systemTemp.createTempSync('coverage_gate_test');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final file in domainFiles) {
    File('${root.path}/$file')
      ..createSync(recursive: true)
      ..writeAsStringSync('// domain code\n');
  }
  for (final file in barrels) {
    File('${root.path}/$file')
      ..createSync(recursive: true)
      ..writeAsStringSync(_barrelSource);
  }
  final out = StringBuffer();
  final code = await runCoverageGate(['--root', root.path, ...args], out: out);
  return (code, out.toString());
}

/// One call of the fake `flutter test`.
typedef _Call = ({List<String> args, String workingDirectory});

/// A fake `flutter test` that records its calls, writes [fixture] (when
/// given) at the `--coverage-path` it was passed, and exits [exitCode].
TestRunner _fakeFlutter(
  List<_Call> calls, {
  String? fixture,
  int exitCode = 0,
}) {
  return (args, workingDirectory) async {
    calls.add((args: args, workingDirectory: workingDirectory));
    final path = args[args.indexOf('--coverage-path') + 1];
    if (fixture != null) {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(File('$_fixtures/$fixture').readAsStringSync());
    }
    return exitCode;
  };
}

/// The report path of a --run test: inside the scratch root, so a test
/// never writes into the package's coverage/.
String _lcovIn(Directory root) => '${root.path}/coverage/gate.info';

void main() {
  group('parseLcov', () {
    test('counts lines and branches per source file', () {
      final report = _report('domain_below.info');
      expect(report.keys, containsAll(<String>['lib/app/router.dart', _tag]));
      final tag = report[_tag]!;
      expect((tag.linesFound, tag.linesHit), (10, 8));
      expect((tag.branchesFound, tag.branchesHit), (10, 9));
    });

    test('merges repeated records and reads "-" as not taken', () {
      final report = parseLcov(
        'SF:lib/domain/a.dart\nDA:1,0\nDA:2,1\nBRDA:1,0,0,-\nend_of_record\n'
        'SF:lib/domain/a.dart\nDA:1,3\nBRDA:1,0,1,2\nend_of_record\n',
      );
      final a = report['lib/domain/a.dart']!;
      expect((a.linesFound, a.linesHit), (2, 2));
      expect((a.branchesFound, a.branchesHit), (2, 1));
    });

    test('makes absolute paths under the root relative', () {
      final report = parseLcov(
        'SF:/work/relay/lib/domain/a.dart\nDA:1,1\nend_of_record\n',
        root: '/work/relay',
      );
      expect(report.keys, ['lib/domain/a.dart']);
    });

    test('falls back to the LF/LH and BRF/BRH summaries', () {
      final report = parseLcov(
        'SF:lib/domain/a.dart\nLF:4\nLH:3\nBRF:2\nBRH:1\nend_of_record\n',
      );
      final a = report['lib/domain/a.dart']!;
      expect((a.linesFound, a.linesHit), (4, 3));
      expect((a.branchesFound, a.branchesHit), (2, 1));
    });
  });

  group('isExportOnlyLibrary (CP1 F-1)', () {
    test('a barrel of comments, library and export directives is one', () {
      expect(isExportOnlyLibrary(_barrelSource), isTrue);
      expect(isExportOnlyLibrary("export 'a.dart';"), isTrue);
      expect(
        isExportOnlyLibrary("library relay.notes;\nexport 'a.dart';"),
        isTrue,
      );
    });

    test('anything with code, or with no export, is not', () {
      expect(isExportOnlyLibrary(''), isFalse);
      expect(isExportOnlyLibrary('// domain code\n'), isFalse);
      expect(isExportOnlyLibrary('library;\n'), isFalse);
      expect(
        isExportOnlyLibrary("import 'a.dart';\nexport 'a.dart';"),
        isFalse,
      );
      expect(isExportOnlyLibrary("export 'a.dart';\nconst x = 1;"), isFalse);
      expect(isExportOnlyLibrary("export 'a.dart';\nclass A {}\n"), isFalse);
      expect(
        isExportOnlyLibrary("@Deprecated('x')\nlibrary;\nexport 'a.dart';"),
        isFalse,
      );
    });
  });

  group('evaluateDomainCoverage', () {
    test('passes at or above 90 % lines and 85 % branches', () {
      final result = _gate('domain_ok.info');
      expect(result.passed, isTrue, reason: result.messages.join('\n'));
      expect(result.messages.join('\n'), contains('95.0% lines'));
    });

    test('fails below 90 % lines', () {
      final result = _gate('domain_below.info');
      expect(result.passed, isFalse);
      expect(result.messages.join('\n'), contains('85.0% lines < 90%'));
    });

    test('fails below 85 % branches', () {
      final result = _gate('domain_branches_below.info');
      expect(result.passed, isFalse);
      expect(result.messages.join('\n'), contains('80.0% branches < 85%'));
    });

    test('ignores code outside lib/domain/', () {
      // lib/app/router.dart is at 0 % in every fixture.
      expect(_gate('domain_ok.info').passed, isTrue);
    });

    test('fails on a domain file missing from the report', () {
      const untested = 'lib/domain/links/link.dart';
      final result = _gate('domain_ok.info', onDisk: [_note, _tag, untested]);
      expect(result.passed, isFalse);
      expect(result.messages.join('\n'), contains('missing: $untested'));
    });

    test('ignores generated domain files', () {
      final result = _gate(
        'domain_ok.info',
        onDisk: [_note, _tag, 'lib/domain/notes/note.freezed.dart'],
      );
      expect(result.passed, isTrue, reason: result.messages.join('\n'));
    });

    test('passes with a notice when there is no domain code yet', () {
      final result = _gate('no_domain.info', onDisk: const []);
      expect(result.passed, isTrue);
      expect(result.messages.join('\n'), contains('no domain code yet'));
    });

    test('a report with domain entries is gated even with none on disk', () {
      expect(_gate('domain_below.info', onDisk: const []).passed, isFalse);
    });
  });

  group('runCoverageGate', () {
    test('exits 1 on a below-threshold report', () async {
      final (code, out) = await _run([
        '--lcov',
        '$_fixtures/domain_below.info',
      ]);
      expect(code, 1);
      expect(out, contains('FAIL'));
    });

    test('exits 0 on a passing report', () async {
      final (code, _) = await _run(
        ['--lcov', '$_fixtures/domain_ok.info'],
        domainFiles: [_note, _tag],
      );
      expect(code, 0);
    });

    test('exits 0 with a notice when there is no report and no domain '
        'code', () async {
      final (code, out) = await _run(['--lcov', '$_fixtures/absent.info']);
      expect(code, 0);
      expect(out, contains('no domain code yet'));
    });

    test('exits 1 when domain code exists but the report does not', () async {
      final (code, out) = await _run(
        ['--lcov', '$_fixtures/absent.info'],
        domainFiles: [_note],
      );
      expect(code, 1);
      expect(out, contains('no coverage report'));
    });

    test('passes over an export-only library the report cannot list, with '
        'a notice (CP1 F-1)', () async {
      const barrel = 'lib/domain/notes/notes.dart';
      final (code, out) = await _run(
        ['--lcov', '$_fixtures/domain_ok.info'],
        domainFiles: [_note, _tag],
        barrels: [barrel],
      );
      expect(code, 0, reason: out);
      expect(out, isNot(contains('missing')));
      expect(out, contains('export-only library, nothing to cover: $barrel'));
    });

    test('still fails on a file with code missing beside a barrel', () async {
      const untested = 'lib/domain/links/link.dart';
      final (code, out) = await _run(
        ['--lcov', '$_fixtures/domain_ok.info'],
        domainFiles: [_note, _tag, untested],
        barrels: ['lib/domain/notes/notes.dart'],
      );
      expect(code, 1);
      expect(out, contains('missing: $untested'));
    });

    test('exits 2 on a usage error', () async {
      final (code, _) = await _run(['--min-lines', 'ninety']);
      expect(code, 2);
    });
  });

  group('runCoverageGate --run (the coverage gate, P1-02e)', () {
    late Directory root;
    late String lcov;
    late List<_Call> calls;

    setUp(() {
      root = Directory.systemTemp.createTempSync('coverage_gate_run_test');
      lcov = _lcovIn(root);
      calls = [];
      for (final file in [_note, _tag]) {
        File('${root.path}/$file')
          ..createSync(recursive: true)
          ..writeAsStringSync('// domain code\n');
      }
      Directory('${root.path}/test/domain').createSync(recursive: true);
    });
    tearDown(() => root.deleteSync(recursive: true));

    Future<(int, String)> gate(
      TestRunner runTests, {
      String dir = 'test/domain',
      bool explicitLcov = true,
    }) async {
      final out = StringBuffer();
      final code = await runCoverageGate(
        [
          '--root',
          root.path,
          '--run',
          dir,
          if (explicitLcov) ...['--lcov', lcov],
        ],
        out: out,
        runTests: runTests,
      );
      return (code, out.toString());
    }

    test('runs flutter test on the directory, in the root, with branch '
        'coverage into the report, and exits 0 when it passes', () async {
      final (code, out) = await gate(
        _fakeFlutter(calls, fixture: 'domain_ok.info'),
      );
      expect(code, 0, reason: out);
      expect(out, contains('coverage_gate: pass'));
      final call = calls.single;
      expect(call.workingDirectory, root.path);
      expect(call.args, [
        'test',
        '--coverage',
        '--branch-coverage',
        '--coverage-path',
        File(lcov).absolute.path,
        'test/domain',
      ]);
    });

    test('exits 1 when the run reports lines below 90 %', () async {
      final (code, out) = await gate(
        _fakeFlutter(calls, fixture: 'domain_below.info'),
      );
      expect(code, 1);
      expect(out, contains('85.0% lines < 90%'));
    });

    test('exits 1 when the run reports branches below 85 %', () async {
      final (code, out) = await gate(
        _fakeFlutter(calls, fixture: 'domain_branches_below.info'),
      );
      expect(code, 1);
      expect(out, contains('80.0% branches < 85%'));
    });

    test('exits 1, not a vacuous pass, when the run writes no report and '
        'domain code exists', () async {
      final (code, out) = await gate(_fakeFlutter(calls));
      expect(code, 1);
      expect(out, contains('no coverage report'));
    });

    test('deletes a stale report first, so an old pass cannot stand in for '
        'this run', () async {
      File(lcov)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          File('$_fixtures/domain_ok.info').readAsStringSync(),
        );
      final (code, out) = await gate(_fakeFlutter(calls));
      expect(code, 1);
      expect(out, contains('no coverage report'));
    });

    test('exits 1 when the tests fail, even with a passing report', () async {
      final (code, out) = await gate(
        _fakeFlutter(calls, fixture: 'domain_ok.info', exitCode: 1),
      );
      expect(code, 1);
      expect(out, contains('flutter test test/domain exited 1'));
    });

    test('exits 1 without running anything when the directory does not '
        'exist', () async {
      final (code, out) = await gate(
        _fakeFlutter(calls, fixture: 'domain_ok.info'),
        dir: 'test/nowhere',
      );
      expect(code, 1);
      expect(out, contains('no test directory'));
      expect(calls, isEmpty);
    });

    test('writes its own report, not coverage/lcov.info, by default', () async {
      final (code, _) = await gate(
        _fakeFlutter(calls, fixture: 'domain_ok.info'),
        explicitLcov: false,
      );
      final path =
          calls.single.args[calls.single.args.indexOf('--coverage-path') + 1];
      addTearDown(() {
        if (File(path).existsSync()) File(path).deleteSync();
      });
      expect(code, 0);
      expect(path, endsWith('coverage/$runReport'));
      expect(path, isNot(endsWith('coverage/lcov.info')));
    });

    test('exits 2 when --run has no value', () async {
      final out = StringBuffer();
      final code = await runCoverageGate(
        ['--root', root.path, '--run'],
        out: out,
        runTests: _fakeFlutter(calls),
      );
      expect(code, 2);
      expect(calls, isEmpty);
    });
  });
}
