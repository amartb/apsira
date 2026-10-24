// From relay tool/privacy/manifest_check.dart @ 5f606e9
// The merged-manifest check of `privacy_guards` (08 §3, §9; D-041,
// architecture §11): the release manifest declares no `INTERNET`, and its
// permission list equals tool/privacy/declared_permissions.txt exactly, so
// a plugin that adds a permission fails CI until the list (with its reason)
// says so.
//
//   dart run apsira_tools:manifest_check [--config <file>]
//       [--manifest] <file or directory> [--declared <file>]
//       [--architecture <file>]
//
// `--declared` defaults to `privacy.declared_permissions` of the `--config`
// file (default tool/apsira_tools.yaml, D-APK-002):
// tool/privacy/declared_permissions.txt. The manifest may be given
// positionally or with `--manifest`, and defaults to `privacy.manifest`
// (v0.2; none in RELAY).
//
// The approved permissions (v0.2, VIATICUM's, from viaticum
// tool/privacy/manifest_check.dart @ 20f05f6): with `--architecture` or
// `privacy.approved_permissions` (none in RELAY), every requested and
// every declared permission must be in the table of that document's
// `privacy.approved_heading` section (default `### 11.1`; a row's first
// cell is `` `NAME` `` for `android.permission.NAME`) or be one the
// manifest defines with signature protection, and every declared one needs
// a reason. A document without that table exits 2.
//
// CI runs it after Gradle's `processProdReleaseManifest` on
// build/app/intermediates/merged_manifests/prodRelease: a directory is
// searched for its single AndroidManifest.xml, so the check does not depend
// on the Android Gradle plugin's folder layout below it. Exit 0 when the
// set matches, 1 naming each forbidden, undeclared or missing permission,
// 2 on bad usage or when the manifest cannot be found.
//
// The scan is lexical: comments are removed, then every `uses-permission`
// element (and its `-sdk-23` / `-sdk-m` forms) gives its `android:name`.
import 'dart:io';

import 'config.dart';

/// Permissions no Relay manifest may hold, whatever the declared list says.
const forbiddenPermissions = {'android.permission.INTERNET'};

const _usage =
    'usage: dart run apsira_tools:manifest_check [--config <file>] '
    '[--manifest] <file or directory> [--declared <file>] '
    '[--architecture <file>]';

final _comment = RegExp(r'<!--.*?-->', dotAll: true);

final _usesPermission = RegExp(
  r'<uses-permission(?:-sdk-23|-sdk-m)?\b([^>]*)>',
  dotAll: true,
);

final _name = RegExp(r'''android:name\s*=\s*(?:"([^"]*)"|'([^']*)')''');

/// The permission names [manifest] requests.
Set<String> usesPermissions(String manifest) => {
  for (final element in _usesPermission.allMatches(
    manifest.replaceAll(_comment, ''),
  ))
    if (_name.firstMatch(element[1]!) case final m?) (m[1] ?? m[2])!,
};

final _removeNode = RegExp(r'''tools:node\s*=\s*(?:"remove"|'remove')''');

/// The permission names [manifest] removes from the merge
/// (`tools:node="remove"`): what a source manifest takes out of what its
/// libraries bring in. A merged manifest holds none.
Set<String> removedPermissions(String manifest) => {
  for (final element in _usesPermission.allMatches(
    manifest.replaceAll(_comment, ''),
  ))
    if (_removeNode.hasMatch(element[1]!))
      if (_name.firstMatch(element[1]!) case final m?) (m[1] ?? m[2])!,
};

final _permission = RegExp(r'<permission\b([^>]*)>', dotAll: true);

final _signature = RegExp(
  r'''android:protectionLevel\s*=\s*["']signature["']''',
);

/// The permissions [manifest] itself defines with signature protection:
/// only an app signed with the same key holds them.
Set<String> ownSignaturePermissions(String manifest) => {
  for (final element in _permission.allMatches(
    manifest.replaceAll(_comment, ''),
  ))
    if (_signature.hasMatch(element[1]!))
      if (_name.firstMatch(element[1]!) case final m?) (m[1] ?? m[2])!,
};

