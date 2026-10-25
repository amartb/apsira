// From viaticum test/data/platform/alarm_manager_scheduler_test.dart
// @ 78d38e0 (its check of data_extraction_rules.xml), for every consumer and
// every per-install path, in every domain the rules name (D-APK-022).
import 'dart:io';

import '../alarm_registry.dart';
import '../snooze_store.dart';

/// The per-install paths under app storage the alarm registry defines; an
/// app's Android backup rules must exclude each of them.
const alarmInstallPaths = [AlarmRegistry.defaultPath, SnoozeStore.defaultPath];

/// A path in one domain of Android's backup rules, as an
/// `<exclude domain="…" path="…"/>` names it.
final class BackupPath {
  /// Under app storage (`files/`): the registry's and the C1 flag files.
  const BackupPath.file(this.path) : domain = 'file';

  /// A SharedPreferences file (`shared_prefs/`), by its file name.
  const BackupPath.sharedPref(this.path) : domain = 'sharedpref';

  /// Under the app's data directory itself: `app_flutter/`, the documents
  /// directory, where LYCEUM keeps its database and markers.
  const BackupPath.root(this.path) : domain = 'root';

  /// Under the databases directory (`databases/`).
  const BackupPath.database(this.path) : domain = 'database';

  /// The domain's name in the rules: `file`, `sharedpref`, `root` or
  /// `database`.
  final String domain;
  final String path;

  /// The path under the app's data directory, where the domains meet.
  String get _rooted => '${_domainFolders[domain]}${_bare(path)}';

  @override
  bool operator ==(Object other) =>
      other is BackupPath && other.domain == domain && other.path == path;

  @override
  int get hashCode => Object.hash(domain, path);

  /// `domain:path`, as a gap names it (a `file` path given in `paths` is
  /// named bare).
  @override
  String toString() => '$domain:$path';
}

/// The notification plugin's list of scheduled notifications
/// (`scheduled_notifications` in flutter_local_notifications'
/// `FlutterLocalNotificationsPlugin.java`), which its boot receiver re-arms:
/// per-install like the registry, whichever app holds the plugin.
const flnScheduledNotifications = BackupPath.sharedPref(
  'scheduled_notifications.xml',
);

/// Everything of the alarm registry's that an app's backup rules exclude:
/// [alarmInstallPaths] and [flnScheduledNotifications]. An app on
/// `AlarmManagerScheduler` adds `apsira_jobs`' `alarmManagerBackupExclusions`.
const alarmBackupExclusions = [
  BackupPath.file(AlarmRegistry.defaultPath),
  BackupPath.file(SnoozeStore.defaultPath),
  flnScheduledNotifications,
];

/// An app's Android backup rules leave a per-install path in.
final class BackupExclusionFailure implements Exception {
  const BackupExclusionFailure(this.gaps);

  /// One line per path and section that copies it.
  final List<String> gaps;

  @override
  String toString() =>
      'BackupExclusionFailure: Android\'s backup would copy\n'
      '${gaps.map((g) => '  $g').join('\n')}';
}

/// Checks that [dataExtractionRules] (`res/xml/data_extraction_rules.xml`)
/// excludes every one of [paths] (relative to app storage, the `file`
/// domain) and of [excluded] (any domain) from the cloud backup and from a
/// device-to-device transfer, and that [fullBackupContent]
/// (`full_backup_content`, Android 11 and earlier) excludes them too when the
/// app has one. A [BackupExclusionFailure] names every gap.
///
/// A line scan of `<exclude domain="…" path="…"/>` in the `file`,
/// `sharedpref`, `root` and `database` domains, comments left out, with no
/// XML dependency. The domains meet under the app's data directory, as
/// Android resolves them: an exclusion of a folder (`alarms/`, or `files/`
/// in `root`) covers what is in it, and a `sharedpref` name without `.xml`
/// covers its file. Rules written with `<include>` are not read, so they
/// show as gaps.
void expectExcludedFromDeviceBackup(
  File dataExtractionRules, {
  File? fullBackupContent,
  Iterable<String> paths = const [],
  Iterable<BackupPath> excluded = const [],
}) {
  final gaps = backupExclusionGaps(
    dataExtractionRules.readAsStringSync(),
    fullBackupContent: fullBackupContent?.readAsStringSync(),
    paths: paths,
    excluded: excluded,
  );
  if (gaps.isNotEmpty) throw BackupExclusionFailure(gaps);
}

