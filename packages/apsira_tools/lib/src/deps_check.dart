// From relay tool/privacy/deps_check.dart @ 5f606e9
// The dependency check of `privacy_guards` (08 §3, §9; D-041, CLAUDE.md §6):
// every package the app can reach at runtime is on the allowlist, with the
// reason it is there, and none is a known network package.
//
// The runtime closure starts at the root's regular dependencies (dev
// dependencies excluded) and follows every package's dependencies in
// `dart pub deps --json`, which is run unless `--deps-json` gives a saved
// output. Packages that run only in a build hook are allowlisted with the
// reason [buildHookReason]: D-096 reads the no-network-code rule as runtime
// only, and sqlite3's hook downloads its checked prebuilt library at build
// time.
//
// The spike-only dev dependencies are checked too (the name is the removed
// Spike lab's, D-104; the section is empty since
// flutter_local_notifications became a regular dependency, D-114): each
// package in the `spike_only` section must stay outside the runtime
// closure (a regular dependency that reaches one makes Flutter keep its
// plugin in release builds), and the closure of
// the spike-only dev dependencies may add only packages listed there with
// a reason, none of them a network package unless it is the one
// `network_exceptions` entry (D-105: `http`, which
// flutter_local_notifications' `timezone` brings). The exception holds
// only at import level: the check fails when a file under lib/ imports or
// exports one of its `banned_imports`. In the runtime closure it holds only
// where its `runtime_via` packages are the only ones that depend on it
// (D-111: image_picker's platform interfaces declare `http` for their web
// code alone; D-114: `timezone`, whose browser.dart alone imports it); any
// other runtime path to it still fails.
//
//   dart run apsira_tools:deps_check [--config <file>] [--deps-json <file>]
//       [--allowlist <file>] [--lib <dir>]
//
// `--allowlist` defaults to `privacy.allowlist` of the `--config` file
// (default tool/apsira_tools.yaml, D-APK-002):
// tool/privacy/dependency_allowlist.yaml.
//
// Exit 0 when clean, 1 naming each finding, 2 on bad usage.
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'config.dart';

/// The reason every hook-only package carries (D-096).
const buildHookReason = 'build hook, not in the APK';

const _usage =
    'usage: dart run apsira_tools:deps_check [--config <file>] '
    '[--deps-json <file>] [--allowlist <file>] [--lib <dir>]';

/// How many `network_exceptions` the allowlist may hold (D-105); a second
/// one needs its own decision.
const maxNetworkExceptions = 1;

/// A network package the spike-only closure may hold (D-105): why, and the
/// import URI prefixes lib/ must never use, so its network code stays out.
final class NetworkException {
  const NetworkException(
    this.reason,
    this.bannedImports, [
    this.runtimeVia = const [],
  ]);

  final String reason;
  final List<String> bannedImports;

  /// The runtime packages that may depend on it (D-111); empty keeps it out
  /// of the runtime closure.
  final List<String> runtimeVia;
}

/// The packages reachable from the root's regular dependencies in [depsJson],
/// the output of `dart pub deps --json`. The root itself is left out.
Set<String> runtimeClosure(String depsJson) {
  final (packages, root) = _graph(depsJson);
  return _closure(packages, (root['directDependencies'] as List).cast());
}

/// For each package of the runtime closure in [depsJson], the packages of
/// that closure (the root included) that depend on it directly.
Map<String, Set<String>> runtimeDependents(String depsJson) {
  final (packages, root) = _graph(depsJson);
  final closure = runtimeClosure(depsJson);
  final dependents = <String, Set<String>>{};
  void add(String from, Iterable<String> to) {
    for (final name in to) {
      (dependents[name] ??= {}).add(from);
    }
  }

  add(root['name'] as String, (root['directDependencies'] as List).cast());
  for (final name in closure) {
    add(name, (packages[name]!['dependencies'] as List).cast());
  }
  return dependents;
}

/// The packages reachable from the root's dev dependencies that
/// [allowlist] lists as spike-only, those included.
Set<String> spikeClosure(String depsJson, DependencyAllowlist allowlist) {
  final (packages, root) = _graph(depsJson);
  final dev = (root['devDependencies'] as List? ?? const []).cast<String>();
  return _closure(packages, dev.where(allowlist.spikeOnly.containsKey));
}

