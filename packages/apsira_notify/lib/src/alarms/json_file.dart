// From viaticum lib/data/platform/alarm_manager_scheduler.dart @ 78d38e0
// (AlarmStore.write: a temporary file, flushed, then renamed).
import 'dart:convert';
import 'dart:io';

/// Replaces [file] with [json], whole: written to `<file>.tmp`, flushed, then
/// renamed over it, so a crash leaves the old file or the new one, never
/// part of either. A leftover `.tmp` is overwritten by the next write and
/// never read. [afterStep] is told `tmpWritten`, then `renamed`.
Future<void> writeJsonWhole(
  File file,
  Object? json, {
  void Function(String step)? afterStep,
}) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(jsonEncode(json), flush: true);
  afterStep?.call('tmpWritten');
  await temp.rename(file.path);
  afterStep?.call('renamed');
}

/// The JSON object in [file], or null when there is no file. A file that is
/// not a JSON object is a [FormatException] naming [what].
Future<Map<String, Object?>?> readJsonObject(File file, String what) async {
  if (!await file.exists()) return null;
  final Object? json;
  try {
    json = jsonDecode(await file.readAsString());
  } on FormatException {
    throw FormatException('$what: not JSON');
  }
  if (json is! Map<String, Object?>) {
    throw FormatException('$what: not a JSON object');
  }
  return json;
}