/// The gaps [expectExcludedFromDeviceBackup] reports, from the files' text:
/// `<path>: …` for [paths], `<domain>:<path>: …` for [excluded].
List<String> backupExclusionGaps(
  String dataExtractionRules, {
  String? fullBackupContent,
  Iterable<String> paths = const [],
  Iterable<BackupPath> excluded = const [],
}) {
  final rules = _withoutComments(dataExtractionRules);
  final sections = <String, List<String>?>{
    'cloud-backup': _section(rules, 'cloud-backup'),
    'device-transfer': _section(rules, 'device-transfer'),
    if (fullBackupContent != null)
      'full-backup-content': _section(
        _withoutComments(fullBackupContent),
        'full-backup-content',
      ),
  };
  final wanted = [
    for (final path in paths) (path, BackupPath.file(path)),
    for (final e in excluded) ('$e', e),
  ];
  return [
    for (final (name, path) in wanted)
      for (final MapEntry(key: section, value: excludes) in sections.entries)
        if (excludes == null)
          '$name: no <$section> section'
        else if (!excludes.any((e) => _covers(e, path._rooted)))
          '$name: not excluded in <$section>',
  ];
}

/// Each domain's folder under the app's data directory.
const _domainFolders = {
  'root': '',
  'file': 'files/',
  'sharedpref': 'shared_prefs/',
  'database': 'databases/',
};

String _withoutComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// The exclusions inside `<name>…</name>`, rooted, in the domains
/// [_domainFolders] names; an empty list for `<name/>`, null when there is no
/// such section.
List<String>? _section(String xml, String name) {
  if (RegExp('<$name\\b[^>]*/>').hasMatch(xml)) return const [];
  final match = RegExp('<$name\\b[^>]*>([\\s\\S]*?)</$name>').firstMatch(xml);
  if (match == null) return null;
  return [
    for (final tag in RegExp(r'<exclude\b[^>]*>').allMatches(match[1]!))
      ...?_excludeOf(tag[0]!),
  ];
}

/// The paths under the data directory that an `<exclude>` tag leaves out:
/// its path in its domain's folder and, for a `sharedpref` name without
/// `.xml`, its file too, as Android reads it; null for another domain.
List<String>? _excludeOf(String tag) {
  final domain = _attribute(tag, 'domain');
  final folder = _domainFolders[domain];
  final path = _attribute(tag, 'path');
  if (folder == null || path == null) return null;
  final rooted = '$folder${_bare(path)}';
  return [
    rooted,
    if (domain == 'sharedpref' &&
        _bare(path).isNotEmpty &&
        !path.endsWith('/') &&
        !path.endsWith('.xml'))
      '$rooted.xml',
  ];
}

/// [path] without a leading `./`; `.` is the domain itself.
String _bare(String path) {
  var p = path.trim();
  while (p.startsWith('./')) {
    p = p.substring(2);
  }
  return p == '.' ? '' : p;
}

String? _attribute(String tag, String name) =>
    RegExp('\\b$name\\s*=\\s*"([^"]*)"').firstMatch(tag)?[1];

/// Whether excluding [exclude] leaves [path] out: the same path, or a folder
/// that holds it (the empty path is the whole data directory).
bool _covers(String exclude, String path) {
  if (exclude.isEmpty) return true;
  final folder = exclude.endsWith('/') ? exclude : '$exclude/';
  return exclude == path || path.startsWith(folder);
}