typedef _Package = Map<String, dynamic>;

(Map<String, _Package>, _Package) _graph(String depsJson) {
  final json = jsonDecode(depsJson) as Map<String, dynamic>;
  final packages = {
    for (final p in (json['packages'] as List).cast<_Package>())
      p['name'] as String: p,
  };
  return (packages, packages[json['root']]!);
}

Set<String> _closure(Map<String, _Package> packages, Iterable<String> from) {
  final seen = <String>{};
  final pending = [...from];
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!seen.add(name)) continue;
    final package = packages[name];
    if (package == null) {
      throw FormatException('pub deps names $name but does not list it');
    }
    pending.addAll((package['dependencies'] as List).cast<String>());
  }
  return seen;
}

/// tool/privacy/dependency_allowlist.yaml: `allowed` maps each package to
/// its reason; `spike_only` maps each spike-only dev dependency, and each
/// package its closure adds, to its reason; `network` lists known network
/// packages, and `network_prefixes` the name prefixes of whole network
/// families.
final class DependencyAllowlist {
  DependencyAllowlist({
    required this.allowed,
    required this.network,
    required this.networkPrefixes,
    this.spikeOnly = const {},
    this.networkExceptions = const {},
  });

  factory DependencyAllowlist.parse(String yaml) {
    final doc = loadYaml(yaml) as YamlMap;
    Map<String, String> reasons(String section) => {
      for (final MapEntry(:key, :value)
          in ((doc[section] as YamlMap?) ?? YamlMap()).entries)
        '$key': value == null ? '' : '$value',
    };
    return DependencyAllowlist(
      allowed: reasons('allowed'),
      spikeOnly: reasons('spike_only'),
      networkExceptions: {
        for (final MapEntry(:key, :value)
            in ((doc['network_exceptions'] as YamlMap?) ?? YamlMap()).entries)
          '$key': NetworkException(
            '${(value as YamlMap?)?['reason'] ?? ''}',
            [...?(value?['banned_imports'] as YamlList?)?.map((e) => '$e')],
            [...?(value?['runtime_via'] as YamlList?)?.map((e) => '$e')],
          ),
      },
      network: {...?(doc['network'] as YamlList?)?.map((e) => '$e')},
      networkPrefixes: [
        ...?(doc['network_prefixes'] as YamlList?)?.map((e) => '$e'),
      ],
    );
  }

  final Map<String, String> allowed;
  final Map<String, String> spikeOnly;

  /// Network packages the spike-only closure may hold, by name.
  final Map<String, NetworkException> networkExceptions;
  final Set<String> network;
  final List<String> networkPrefixes;

  bool isNetwork(String package) =>
      network.contains(package) ||
      networkPrefixes.any((prefix) => package.startsWith(prefix));

  /// Entries that make the list itself wrong: a package with no reason, or
  /// a network package allowed.
  List<String> problems() => [
    for (final MapEntry(:key, :value) in allowed.entries)
      if (value.trim().isEmpty)
        'allowlist: $key has no reason'
      else if (isNetwork(key))
        'allowlist: $key is a network package and cannot be allowed',
    for (final MapEntry(:key, :value) in spikeOnly.entries)
      if (value.trim().isEmpty)
        'spike_only: $key has no reason'
      else if (isNetwork(key))
        'spike_only: $key is a network package and cannot be listed',
    for (final MapEntry(:key, :value) in networkExceptions.entries) ...[
      if (value.reason.trim().isEmpty) 'network_exceptions: $key has no reason',
      if (value.bannedImports.isEmpty)
        'network_exceptions: $key bans no import',
    ],
    if (networkExceptions.length > maxNetworkExceptions)
      'network_exceptions: ${networkExceptions.length} entries; at most '
          '$maxNetworkExceptions (D-105), a second needs a decision',
  ];
}

