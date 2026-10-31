// From relay lib/features/lock/state/lock_settings.dart @ 09b28810 (the
// record), with relay lib/features/lock/ui/lock_settings_section.dart's
// `lockTimeoutChoices` and `updateLockSettings`. RELAY's stream of its
// `settings` row becomes the app's LockSettingsStore behind
// lockSettingsProvider (D-APK-016): the package never chooses a key.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_controller.dart' show lockLogProvider;
import 'lock_policy.dart';

/// The background times **Lock after** offers, in minutes; 0 is
/// Immediately.
const lockTimeoutOptions = [0, 1, 5, 15, 30];

/// The lock's settings, stored as RELAY's row:
/// `{"enabled": false, "timeoutMinutes": 5, "hideInRecents": false}`.
///
/// A row that is absent, or a field that is missing or of the wrong type,
/// reads as its code default, so the lock is off until the user turns it on
/// (or as the `fallback` given to [LockSettings.fromJson]).
@immutable
final class LockSettings {
  const LockSettings({
    this.enabled = false,
    this.timeoutMinutes = defaultTimeoutMinutes,
    this.hideInRecents = false,
  });

  /// Reads a decoded row; anything unexpected is [fallback]'s (a mandatory
  /// app's store passes `LockPolicy.mandatory.defaults`, so a fresh install
  /// gets 1 minute).
  factory LockSettings.fromJson(
    Object? value, {
    LockSettings fallback = LockSettings.defaults,
  }) {
    if (value is! Map<String, Object?>) return fallback;
    final enabled = value['enabled'];
    final timeout = value['timeoutMinutes'];
    final hide = value['hideInRecents'];
    return LockSettings(
      enabled: enabled is bool ? enabled : fallback.enabled,
      timeoutMinutes: timeout is int && timeout >= 0
          ? timeout
          : fallback.timeoutMinutes,
      hideInRecents: hide is bool ? hide : fallback.hideInRecents,
    );
  }

  /// Off, 5 minutes, shown in recents.
  static const defaults = LockSettings();

  /// The background time after which the app locks again, in minutes.
  static const defaultTimeoutMinutes = 5;

  /// Whether the app locks on launch and after [timeout] in the background.
  final bool enabled;

  /// 0 locks as soon as the app goes to the background.
  final int timeoutMinutes;

  /// Applied to the ScreenPrivacy port by `RecentsPrivacy`, whether the
  /// lock is on or not; the lock's own decisions ignore it.
  final bool hideInRecents;

  Duration get timeout => Duration(minutes: timeoutMinutes);

  /// The row, its fields in RELAY's order.
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'timeoutMinutes': timeoutMinutes,
    'hideInRecents': hideInRecents,
  };

  /// [stored] (the row as read, or null) with these settings written over
  /// it: a field a later version added is kept.
  Map<String, Object?> mergeInto(Map<String, Object?>? stored) => {
    ...?stored,
    ...toJson(),
  };

  LockSettings copyWith({
    bool? enabled,
    int? timeoutMinutes,
    bool? hideInRecents,
  }) => LockSettings(
    enabled: enabled ?? this.enabled,
    timeoutMinutes: timeoutMinutes ?? this.timeoutMinutes,
    hideInRecents: hideInRecents ?? this.hideInRecents,
  );

  @override
  bool operator ==(Object other) =>
      other is LockSettings &&
      other.enabled == enabled &&
      other.timeoutMinutes == timeoutMinutes &&
      other.hideInRecents == hideInRecents;

  @override
  int get hashCode => Object.hash(enabled, timeoutMinutes, hideInRecents);

  @override
  String toString() =>
      'LockSettings(enabled: $enabled, timeoutMinutes: $timeoutMinutes, '
      'hideInRecents: $hideInRecents)';
}

/// Where an app keeps the lock's settings, under its own key and in its own
/// format (RELAY: the `lock` row; LYCEUM: `app_lock_enabled`,
/// `auto_lock_minutes`); the package never chooses a key.
abstract interface class LockSettingsStore {
  /// The stored settings; [LockSettings.defaults] when there are none. May
  /// throw when the storage cannot be read: the lock then stays off (under
  /// [LockPolicy.mandatory], on: [MandatoryLockSettingsStore]).
  Future<LockSettings> read();

  /// Stores [settings], keeping any field the app does not know
  /// ([LockSettings.mergeInto]).
  Future<void> write(LockSettings settings);
}

/// The app's [LockSettingsStore]; every app overrides it in its
/// `ProviderScope`. Unbound, the lock never engages (under
/// [LockPolicy.mandatory] it is on with the policy's defaults).
final lockSettingsStoreProvider = Provider<LockSettingsStore>(
  (ref) => throw UnimplementedError('override lockSettingsStoreProvider'),
);

/// The lock settings as read from the store, and the one way the package
/// writes them: the lock controller and hide in recents follow it, and the
/// Settings rows change it through [LockSettingsSetting.change]. An app that
/// changes the stored settings any other way (a restore) invalidates it.
///
/// Under [LockPolicy.mandatory] the app's store is read and written through
/// [MandatoryLockSettingsStore]: the lock is always on, and a read that fails
/// logs `lock.settingsReadFailed` and reads as the policy's defaults.
final lockSettingsProvider =
    AsyncNotifierProvider<LockSettingsSetting, LockSettings>(
      LockSettingsSetting.new,
      // A read that failed is not tried again: the lock stays off (never a
      // lock-out) until the app is started again. A mandatory read never
      // fails.
      retry: (_, _) => null,
    );

/// The lock settings, read once from the app's store.
class LockSettingsSetting extends AsyncNotifier<LockSettings> {
  @override
  Future<LockSettings> build() {
    final policy = ref.watch(lockPolicyProvider);
    if (!policy.isMandatory) return ref.watch(lockSettingsStoreProvider).read();
    return _mandatory(policy, watch: true).read();
  }

  /// The app's store under [policy], wrapped: an unbound store is null.
  LockSettingsStore _mandatory(LockPolicy policy, {bool watch = false}) {
    LockSettingsStore? inner;
    Object? unbound;
    try {
      inner = watch
          ? ref.watch(lockSettingsStoreProvider)
          : ref.read(lockSettingsStoreProvider);
    } catch (e) {
      unbound = e;
    }
    return MandatoryLockSettingsStore(
      inner,
      policy: policy,
      onReadFailed: (error) => _logReadFailed(error ?? unbound),
    );
  }

  void _logReadFailed(Object? error) {
    try {
      ref
          .read(lockLogProvider)
          .warning('lock.settingsReadFailed', error: error);
    } catch (_) {
      // Logging never stops the app.
    }
  }

  /// Writes [edit] of the stored settings, read again first, and follows
  /// it once the write has succeeded. A failed write rethrows and keeps the
  /// settings as they were.
  Future<void> change(LockSettings Function(LockSettings) edit) async {
    final policy = ref.read(lockPolicyProvider);
    final store = policy.isMandatory
        ? _mandatory(policy)
        : ref.read(lockSettingsStoreProvider);
    var next = edit(await store.read());
    if (policy.isMandatory) next = next.copyWith(enabled: true);
    await store.write(next);
    if (ref.mounted) state = AsyncData(next);
  }
}
