// From relay lib/core/ports/alarm_scheduler.dart @ 09b28810 (the port) and
// viaticum lib/core/ports/alarm_scheduler.dart @ 78d38e0 (string alarm ids,
// the fire-time content); the platform id is the registry's (D-APK-022).

/// Exact alarms on the platform: `FlnAlarmScheduler` (the notification
/// plugin's own scheduling, LYCEUM) here, and `AlarmManagerScheduler` in
/// `apsira_jobs` (RELAY, VIATICUM).
///
/// The port keeps no list of what it armed: the per-install `AlarmRegistry`
/// is that list, and `AlarmSync` is its only caller. The plugin underneath
/// keeps its own ([pendingPlatformIds]), which a backup may carry to another
/// install; `AlarmSync` cancels every id in it that the registry never
/// handed out, so the app arms no alarm of that plugin outside `AlarmSync`.
abstract interface class AlarmScheduler {
  /// Whether the system currently allows exact alarms.
  Future<bool> canScheduleExact();

  /// Arms [alarm] under its [RegisteredAlarm.platformId], replacing any alarm
  /// armed under that id. False when the platform refused or skipped it.
  Future<bool> schedule(RegisteredAlarm alarm);

  /// Cancels the alarm armed under [platformId]; cancelling one that is not
  /// armed does nothing.
  Future<void> cancel(int platformId);

  /// The platform ids the plugin holds pending and re-arms after a reboot:
  /// its persisted list (the notification plugin's `scheduled_notifications`,
  /// the alarm manager's `persistent_alarm_ids`), which Android's backup and
  /// a device transfer copy unless the app's rules exclude it (D-APK-022).
  Future<Set<int>> pendingPlatformIds();

  /// Opens the system's battery-optimisation settings, where the user exempts
  /// the app when its alarms arrive late.
  Future<void> openBatteryOptimisationSettings();
}

/// The registry's own keys in an entry; [ScheduledAlarm.content] may use none.
const reservedAlarmKeys = {'alarmId', 'atUtcMs', 'platformId'};

/// An alarm the app wants: [alarmId] fires at [atUtc], a UTC instant.
///
/// [content] is what the fire needs and the app's alone (VIATICUM's channel,
/// title and body, already localised); it is stored in the registry and
/// handed to the fire, never logged. Its values are JSON values.
final class ScheduledAlarm {
  const ScheduledAlarm({
    required this.alarmId,
    required this.atUtc,
    this.content = const {},
  });

  /// Stable per fire, and unique among the app's alarms.
  final String alarmId;
  final DateTime atUtc;
  final Map<String, Object?> content;

  /// An [ArgumentError] when [atUtc] is not UTC or [content] uses a key of
  /// the registry's own.
  void validate() {
    if (!atUtc.isUtc) {
      throw ArgumentError.value(atUtc, 'atUtc', 'must be UTC');
    }
    for (final key in content.keys) {
      if (reservedAlarmKeys.contains(key)) {
        throw ArgumentError.value(key, 'content', 'a key of the registry');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduledAlarm &&
      other.alarmId == alarmId &&
      other.atUtc == atUtc &&
      _sameContent(other.content, content);

  @override
  int get hashCode => Object.hash(alarmId, atUtc, content.length);

  /// Prints the id and time only: content is never logged.
  @override
  String toString() => 'ScheduledAlarm($alarmId at ${atUtc.toIso8601String()})';
}

/// An alarm in the registry and the platform id it is armed under.
final class RegisteredAlarm {
  const RegisteredAlarm({
    required this.alarmId,
    required this.platformId,
    required this.atUtc,
    this.content = const {},
  });

  /// The largest platform id: Android takes a 32-bit signed request code,
  /// and the registry hands out non-negative ones.
  static const maxPlatformId = 0x7fffffff;

  /// Whether the platform takes [id].
  static bool isValidPlatformId(int id) => id >= 0 && id <= maxPlatformId;

  final String alarmId;
  final int platformId;
  final DateTime atUtc;
  final Map<String, Object?> content;

  /// The wanted alarm it arms.
  ScheduledAlarm get alarm =>
      ScheduledAlarm(alarmId: alarmId, atUtc: atUtc, content: content);

  @override
  bool operator ==(Object other) =>
      other is RegisteredAlarm &&
      other.alarmId == alarmId &&
      other.platformId == platformId &&
      other.atUtc == atUtc &&
      _sameContent(other.content, content);

  @override
  int get hashCode => Object.hash(alarmId, platformId, atUtc);

  @override
  String toString() =>
      'RegisteredAlarm($alarmId #$platformId at ${atUtc.toIso8601String()})';
}

/// An alarm that went off: ids and times only.
final class FiredAlarm {
  const FiredAlarm({
    required this.alarmId,
    required this.platformId,
    required this.scheduledAtUtc,
    required this.firedAtUtc,
  });

  final String alarmId;
  final int platformId;
  final DateTime scheduledAtUtc;
  final DateTime firedAtUtc;

  @override
  bool operator ==(Object other) =>
      other is FiredAlarm &&
      other.alarmId == alarmId &&
      other.platformId == platformId &&
      other.scheduledAtUtc == scheduledAtUtc &&
      other.firedAtUtc == firedAtUtc;

  @override
  int get hashCode =>
      Object.hash(alarmId, platformId, scheduledAtUtc, firedAtUtc);
}

bool _sameContent(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || !_sameValue(b[key], value)) return false;
  }
  return true;
}

bool _sameValue(Object? a, Object? b) {
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _sameValue(a[k], b[k]));
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