/// The permissions the [heading] section of [document] approves: the
/// first cell of every table row in it, `` `NAME` ``, as
/// `android.permission.NAME`. The section ends at the next heading of the
/// same level or above.
Set<String> approvedPermissions(
  String document, {
  String heading = '### 11.1',
}) {
  final start = document.indexOf(heading);
  if (start < 0) return {};
  final level = RegExp(r'^#*').firstMatch(heading)![0]!.length;
  final next = RegExp('^#{1,${level < 1 ? 1 : level}} ', multiLine: true);
  final headingEnd = document.indexOf('\n', start);
  final rest = headingEnd < 0 ? '' : document.substring(headingEnd);
  final end = next.firstMatch(rest)?.start ?? rest.length;
  return {
    for (final line in rest.substring(0, end).split('\n'))
      if (RegExp(r'^\|\s*`([A-Z_]+)`').firstMatch(line) case final m?)
        'android.permission.${m[1]}',
  };
}

/// The declared list: one `<permission>: <reason>` per line; blank lines and
/// lines starting with `#` are skipped. A line without a reason maps to ''.
Map<String, String> parseDeclaredPermissions(String text) => {
  for (final raw in text.split('\n'))
    if (raw.trim() case final line
        when line.isNotEmpty && !line.startsWith('#'))
      line.split(':').first.trim(): line.contains(':')
          ? line.substring(line.indexOf(':') + 1).trim()
          : '',
};

/// What a manifest holds against the declared list.
final class ManifestReport {
  ManifestReport({
    required this.forbidden,
    required this.undeclared,
    required this.missing,
    this.declaredPath = 'tool/privacy/declared_permissions.txt',
    this.outside = const [],
    this.declaredOutside = const [],
    this.noReason = const [],
    this.approvedSource = '',
  });

  /// Requested, not forbidden, and neither approved nor the app's own.
  final List<String> outside;

  /// Declared, and neither approved nor the app's own.
  final List<String> declaredOutside;

  /// Declared without a reason (checked with an approved source).
  final List<String> noReason;

  /// The approved-permissions source a finding names: `<file> <heading>`.
  final String approvedSource;

  /// The declared list a finding tells the reader to edit.
  final String declaredPath;

  /// Requested and in [forbiddenPermissions].
  final List<String> forbidden;

  /// Requested but not declared.
  final List<String> undeclared;

  /// Declared but not requested.
  final List<String> missing;

  bool get isClean => findings.isEmpty;

  Iterable<String> get findings => [
    for (final p in forbidden) 'forbidden permission: $p (D-041)',
    for (final p in outside) 'outside $approvedSource: $p',
    for (final p in undeclared)
      'undeclared permission: $p (add it to $declaredPath with its '
          'reason, if architecture §11.1 approves it)',
    for (final p in missing) 'declared but not in the manifest: $p',
    for (final p in declaredOutside)
      'the declared list holds $p, which is outside $approvedSource',
    for (final p in noReason) 'declared without a reason: $p',
  ];

  @override
  String toString() => findings.join('\n');
}

/// Checks [manifest] against the [declared] permission names, read from
/// [declaredPath], and, when [approved] is given (v0.2), against the
/// permissions [approvedSource] approves.
ManifestReport checkManifest(
  String manifest,
  Map<String, String> declared, {
  String declaredPath = 'tool/privacy/declared_permissions.txt',
  Set<String>? approved,
  String approvedSource = '',
}) {
  final requested = usesPermissions(manifest);
  final forbidden = requested.intersection(forbiddenPermissions);
  final own = ownSignaturePermissions(manifest);
  bool allowed(String p) => approved!.contains(p) || own.contains(p);
  List<String> sorted(Iterable<String> names) => names.toList()..sort();
  return ManifestReport(
    outside: approved == null
        ? const []
        : sorted(requested.difference(forbidden).where((p) => !allowed(p))),
    declaredOutside: approved == null
        ? const []
        : sorted(declared.keys.where((p) => !allowed(p))),
    noReason: approved == null
        ? const []
        : sorted(
            declared.entries.where((e) => e.value.isEmpty).map((e) => e.key),
          ),
    approvedSource: approvedSource,
    forbidden: forbidden.toList()..sort(),
    undeclared:
        requested
            .difference(declared.keys.toSet())
            .difference(forbidden)
            .toList()
          ..sort(),
    missing: declared.keys.toSet().difference(requested).toList()..sort(),
    declaredPath: declaredPath,
  );
}

