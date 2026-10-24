// From lyceum lib/data/platform/notification_service.dart @ 9f4ff27
// (LocalNotifier.schedule and cancel: zonedSchedule in UTC, exact while idle,
// a past time dropped), with the registry's platform ids and RELAY's
// notification details (D-APK-022).
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/timezone.dart' as tz;

import '../local_notifier.dart';
import '../notifier.dart';
import '../system_settings.dart';
import 'alarm_scheduler.dart';

/// Builds the notification an alarm posts when it fires: its texts, channel,
/// actions and lock-screen version, under [RegisteredAlarm.platformId].
typedef AlarmNotificationBuilder = AppNotification Function(
  RegisteredAlarm alarm,
);

/// The [AlarmScheduler] on the notification plugin's own scheduling
/// (`zonedSchedule`), as LYCEUM schedules its alerts (its D-034): the system
/// posts the notification at the alarm's time, exact while idle, with no
/// engine of the app's running. Android only.
///
/// - The notification's id is the registry's platform id, so a response
///   names the alarm, and the payload is the alarm id unless the builder
///   sets one.
/// - A time that is not ahead is skipped ([schedule] answers false): the
///   plugin refuses a past date, and the platform never posts one late; an
///   `AlarmSync` for this scheduler takes `lateGrace: Duration.zero`.
/// - [cancel] cancels an alarm still pending only: the plugin's `cancel` also
///   removes a notification already showing, which stays until the user or
///   the app dismisses it.
final class FlnAlarmScheduler implements AlarmScheduler {
  FlnAlarmScheduler({
    required this._notificationOf,
    fln.AndroidFlutterLocalNotificationsPlugin? plugin,
    this._ready,
    this._settings = const ChannelSystemSettings(),
    DateTime Function()? now,
  }) : _plugin = plugin ?? fln.AndroidFlutterLocalNotificationsPlugin(),
       _now = now ?? _utcNow;

  final AlarmNotificationBuilder _notificationOf;
  final fln.AndroidFlutterLocalNotificationsPlugin _plugin;

  /// Run before every plugin call: the app's `LocalNotifier` initialises the
  /// plugin (`ensureChannels`), which this class never does, so the app's
  /// response callbacks stay the ones it set.
  final Future<void> Function()? _ready;
  final SystemSettings _settings;
  final DateTime Function() _now;

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Future<bool> canScheduleExact() async {
    await _ready?.call();
    return await _plugin.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> schedule(RegisteredAlarm alarm) async {
    if (!RegisteredAlarm.isValidPlatformId(alarm.platformId)) {
      throw ArgumentError.value(alarm.platformId, 'platformId');
    }
    if (!alarm.atUtc.isUtc) {
      throw ArgumentError.value(alarm.atUtc, 'atUtc', 'must be UTC');
    }
    if (!alarm.atUtc.isAfter(_now())) return false;
    final notification = _notificationOf(alarm);
    if (notification.notificationId != alarm.platformId) {
      throw ArgumentError.value(
        notification.notificationId,
        'notificationId',
        'must be the alarm\'s platform id ${alarm.platformId}',
      );
    }
    if (notification.actions.length > AppNotification.maxActions) {
      throw ArgumentError.value(
        notification.actions.length,
        'actions',
        'Android shows at most ${AppNotification.maxActions}',
      );
    }
    await _ready?.call();
    await _plugin.zonedSchedule(
      id: alarm.platformId,
      title: notification.title,
      body: notification.body,
      scheduledDate: tz.TZDateTime.from(alarm.atUtc, tz.UTC),
      payload: notification.payload ?? alarm.alarmId,
      notificationDetails: LocalNotifier.detailsOf(notification),
      scheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
    return true;
  }

  @override
  Future<void> cancel(int platformId) async {
    await _ready?.call();
    final pending = await _plugin.pendingNotificationRequests();
    if (pending.any((p) => p.id == platformId)) {
      await _plugin.cancel(id: platformId);
    }
  }

  @override
  Future<void> openBatteryOptimisationSettings() =>
      _settings.openBatteryOptimisationSettings();
}
