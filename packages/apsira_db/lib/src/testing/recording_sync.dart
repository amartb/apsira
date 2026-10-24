// From viaticum test/data/db/rename_durability_test.dart @ 78d38e0 (the
// recorder) and relay test/data/db/restore_swap_test.dart @ 09b28810
// (`syncs`), as one helper (D-APK-018). Plain Dart.
import 'dart:io';

import '../step_hook.dart';

/// A [SyncDirectory] that records each sync, in order, with the steps a
/// hook reports, so a test asserts the durability order (a step, then the
/// sync that makes it durable).
///
/// Pass [call] as `syncDirectory` and [step] as `onStep`. [events] reads
/// `sync:<dir>` (relative to [root], `.` for the root itself, or the base
/// name without one) and `step:<name>`. [failWhen] makes a sync throw a
/// [FileSystemException], as a failed fsync does; [observe] adds what a
/// test wants to see at each sync (the markers present, say).
final class RecordingSync {
  RecordingSync({this.root, this.failWhen, this.observe});

  final Directory? root;

  final bool Function(Directory directory)? failWhen;

  final String Function(Directory directory)? observe;

  final List<String> events = [];

  /// The syncs alone, in order.
  List<String> get syncs => [
    for (final e in events)
      if (e.startsWith('sync:')) e.substring(5),
  ];

  void call(Directory directory) {
    final seen = observe?.call(directory);
    events.add('sync:${_where(directory)}${seen == null ? '' : ' $seen'}');
    if (failWhen?.call(directory) ?? false) {
      throw FileSystemException('injected fsync failure', directory.path);
    }
  }

  /// A step hook that records the step; pass it as `onStep`.
  StepHook get step =>
      (done) => events.add('step:${done is Enum ? done.name : done}');

  String _where(Directory directory) {
    final base = root?.absolute.path;
    final path = directory.absolute.path;
    if (base != null) {
      if (path == base) return '.';
      if (path.startsWith('$base/')) return path.substring(base.length + 1);
    }
    return directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
  }
}