/// [path] itself, or the single AndroidManifest.xml below the directory.
File? _locate(String path, StringSink out) {
  if (File(path).existsSync()) return File(path);
  final dir = Directory(path);
  if (!dir.existsSync()) {
    out.writeln('manifest: no such file or directory: $path');
    return null;
  }
  final found = [
    for (final entity in dir.listSync(recursive: true))
      if (entity is File &&
          entity.uri.pathSegments.last == 'AndroidManifest.xml')
        entity,
  ];
  if (found.length != 1) {
    out.writeln(
      'manifest: expected one AndroidManifest.xml under $path, '
      'found ${found.length}',
    );
    return null;
  }
  return found.single;
}

Future<int> runManifestCheck(List<String> args, {StringSink? out}) async {
  final sink = out ?? stdout;
  String? manifestPath;
  String? declaredPath;
  String? approvedPath;
  var configPath = defaultConfigPath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      if (manifestPath != null) {
        sink.writeln(_usage);
        return 2;
      }
      manifestPath = arg;
      continue;
    }
    if (i + 1 >= args.length) {
      sink.writeln(_usage);
      return 2;
    }
    final value = args[++i];
    switch (arg) {
      case '--config':
        configPath = value;
      case '--manifest' when manifestPath == null:
        manifestPath = value;
      case '--declared':
        declaredPath = value;
      case '--architecture':
        approvedPath = value;
      default:
        sink.writeln(_usage);
        return 2;
    }
  }
  final String heading;
  try {
    final privacy = ApsiraToolsConfig.load(path: configPath).privacy;
    declaredPath ??= privacy.declaredPermissions;
    manifestPath ??= privacy.manifest;
    approvedPath ??= privacy.approvedPermissions;
    heading = privacy.approvedHeading;
  } on FormatException catch (e) {
    sink.writeln('manifest: ${e.message}');
    return 2;
  }
  if (manifestPath == null) {
    sink.writeln(_usage);
    return 2;
  }
  final manifest = _locate(manifestPath, sink);
  if (manifest == null) return 2;
  if (!File(declaredPath).existsSync()) {
    sink.writeln('manifest: no such declared list: $declaredPath');
    return 2;
  }
  Set<String>? approved;
  if (approvedPath != null) {
    if (!File(approvedPath).existsSync()) {
      sink.writeln('manifest: no such file: $approvedPath');
      return 2;
    }
    approved = approvedPermissions(
      File(approvedPath).readAsStringSync(),
      heading: heading,
    );
    if (approved.isEmpty) {
      sink.writeln('manifest: no $heading permission table in $approvedPath');
      return 2;
    }
  }
  final declared = parseDeclaredPermissions(
    File(declaredPath).readAsStringSync(),
  );
  final report = checkManifest(
    manifest.readAsStringSync(),
    declared,
    declaredPath: declaredPath,
    approved: approved,
    approvedSource: '$approvedPath $heading',
  );
  for (final finding in report.findings) {
    sink.writeln('manifest: $finding');
  }
  if (!report.isClean) {
    sink.writeln('manifest: ${manifest.path} breaks the declared set');
    return 1;
  }
  sink.writeln(
    'manifest: ${manifest.path} clean (${declared.length} declared, '
    'no ${forbiddenPermissions.join(', ')})'
    "${approved == null ? '' : "; each in $approvedPath $heading or the app's own"}",
  );
  return 0;
}
