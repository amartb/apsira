// From relay lib/domain/reminders/window.dart @ 09b28810 (the window and its
// plan), with viaticum lib/domain/reminders/window.dart @ 78d38e0's string
// alarm ids; the platform ids are the registry's, not RELAY's FNV request
// codes, and every alarm in the window is armed again (D-APK-022).
import 'alarm_scheduler.dart';

/// How many alarms the window arms: well under Android's 500 per app.
const reminderWindowSize = 100;

/// The [size] nearest of [wanted], by instant, then by alarm id. A fire
/// already past is the nearest of all: on the alarm manager it goes off at
/// once.
List<ScheduledAlarm> nearestFires(
  Iterable<ScheduledAlarm> wanted, {
  int size = reminderWindowSize,
}) {
  final sorted = [...wanted]
    ..sort((a, b) {
      final byTime = a.atUtc.compareTo(b.atUtc);
      return byTime != 0 ? byTime : a.alarmId.compareTo(b.alarmId);
    });
  return sorted.take(size).toList();
}

/// What a resync does to the platform: every entry of [cancel] is cancelled
/// (and then unregistered) before any alarm of [arm] is registered and armed.
final class AlarmPlan {
  const AlarmPlan({required this.cancel, required this.arm});

  /// The registry's entries outside the window.
  final List<RegisteredAlarm> cancel;

  /// The whole window, unchanged alarms included: both platforms replace an
  /// alarm by id, so arming again costs nothing and a copied or stale
  /// registry can never hide an unarmed alarm.
  final List<ScheduledAlarm> arm;
}

/// The plan from [registered] (every registry entry) to the window of
/// [wanted]: an entry whose alarm id is in the window stays registered under
/// its platform id; every other entry is cancelled.
AlarmPlan planAlarms({
  required Iterable<ScheduledAlarm> wanted,
  required Iterable<RegisteredAlarm> registered,
  int size = reminderWindowSize,
}) {
  final window = nearestFires(wanted, size: size);
  final ids = {for (final a in window) a.alarmId};
  return AlarmPlan(
    cancel: [
      for (final entry in registered)
        if (!ids.contains(entry.alarmId)) entry,
    ],
    arm: window,
  );
}
