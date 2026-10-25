// From relay lib/data/platform/alarm_manager_scheduler.dart @ 09b28810 (the
// adapter: exact, waking, allowed while idle, re-armed after a reboot, the
// alarm-clock fallback, a refusal answered false) and viaticum
// lib/data/platform/alarm_manager_scheduler.dart @ 78d38e0 (the params a fire
// gets, onAlarmFired); the registry is apsira_notify's and the platform ids
// its own (D-APK-022, ruling R-1 Q1-c). The plugin's reboot list is read
// through the package's own channel (F1). The fire's cancel is left out for
// an id armed again meanwhile (F6, D-APK-022).
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter/services.dart';

/// The [AlarmScheduler] on `android_alarm_manager_plus`: each alarm is one
/// exact alarm (`setExactAndAllowWhileIdle`), waking the device, re-armed by
/// the plugin's boot receiver after a reboot, under the registry's platform
/// id. RELAY and VIATICUM; LYCEUM schedules through the notification plugin
/// (`FlnAlarmScheduler`), so this plugin stays out of its APK.
///
/// A fire starts a background engine at the app's [onFire]: a top-level
/// `@pragma('vm:entry-point')` function taking the platform id and the
/// params map (or only the id, as RELAY's did), which calls
/// [onAlarmFired] with the params [alarmParams] gave the plugin. The plugin's
/// service starts on the first schedule; nothing touches a channel at
/// construction, so an app's bootstrap binds it freely.
final class AlarmManagerScheduler implements AlarmScheduler {
  AlarmManagerScheduler(
    this.onFire, {
    this.alarmClock = false,
    Future<bool> Function()? canScheduleExact,
    this._settings = const ChannelSystemSettings(),
  }) : _canScheduleExact = canScheduleExact ?? _exactAlwaysAllowed;

  /// The fire entry (see the class comment).
  final Function onFire;

  /// The package's channel to the plugin's reboot list: `persistentAlarmIds`
  /// answers the ids in `persistent_alarm_ids` of the plugin's
  /// SharedPreferences file (`ApsiraJobsPlugin.kt`).
  static const listChannel = MethodChannel('apsira_jobs/alarms');

  /// RELAY's fallback (its ruling P3-R3): alarms set as alarm clocks
  /// (`setAlarmClock`), which Doze never defers, at the cost of the alarm
  /// icon in the status bar. Off by default.
  final bool alarmClock;

  final Future<bool> Function() _canScheduleExact;
  final SystemSettings _settings;
  Future<bool>? _started;

  /// `USE_EXACT_ALARM` is granted at install and cannot be revoked, so exact
  /// alarms are allowed unless the app answers otherwise (VIATICUM asks the
  /// notification plugin).
  static Future<bool> _exactAlwaysAllowed() async => true;

  Future<bool> _ready() => _started ??= AndroidAlarmManager.initialize().then(
    (started) {
      if (!started) _started = null;
      return started;
    },
    onError: (Object e) {
      _started = null;
      throw e;
    },
  );

  @override
  Future<bool> canScheduleExact() => _canScheduleExact();

  @override
  Future<bool> schedule(RegisteredAlarm alarm) async {
    // The plugin only asserts the range, and asserts are off in release.
    if (!RegisteredAlarm.isValidPlatformId(alarm.platformId)) {
      throw ArgumentError.value(
        alarm.platformId,
        'platformId',
        'not a non-negative 31-bit integer',
      );
    }
    if (!alarm.atUtc.isUtc) {
      throw ArgumentError.value(alarm.atUtc, 'atUtc', 'must be UTC');
    }
    if (!await _ready()) return false;
    return AndroidAlarmManager.oneShotAt(
      alarm.atUtc,
      alarm.platformId,
      onFire,
      alarmClock: alarmClock,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: alarmParams(alarm),
    );
  }

  /// The plugin's `cancel`: besides the system alarm it removes the alarm
  /// from the plugin's own list (app-private SharedPreferences) that its boot
  /// receiver re-arms. It is the only call that prunes that list, so a fired
  /// alarm is cancelled by [onAlarmFired] and every other by `AlarmSync`.
  @override
  Future<void> cancel(int platformId) => AndroidAlarmManager.cancel(platformId);

