// From relay test/fakes/fake_alarm_scheduler.dart @ 09b28810 and viaticum
// test/fakes/fake_alarm_scheduler.dart @ 78d38e0, on the registry's platform
// ids (D-APK-022).
import '../alarm_scheduler.dart';

/// Records the platform's alarms so tests can assert what would ring.
///
/// [armed] is the platform's own list, by platform id: [schedule] replaces by
/// id, [cancel] removes, [fire] takes one out as it goes off, and [forgetAll]
/// is a reboot that lost every alarm.
final class FakeAlarmScheduler implements AlarmScheduler {
  /// What is armed, by platform id: what would ring.
  final Map<int, RegisteredAlarm> armed = {};

  /// Every alarm [schedule] armed, in order.
  final List<RegisteredAlarm> scheduled = [];

  /// Every platform id [cancel] was called with, in order.
  final List<int> cancelled = [];

  /// Every alarm that went off through [fire], in order.
  final List<RegisteredAlarm> fired = [];

  /// What [canScheduleExact] answers; tests flip it to simulate the system
  /// revoking exact alarms.
  bool exactAllowed = true;

  /// Whether [schedule] refuses [alarm], as the platform may; never by
  /// default.
  bool Function(RegisteredAlarm alarm) refuses = _never;

  /// How many times the battery-optimisation settings were opened.
  int batterySettingsOpened = 0;

  static bool _never(RegisteredAlarm _) => false;

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<bool> schedule(RegisteredAlarm alarm) async {
    if (!RegisteredAlarm.isValidPlatformId(alarm.platformId)) {
      throw ArgumentError.value(alarm.platformId, 'platformId');
    }
    if (refuses(alarm)) return false;
    scheduled.add(alarm);
    armed[alarm.platformId] = alarm;
    return true;
  }

  @override
  Future<void> cancel(int platformId) async {
    cancelled.add(platformId);
    armed.remove(platformId);
  }

  /// The alarm armed under [platformId] goes off: it leaves [armed].
  RegisteredAlarm fire(int platformId) {
    final alarm = armed.remove(platformId);
    if (alarm == null) throw StateError('nothing armed under $platformId');
    fired.add(alarm);
    return alarm;
  }

  /// A reboot, or a fresh phone: the platform holds no alarm.
  void forgetAll() => armed.clear();

  @override
  Future<void> openBatteryOptimisationSettings() async =>
      batterySettingsOpened++;
}
