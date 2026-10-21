// From relay test/critical/privacy_guards_test.dart @ 5f606e9
// The `privacy_guards` critical suite (08 §3, §9; D-041, D-050): the merged
// release manifest has no `INTERNET` and holds exactly the declared
// permissions (tool/privacy/manifest_check.dart; CI runs it on Gradle's
// merged prodRelease manifest), the runtime dependency closure stays inside
// the allowlist with no network package but D-105's http through its
// runtime_via packages (tool/privacy/deps_check.dart; D-111, D-114), any
// spike-only dev dependency stays outside that closure with its own closure
// listed and free of network packages (none since D-114), the dev flavour
// declares no permission of its own, Android's own backup goes through
// RelayBackupAgent with its rules and copies nothing while the setting is
// off (D-116), and the log never holds note text.
// Fixtures are in test/fixtures/privacy/; the spike-only cases build their
// `dart pub deps --json` inline. Tests run from the package root.
import 'dart:convert';
import 'dart:io';

import 'package:apsira_tools/src/deps_check.dart';
import 'package:apsira_tools/src/manifest_check.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/privacy';
const _internet = 'android.permission.INTERNET';
const _biometric = 'android.permission.USE_BIOMETRIC';
const _receiver =
    'com.apsiralabs.relay.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';

String _read(String path) => File(path).readAsStringSync();

Future<(int, String)> _manifest(List<String> args) async {
  final out = StringBuffer();
  final code = await runManifestCheck(args, out: out);
  return (code, out.toString());
}

Future<(int, String)> _deps(List<String> args) async {
  final out = StringBuffer();
  final code = await runDepsCheck(args, out: out);
  return (code, out.toString());
}

/// A `dart pub deps --json` document: the root `app` with [direct] and
/// [dev] dependencies, and every package's own dependencies in [graph].
String _depsJson({
  required List<String> direct,
  required List<String> dev,
  Map<String, List<String>> graph = const {},
}) {
  final names = {
    ...direct,
    ...dev,
    ...graph.keys,
    ...graph.values.expand((d) => d),
  };
  return jsonEncode({
    'root': 'app',
    'packages': [
      {
        'name': 'app',
        'kind': 'root',
        'dependencies': [...direct, ...dev],
        'directDependencies': direct,
        'devDependencies': dev,
      },
      for (final name in names)
        {'name': name, 'kind': 'transitive', 'dependencies': graph[name] ?? []},
    ],
  });
}

/// An allowlist that allows [allowed] and lists [spikeOnly] as spike-only,
/// with the repository's network lists.
DependencyAllowlist _allowlist(
  Iterable<String> allowed,
  Map<String, String> spikeOnly,
) {
  final repo = DependencyAllowlist.parse(
    _read('tool/privacy/dependency_allowlist.yaml'),
  );
  return DependencyAllowlist(
    allowed: {for (final p in allowed) p: 'test'},
    network: repo.network,
    networkPrefixes: repo.networkPrefixes,
    spikeOnly: spikeOnly,
  );
}