  /// The ids on the plugin's reboot list (`persistent_alarm_ids`): every
  /// alarm this scheduler arms is on it until [cancel] or the fire's cancel,
  /// and a backup that copied the plugin's prefs file brings another
  /// install's. Read without starting the plugin.
  @override
  Future<Set<int>> pendingPlatformIds() async => {
    ...?await listChannel.invokeListMethod<int>('persistentAlarmIds'),
  };

  @override
  Future<void> openBatteryOptimisationSettings() =>
      _settings.openBatteryOptimisationSettings();
}

/// What an alarm hands its fire: its id, instant and content, so the
/// background engine delivers it with no database. The plugin keeps them
/// for its boot receiver in app-private storage.
Map<String, Object?> alarmParams(RegisteredAlarm alarm) => {
  'alarmId': alarm.alarmId,
  'atUtcMs': alarm.atUtc.millisecondsSinceEpoch,
  ...alarm.content,
};

/// The alarm back from [alarmParams]; a [FormatException] when its id or
/// instant is missing.
ScheduledAlarm alarmFromParams(Map<String, Object?> params) {
  final id = params['alarmId'];
  final ms = params['atUtcMs'];
  if (id is! String || ms is! int) {
    throw const FormatException('not an alarm\'s params');
  }
  return ScheduledAlarm(
    alarmId: id,
    atUtc: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    content: {
      for (final MapEntry(:key, :value) in params.entries)
        if (!reservedAlarmKeys.contains(key)) key: value,
    },
  );
}

/// At fire time, in the background engine: records the fire first
/// ([AlarmRegistry.markFired]), so a resync never arms it again at that
/// instant even if delivering fails; then runs [deliver] (the app shows the
/// alarm's notification); then cancels the platform alarm, which drops it
/// from the plugin's reboot list. Each step runs whatever the one before
/// did; the first failure is thrown at the end. Params that are not an
/// alarm's are a [FormatException] before anything happens.
///
/// An alarm id keeps its platform id while it stays registered, so an id may
/// serve several fires (a snooze, `AlarmSync.snooze`, re-arms the same id;
/// VIATICUM's ids name a day, not an instant). When the registry holds
/// [platformId] at another instant than this fire's by the time [deliver]
/// is done (the next fire was registered, and so armed or about to be,
/// meanwhile: a +10 min tapped on the notification, a resync), the cancel
/// is left out: `oneShotAt` under that id already replaced the fired alarm
/// on the reboot list, and the cancel would drop the next fire (D-APK-022).
/// A registry that cannot be read leaves the cancel in.
Future<void> onAlarmFired({
  required int platformId,
  required Map<String, dynamic> params,
  required DateTime firedUtc,
  required AlarmRegistry registry,
  required Future<void> Function(ScheduledAlarm alarm) deliver,
}) async {
  final alarm = alarmFromParams(params);
  Object? failure;
  StackTrace? stack;
  Future<void> step(Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (e, s) {
      failure ??= e;
      stack ??= s;
    }
  }

  await step(
    () => registry.markFired(
      FiredAlarm(
        alarmId: alarm.alarmId,
        platformId: platformId,
        scheduledAtUtc: alarm.atUtc,
        firedAtUtc: firedUtc,
      ),
    ),
  );
  await step(() => deliver(alarm));
  await step(() async {
    if (await _armedAgain(registry, platformId, alarm.atUtc)) return;
    await AndroidAlarmManager.cancel(platformId);
  });
  if (failure case final e?) Error.throwWithStackTrace(e, stack!);
}

/// Whether [registry] holds [platformId] at another instant than [firedAtUtc]:
/// its next fire. False when the registry cannot be read.
Future<bool> _armedAgain(
  AlarmRegistry registry,
  int platformId,
  DateTime firedAtUtc,
) async {
  try {
    return (await registry.entries()).any(
      (e) => e.platformId == platformId && e.atUtc != firedAtUtc,
    );
  } on Object {
    return false;
  }
}
