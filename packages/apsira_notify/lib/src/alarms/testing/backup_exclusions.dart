// From viaticum test/data/platform/alarm_manager_scheduler_test.dart
// @ 78d38e0 (its check of data_extraction_rules.xml), for every consumer and
// every per-install path (D-APK-022).
import 'dart:io';

import '../alarm_registry.dart';
import '../snooze_store.dart';

/// The per-install paths under app storage the alarm registry defines; an
/// app's Android backup rules must exclude each of them.
const alarmInstallPaths = [AlarmRegistry.defaultPath, SnoozeStore.defaultPath];

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
/// domain) from the cloud backup and from a device-to-device transfer, and
/// that [fullBackupContent] (`full_backup_content`, Android 11 and earlier)
/// excludes them too when the app has one. A [BackupExclusionFailure] names
/// every gap.
///
/// A line scan of `<exclude domain="file" path="…"/>`, comments left out, with
/// no XML dependency: an exclusion of a folder (`alarms/`) covers the files
/// in it. Rules written with `<include>` are not read, so they show as gaps.
void expectExcludedFromDeviceBackup(
  File dataExtractionRules, {
  File? fullBackupContent,
  required Iterable<String> paths,
}) {
  final gaps = backupExclusionGaps(
    dataExtractionRules.readAsStringSync(),
    fullBackupContent: fullBackupContent?.readAsStringSync(),
    paths: paths,
  );
  if (gaps.isNotEmpty) throw BackupExclusionFailure(gaps);
}

/// The gaps [expectExcludedFromDeviceBackup] reports, from the files' text.
List<String> backupExclusionGaps(
  String dataExtractionRules, {
  String? fullBackupContent,
  required Iterable<String> paths,
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
  return [
    for (final path in paths)
      for (final MapEntry(key: name, value: excludes) in sections.entries)
        if (excludes == null)
          '$path: no <$name> section'
        else if (!excludes.any((e) => _covers(e, path)))
          '$path: not excluded in <$name>',
  ];
}

String _withoutComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// The `file` domain exclusions inside `<name>…</name>`; an empty list for
/// `<name/>`, null when there is no such section.
List<String>? _section(String xml, String name) {
  if (RegExp('<$name\\b[^>]*/>').hasMatch(xml)) return const [];
  final match = RegExp('<$name\\b[^>]*>([\\s\\S]*?)</$name>').firstMatch(xml);
  if (match == null) return null;
  return [
    for (final tag in RegExp(r'<exclude\b[^>]*>').allMatches(match[1]!))
      if (_attribute(tag[0]!, 'domain') == 'file') ?_attribute(tag[0]!, 'path'),
  ];
}

String? _attribute(String tag, String name) =>
    RegExp('\\b$name\\s*=\\s*"([^"]*)"').firstMatch(tag)?[1];

/// Whether excluding [exclude] leaves [path] out: the same path, or a folder
/// that holds it.
bool _covers(String exclude, String path) {
  final folder = exclude.endsWith('/') ? exclude : '$exclude/';
  return exclude == path || path.startsWith(folder);
}