/// Runs the deps command line on [depsJson] and [allowlistYaml] written to
/// a temporary directory.
Future<(int, String)> _depsFiles(String depsJson, String allowlistYaml) async {
  final dir = Directory.systemTemp.createTempSync('privacy_deps_');
  try {
    final deps = File('${dir.path}/deps.json')..writeAsStringSync(depsJson);
    final list = File('${dir.path}/allowlist.yaml')
      ..writeAsStringSync(allowlistYaml);
    return await _deps(['--deps-json', deps.path, '--allowlist', list.path]);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  group('manifest', () {
    final declared = parseDeclaredPermissions(
      _read('tool/privacy/declared_permissions.txt'),
    );

    test('accepts the declared set', () async {
      final report = checkManifest(
        _read('$_fixtures/manifest_declared.xml'),
        declared,
      );
      expect(report.isClean, isTrue, reason: '$report');
      final (code, out) = await _manifest([
        '--manifest',
        '$_fixtures/manifest_declared.xml',
      ]);
      expect(code, 0, reason: out);
    });

    test('rejects INTERNET', () async {
      final report = checkManifest(
        _read('$_fixtures/manifest_with_internet.xml'),
        declared,
      );
      expect(report.forbidden, [_internet]);
      final (code, out) = await _manifest([
        '--manifest',
        '$_fixtures/manifest_with_internet.xml',
      ]);
      expect(code, 1);
      expect(out, contains(_internet));
    });

    test('rejects a permission outside the declared set', () async {
      final report = checkManifest(
        _read('$_fixtures/manifest_extra_permission.xml'),
        declared,
      );
      expect(report.forbidden, isEmpty);
      expect(report.undeclared, ['android.permission.CAMERA']);
      final (code, out) = await _manifest([
        '--manifest',
        '$_fixtures/manifest_extra_permission.xml',
      ]);
      expect(code, 1);
      expect(out, contains('android.permission.CAMERA'));
    });

    test('rejects a declared permission the manifest lacks', () {
      final report = checkManifest('<manifest></manifest>', declared);
      expect(report.missing, [
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MICROPHONE',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.RECORD_AUDIO',
        _biometric,
        'android.permission.USE_EXACT_ALARM',
        'android.permission.VIBRATE',
        'android.permission.WAKE_LOCK',
        _receiver,
      ]);
      expect(report.isClean, isFalse);
    });

    test('reads every uses-permission form and skips comments', () {
      const xml = '''
<manifest>
  <!-- <uses-permission android:name="android.permission.INTERNET"/> -->
  <uses-permission
      android:name="android.permission.VIBRATE"/>
  <uses-permission-sdk-23 android:name="android.permission.CAMERA" />
  <uses-permission-sdk-m android:maxSdkVersion="35"
      android:name='android.permission.WAKE_LOCK'/>
  <permission android:name="com.example.OWN"/>
</manifest>''';
      expect(usesPermissions(xml), {
        'android.permission.VIBRATE',
        'android.permission.CAMERA',
        'android.permission.WAKE_LOCK',
      });
    });

    test('finds the one manifest in a Gradle output directory', () async {
      final dir = Directory.systemTemp.createTempSync('privacy_manifest_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final (missing, _) = await _manifest(['--manifest', dir.path]);
      expect(missing, 2, reason: 'no manifest under the directory');
      File('${dir.path}/processProdReleaseManifest/AndroidManifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(_read('$_fixtures/manifest_with_internet.xml'));
      final (code, out) = await _manifest(['--manifest', dir.path]);
      expect(code, 1, reason: out);
      expect(out, contains(_internet));
    });
    test('reads the permissions a manifest removes', () {
      const xml = '''
<manifest xmlns:tools="http://schemas.android.com/tools">
  <!-- <uses-permission android:name="android.permission.CAMERA" tools:node="remove"/> -->
  <uses-permission android:name="android.permission.VIBRATE" />
  <uses-permission
      android:name="android.permission.ACCESS_NETWORK_STATE"
      tools:node="remove" />
  <uses-permission tools:node='remove'
      android:name='android.permission.POST_NOTIFICATIONS'/>
</manifest>''';
      expect(removedPermissions(xml), {
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.POST_NOTIFICATIONS',
      });
    });
  });

  group('dependencies', () {
    final allowlist = DependencyAllowlist.parse(
      _read('tool/privacy/dependency_allowlist.yaml'),
    );
    test('a spike-only package in the runtime closure fails, naming it '
        '(Flutter would keep its plugin in release builds)', () async {
      final deps = _depsJson(
        direct: ['meta', 'helper'],
        dev: ['record'],
        graph: {
          'helper': ['record'],
        },
      );
      final allowlist = _allowlist(
        ['meta', 'helper', 'record'],
        {'record': 'spike P0-16'},
      );
      final report = checkDependencies(
        runtimeClosure(deps),
        allowlist,
        spike: spikeClosure(deps, allowlist),
      );
      expect(report.spikeInRuntime, ['record']);
      expect(report.isClean, isFalse);
      final (code, out) = await _depsFiles(deps, '''
allowed:
  meta: test
  helper: test
  record: test
spike_only:
  record: spike P0-16
''');
      expect(code, 1, reason: out);
      expect(
        out,
        contains('spike-only package in the runtime closure: record'),
      );
    });

    test('a spike-only closure holding http fails', () async {
      final deps = _depsJson(
        direct: ['meta'],
        dev: ['notifier'],
        graph: {
          'notifier': ['zones'],
          'zones': ['http'],
        },
      );
      final allowlist = _allowlist(
        ['meta'],
        {'notifier': 'spike P0-15', 'zones': 'notifier'},
      );
      final spike = spikeClosure(deps, allowlist);
      expect(spike, {'notifier', 'zones', 'http'});
      final report = checkDependencies(
        runtimeClosure(deps),
        allowlist,
        spike: spike,
      );
      expect(report.spikeNetwork, ['http']);
      expect(report.spikeUnlisted, ['http']);
      final (code, out) = await _depsFiles(deps, '''
allowed:
  meta: test
spike_only:
  notifier: spike P0-15
  zones: notifier
network:
  - http
''');
      expect(code, 1, reason: out);
      expect(out, contains('network package in the spike-only closure: http'));
    });

    test('every package a spike-only closure adds is listed with a reason', () {
      final deps = _depsJson(
        direct: ['meta'],
        dev: ['recorder'],
        graph: {
          'recorder': ['meta', 'rx'],
        },
      );
      final allowlist = _allowlist(['meta'], {'recorder': 'spike P0-16'});
      final report = checkDependencies(
        runtimeClosure(deps),
        allowlist,
        spike: spikeClosure(deps, allowlist),
      );
      expect(report.spikeUnlisted, ['rx'], reason: 'meta is already allowed');
      expect(report.spikeNetwork, isEmpty);
      final listed = _allowlist(
        ['meta'],
        {'recorder': 'spike P0-16', 'rx': 'recorder'},
      );
      expect(
        checkDependencies(
          runtimeClosure(deps),
          listed,
          spike: spikeClosure(deps, listed),
        ).isClean,
        isTrue,
      );
    });
    test('the http exception admits http at runtime only through its '
        'runtime_via packages (D-111)', () {
      final excepted = DependencyAllowlist.parse('''
allowed:
  meta: test
  picker: test
  picker_interface: test
  other: test
network:
  - http
network_exceptions:
  http:
    reason: picker_interface declares it for web code; lib/ never imports it
    banned_imports:
      - package:http/
    runtime_via:
      - picker_interface
''');
      DepsReport check(List<String> direct, Map<String, List<String>> graph) {
        final deps = _depsJson(direct: direct, dev: [], graph: graph);
        return checkDependencies(
          runtimeClosure(deps),
          excepted,
          dependents: runtimeDependents(deps),
        );
      }

      final through = {
        'picker': ['picker_interface'],
        'picker_interface': ['http'],
      };
      expect(check(['meta', 'picker'], through).isClean, isTrue);
      final other = check(
        ['meta', 'picker', 'other'],
        {
          ...through,
          'other': ['http'],
        },
      );
      expect(other.network, ['http']);
      expect(
        other.findings,
        contains('network package: http (D-041; reached through other)'),
      );
      expect(check(['meta', 'picker', 'http'], through).network, ['http']);
    });

    test('the http exception lets the spike closure hold http, never the '
        'runtime closure', () {
      final deps = _depsJson(
        direct: ['meta'],
        dev: ['notifier'],
        graph: {
          'notifier': ['zones'],
          'zones': ['http'],
        },
      );
      final excepted = DependencyAllowlist.parse('''
allowed:
  meta: test
spike_only:
  notifier: spike P0-15
  zones: notifier
network:
  - http
network_exceptions:
  http:
    reason: zones brings it; lib/ never imports it
    banned_imports:
      - package:http/
''');
      final spike = spikeClosure(deps, excepted);
      expect(
        checkDependencies(runtimeClosure(deps), excepted, spike: spike).isClean,
        isTrue,
      );
      final runtime = _depsJson(direct: ['meta', 'http'], dev: []);
      final report = checkDependencies(runtimeClosure(runtime), excepted);
      expect(report.network, ['http']);
    });

    test('a lib/ file importing http turns the check red: the exception '
        'cannot widen', () async {
      final dir = Directory.systemTemp.createTempSync('privacy_lib_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/lib/features/spike_lab/alarms/sync.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
// import 'package:http/http.dart'; a comment is not an import
import 'dart:async';
import 'package:http/http.dart' as http;
''');
      File('${dir.path}/lib/app/zones.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "export 'package:timezone/standalone.dart' show initializeTimeZone;",
        );
      final found = bannedImports('${dir.path}/lib', allowlist);
      expect(found.map((f) => f.substring(dir.path.length + 1)), [
        'lib/app/zones.dart:1 package:timezone/standalone.dart (http, D-105)',
        'lib/features/spike_lab/alarms/sync.dart:3 package:http/http.dart '
            '(http, D-105)',
      ]);
      final (code, out) = await _deps([
        '--deps-json',
        '$_fixtures/deps_network_dev_only.json',
        '--lib',
        '${dir.path}/lib',
      ]);
      expect(code, 1, reason: out);
      expect(out, contains('banned import: '));
      expect(out, contains('sync.dart:3 package:http/http.dart'));
    });

    test('a closure with http fails', () async {
      final closure = runtimeClosure(_read('$_fixtures/deps_with_http.json'));
      expect(closure, {'collection', 'http', 'http_parser', 'meta'});
      final report = checkDependencies(closure, allowlist);
      expect(report.network, ['http']);
      expect(report.notAllowed, ['http']);
      final (code, out) = await _deps([
        '--deps-json',
        '$_fixtures/deps_with_http.json',
      ]);
      expect(code, 1);
      expect(out, contains('network package: http'));
    });

    test('dev dependencies are outside the runtime closure', () async {
      final closure = runtimeClosure(
        _read('$_fixtures/deps_network_dev_only.json'),
      );
      expect(closure, {'collection', 'meta'});
      final (code, out) = await _deps([
        '--deps-json',
        '$_fixtures/deps_network_dev_only.json',
      ]);
      expect(code, 0, reason: out);
    });
    test('a direct dependency with no reason fails, naming it', () async {
      final deps = _depsJson(direct: ['meta', 'helper'], dev: []);
      final (code, out) = await _depsFiles(deps, '''
allowed:
  meta: test
  helper: ""
''');
      expect(code, 1, reason: out);
      expect(out, contains('allowlist: helper has no reason'));
    });

    test('the allowlist is well formed: a reason for every package and no '
        'network package in it', () {
      expect(allowlist.network, containsAll(['http', 'dio', 'grpc']));
      expect(allowlist.problems(), isEmpty);
      final bad = DependencyAllowlist.parse('''
allowed:
  http: a client
  meta: ""
network:
  - http
''');
      expect(bad.problems(), hasLength(2));
      final badSpike = DependencyAllowlist.parse('''
spike_only:
  record: ""
  dio: a client
network:
  - dio
''');
      expect(badSpike.problems(), [
        'spike_only: record has no reason',
        'spike_only: dio is a network package and cannot be listed',
      ]);
      final badExceptions = DependencyAllowlist.parse('''
network_exceptions:
  http:
    reason: ""
    banned_imports: []
  dio:
    reason: a second one
    banned_imports:
      - package:dio/
''');
      expect(badExceptions.problems(), [
        'network_exceptions: http has no reason',
        'network_exceptions: http bans no import',
        'network_exceptions: 2 entries; at most 1 (D-105), a second needs a '
            'decision',
      ]);
    });
  });
}