/// What a runtime closure holds against the allowlist.
final class DepsReport {
  DepsReport({
    required this.notAllowed,
    required this.network,
    required this.listProblems,
    this.networkVia = const {},
    this.spikeInRuntime = const [],
    this.spikeUnlisted = const [],
    this.spikeNetwork = const [],
    this.banned = const [],
    this.allowlistPath = 'tool/privacy/dependency_allowlist.yaml',
  });

  /// The allowlist file a finding tells the reader to edit.
  final String allowlistPath;

  final List<String> notAllowed;
  final List<String> network;
  final List<String> listProblems;

  /// For a [network] package an exception names, the runtime packages
  /// outside its `runtime_via` that depend on it.
  final Map<String, List<String>> networkVia;

  /// Spike-only packages a regular dependency reaches.
  final List<String> spikeInRuntime;

  /// Packages the spike-only closure adds without a `spike_only` entry.
  final List<String> spikeUnlisted;

  /// Network packages the spike-only closure adds.
  final List<String> spikeNetwork;

  /// lib/ imports of a network exception's banned URIs ([bannedImports]).
  final List<String> banned;

  bool get isClean =>
      banned.isEmpty &&
      notAllowed.isEmpty &&
      network.isEmpty &&
      listProblems.isEmpty &&
      spikeInRuntime.isEmpty &&
      spikeUnlisted.isEmpty &&
      spikeNetwork.isEmpty;

  Iterable<String> get findings => [
    for (final p in network)
      (networkVia[p] ?? const []).isEmpty
          ? 'network package: $p (D-041)'
          : 'network package: $p (D-041; reached through '
                '${networkVia[p]!.join(', ')})',
    for (final p in notAllowed)
      'not on the allowlist: $p (add it to $allowlistPath with its '
          'reason, after checking it does no network I/O)',
    for (final p in spikeInRuntime)
      'spike-only package in the runtime closure: $p (a regular dependency '
          'reaches it, so Flutter would keep it in release builds)',
    for (final b in banned)
      'banned import: $b; the network exception holds only while lib/ '
          'never imports its network code',
    for (final p in spikeNetwork)
      'network package in the spike-only closure: $p (D-041)',
    for (final p in spikeUnlisted)
      'not listed under spike_only: $p (the spike-only closure adds it; '
          'list it with its reason, after checking it does no network I/O)',
    ...listProblems,
  ];

  @override
  String toString() => findings.join('\n');
}

/// Checks the runtime [closure] against [allowlist] and, given the
/// [spike] closure ([spikeClosure]), the spike-only rule. A network
/// exception holds in [closure] only when [dependents]
/// ([runtimeDependents]) names its `runtime_via` packages alone (D-111).
DepsReport checkDependencies(
  Set<String> closure,
  DependencyAllowlist allowlist, {
  Set<String> spike = const {},
  List<String> banned = const [],
  Map<String, Set<String>> dependents = const {},
  String allowlistPath = 'tool/privacy/dependency_allowlist.yaml',
}) {
  final added = spike.difference(closure);
  final excepted = allowlist.networkExceptions.keys.toSet();
  List<String> sorted(Iterable<String> names) => names.toList()..sort();
  List<String> outside(String package) => sorted(
    (dependents[package] ?? const <String>{}).difference(
      allowlist.networkExceptions[package]!.runtimeVia.toSet(),
    ),
  );
  bool admitted(String package) =>
      excepted.contains(package) &&
      allowlist.networkExceptions[package]!.runtimeVia.isNotEmpty &&
      (dependents[package]?.isNotEmpty ?? false) &&
      outside(package).isEmpty;
  final network = closure.where(allowlist.isNetwork);
  return DepsReport(
    notAllowed: sorted(
      closure.where((p) => !allowlist.allowed.containsKey(p) && !admitted(p)),
    ),
    network: sorted(network.where((p) => !admitted(p))),
    networkVia: {
      for (final p in network.where(excepted.contains)) p: outside(p),
    },
    listProblems: allowlist.problems(),
    spikeInRuntime: sorted(allowlist.spikeOnly.keys.where(closure.contains)),
    spikeUnlisted: sorted(
      added.where(
        (p) => !allowlist.spikeOnly.containsKey(p) && !excepted.contains(p),
      ),
    ),
    spikeNetwork: sorted(
      added.where((p) => allowlist.isNetwork(p) && !excepted.contains(p)),
    ),
    banned: banned,
    allowlistPath: allowlistPath,
  );
}

