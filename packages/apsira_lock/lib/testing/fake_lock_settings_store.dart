// The app's store for tests (D-APK-016): RELAY's `lock` row kept in memory,
// written as relay lib/features/lock/ui/lock_settings_section.dart @ 09b28810's
// updateLockSettings writes it (the fields it does not know kept).
import 'dart:async';

import '../src/lock_settings.dart';

/// Holds the stored row in [row] (null: none). [readError] and [writeError]
/// make [read] and [write] throw; [holdReads] makes reads wait until
/// [releaseReads].
final class FakeLockSettingsStore implements LockSettingsStore {
  FakeLockSettingsStore({this.row, this.readError, this.writeError});

  /// The stored row as JSON; null until something is stored.
  Map<String, Object?>? row;

  /// What [read] throws, when set.
  Object? readError;

  /// What [write] throws, when set.
  Object? writeError;

  /// How many reads were asked for.
  int reads = 0;

  /// Every [write] argument, in order.
  final List<LockSettings> writes = [];

  Completer<void>? _hold;

  /// Makes every read wait until [releaseReads] (a read that hangs).
  void holdReads() => _hold ??= Completer<void>();

  /// Lets the held reads answer.
  void releaseReads() {
    _hold?.complete();
    _hold = null;
  }

  @override
  Future<LockSettings> read() async {
    reads++;
    if (_hold case final hold?) await hold.future;
    if (readError case final error?) throw error;
    return LockSettings.fromJson(row);
  }

  @override
  Future<void> write(LockSettings settings) async {
    if (writeError case final error?) throw error;
    writes.add(settings);
    row = settings.mergeInto(row);
  }
}