final _directive = RegExp(r'^[ \t]*(?:import|export)\b[^;]*;', multiLine: true);
final _quoted = RegExp(r'''(['"])(.*?)\1''');

/// Every `<file>:<line> <uri> (<package>, D-105)` where a `.dart` file under
/// [lib] imports or exports a URI one of [allowlist]'s network exceptions
/// bans. Directives are matched at line starts, so a commented-out import
/// does not count.
List<String> bannedImports(String lib, DependencyAllowlist allowlist) {
  final found = <String>[];
  if (!Directory(lib).existsSync()) return found;
  final files =
      Directory(lib)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final source = file.readAsStringSync();
    for (final directive in _directive.allMatches(source)) {
      final line = '\n'.allMatches(source.substring(0, directive.start)).length;
      for (final uri in _quoted.allMatches(directive[0]!)) {
        for (final MapEntry(:key, :value)
            in allowlist.networkExceptions.entries) {
          if (value.bannedImports.any(uri[2]!.startsWith)) {
            found.add('${file.path}:${line + 1} ${uri[2]} ($key, D-105)');
          }
        }
      }
    }
  }
  return found;
}

Future<int> runDepsCheck(List<String> args, {StringSink? out}) async {
  final sink = out ?? stdout;
  String? depsPath;
  String? allowlistPath;
  var configPath = defaultConfigPath;
  var lib = 'lib';
  for (var i = 0; i < args.length; i += 2) {
    if (i + 1 >= args.length) {
      sink.writeln(_usage);
      return 2;
    }
    switch (args[i]) {
      case '--config':
        configPath = args[i + 1];
      case '--deps-json':
        depsPath = args[i + 1];
      case '--allowlist':
        allowlistPath = args[i + 1];
      case '--lib':
        lib = args[i + 1];
      default:
        sink.writeln(_usage);
        return 2;
    }
  }
  try {
    allowlistPath ??= ApsiraToolsConfig.load(path: configPath)
        .privacy
        .allowlist;
  } on FormatException catch (e) {
    sink.writeln('deps: ${e.message}');
    return 2;
  }
  for (final path in [?depsPath, allowlistPath]) {
    if (!File(path).existsSync()) {
      sink.writeln('deps: no such file: $path');
      return 2;
    }
  }
  final String depsJson;
  if (depsPath != null) {
    depsJson = File(depsPath).readAsStringSync();
  } else {
    final result = await Process.run('dart', ['pub', 'deps', '--json']);
    if (result.exitCode != 0) {
      sink.writeln('deps: dart pub deps --json failed: ${result.stderr}');
      return 2;
    }
    depsJson = '${result.stdout}';
  }
  final closure = runtimeClosure(depsJson);
  final dependents = runtimeDependents(depsJson);
  final allowlist = DependencyAllowlist.parse(
    File(allowlistPath).readAsStringSync(),
  );
  final spike = spikeClosure(depsJson, allowlist);
  final report = checkDependencies(
    closure,
    allowlist,
    spike: spike,
    banned: bannedImports(lib, allowlist),
    dependents: dependents,
    allowlistPath: allowlistPath,
  );
  for (final finding in report.findings) {
    sink.writeln('deps: $finding');
  }
  if (!report.isClean) {
    sink.writeln('deps: the runtime closure breaks the allowlist');
    return 1;
  }
  final unused = allowlist.allowed.keys.toSet().difference(closure);
  final admitted = closure.where(allowlist.isNetwork).toList()..sort();
  sink.writeln(
    'deps: ${closure.length} runtime packages allowlisted, '
    'no network package'
    '${admitted.isEmpty ? '' : ' but ${admitted.join(', ')} (D-111, D-114)'}; '
    '${spike.difference(closure).length} spike-only packages outside it'
    '${unused.isEmpty ? '' : '; not in the closure: ${(unused.toList()..sort()).join(', ')}'}',
  );
  return 0;
}
