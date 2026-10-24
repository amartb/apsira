// From relay lib/data/platform/local_notifier.dart @ 09b28810, with viaticum
// lib/data/platform/local_notifier.dart @ 78d38e0's ensureChannels and quiet
// channel; the channels are the app's specs and the settings open through
// SystemSettings in place of app_settings (D-APK-021).
import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;

import 'notifier.dart';
import 'system_settings.dart';

/// The [Notifier] on `flutter_local_notifications` (the patched 22.3.2 in
/// `packages/third_party/`), Android only.
///
/// The plugin is initialised on the first call, never at construction, so an
/// app's bootstrap binds it freely; a failed initialisation is tried again on
/// the next call. Initialising hands the plugin [onBackground] when the app
/// has background actions: a top-level `@pragma('vm:entry-point')` function,
/// where the plugin starts a background engine for each background action
/// whether or not the app runs. It takes `Object` so the plugin's types stay
/// in this file; [responseOf] reads it. Taps and the actions that open the
/// app arrive on [responses] while the app runs, and through
/// [launchResponse] when one started it.
///
/// Scheduling (`zonedSchedule`) is not this class's: alarms go through the
/// app's alarm scheduler.
final class LocalNotifier implements Notifier {
  LocalNotifier({
    required this.statusIcon,
    this.onBackground,
    fln.AndroidFlutterLocalNotificationsPlugin? plugin,
    this._settings = const ChannelSystemSettings(),
    this._log,
  }) : _plugin = plugin ?? fln.AndroidFlutterLocalNotificationsPlugin();

  /// The small status-bar icon, a drawable of the app (`ic_stat_relay`,
  /// `@drawable/ic_stat_viaticum`).
  final String statusIcon;

  /// The background entry point of the actions that do not open the app;
  /// null when the app has none.
  final void Function(Object response)? onBackground;

  final fln.AndroidFlutterLocalNotificationsPlugin _plugin;
  final SystemSettings _settings;
  final Log? _log;
  final _responses = StreamController<NotificationResponse>.broadcast();
  Future<void>? _initialized;
  bool _launchAnswered = false;

  Future<void> _ready() => _initialized ??= _plugin
      .initialize(
        settings: fln.AndroidInitializationSettings(statusIcon),
        onDidReceiveNotificationResponse: _onForeground,
        onDidReceiveBackgroundNotificationResponse: onBackground,
      )
      .then<void>(
        (_) {},
        onError: (Object e) {
          _initialized = null;
          throw e;
        },
      );

  void _onForeground(fln.NotificationResponse response) {
    final mapped = responseOf(response);
    if (mapped == null) {
      _log?.warning('notification.responseWithoutId');
      return;
    }
    _responses.add(mapped);
  }

  /// The port's response for the plugin's [response], or null when it is not
  /// one or names no notification. An empty payload is none.
  static NotificationResponse? responseOf(Object response) {
    if (response is! fln.NotificationResponse) return null;
    final id = response.id;
    if (id == null) return null;
    final payload = response.payload;
    return NotificationResponse(
      notificationId: id,
      actionId: response.actionId,
      payload: payload == null || payload.isEmpty ? null : payload,
    );
  }

  static fln.Importance _importance(NotificationImportance importance) =>
      switch (importance) {
        NotificationImportance.low => fln.Importance.low,
        NotificationImportance.defaultImportance =>
          fln.Importance.defaultImportance,
        NotificationImportance.high => fln.Importance.high,
      };

  static fln.Priority _priority(NotificationImportance importance) =>
      switch (importance) {
        NotificationImportance.low => fln.Priority.low,
        NotificationImportance.defaultImportance =>
          fln.Priority.defaultPriority,
        NotificationImportance.high => fln.Priority.high,
      };

  /// The plugin's channel for [spec], as [ensureChannels] creates it.
  static fln.AndroidNotificationChannel channelOf(
    NotificationChannelSpec spec,
  ) => fln.AndroidNotificationChannel(
    spec.id,
    spec.name,
    description: spec.description,
    importance: _importance(spec.importance),
    playSound: !spec.silent,
    enableVibration: !spec.silent,
  );

  /// How [notification] is posted on Android: as its channel, its actions and
  /// its lock-screen version. An alarm adapter that schedules through the
  /// plugin posts with the same details.
  static fln.AndroidNotificationDetails detailsOf(
    AppNotification notification,
  ) {
    final channel = notification.channel;
    return fln.AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: _importance(channel.importance),
      priority: _priority(channel.importance),
      playSound: !channel.silent,
      enableVibration: !channel.silent,
      silent: channel.silent,
      category: switch (channel.category) {
        NotificationCategory.reminder =>
          fln.AndroidNotificationCategory.reminder,
        NotificationCategory.event => fln.AndroidNotificationCategory.event,
        null => null,
      },
      groupKey: notification.group,
      // A private channel's content shows only once the device is unlocked:
      // the lock screen shows the public version (through the patched
      // plugin's publicVersion, RELAY's D-217), else the system's redacted
      // one, the app's name and the time.
      visibility: channel.privateOnLockScreen
          ? fln.NotificationVisibility.private
          : null,
      publicVersion: switch (notification.publicTitle) {
        final title? => fln.AndroidNotificationPublicVersion(title: title),
        null => null,
      },
      // By default a tap opens the app and leaves the notification: the app
      // cancels it once the user has chosen (RELAY's P3-R6).
      autoCancel: notification.dismissOnTap,
      actions: notification.actions.isEmpty
          ? null
          : [
              for (final action in notification.actions)
                fln.AndroidNotificationAction(
                  action.actionId,
                  action.label,
                  showsUserInterface: action.opensApp,
                  cancelNotification: !action.opensApp,
                ),
            ],
    );
  }

  @override
  Future<void> ensureChannels(List<NotificationChannelSpec> channels) async {
    final ids = <String>{};
    for (final channel in channels) {
      if (!ids.add(channel.id)) {
        throw ArgumentError.value(channel.id, 'channels', 'a second spec');
      }
    }
    await _ready();
    for (final channel in channels) {
      await _plugin.createNotificationChannel(channelOf(channel));
    }
  }

  @override
  Future<void> show(AppNotification notification) async {
    if (notification.actions.length > AppNotification.maxActions) {
      throw ArgumentError.value(
        notification.actions.length,
        'actions',
        'Android shows at most ${AppNotification.maxActions}',
      );
    }
    await _ready();
    await _plugin.show(
      id: notification.notificationId,
      title: notification.title,
      body: notification.body,
      payload: notification.payload,
      notificationDetails: detailsOf(notification),
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await _ready();
    await _plugin.cancel(id: notificationId);
  }

  @override
  Stream<NotificationResponse> get responses => _responses.stream;

  /// The launch is answered once: a second call answers null, so a start-up
  /// path that asks twice never runs an action twice. The next start does
  /// not see it again: the plugin reports no launch for an activity started
  /// from recents.
  @override
  Future<NotificationResponse?> launchResponse() async {
    if (_launchAnswered) return null;
    await _ready();
    final details = await _plugin.getNotificationAppLaunchDetails();
    _launchAnswered = true;
    if (details == null || !details.didNotificationLaunchApp) return null;
    final response = details.notificationResponse;
    return response == null ? null : responseOf(response);
  }

  @override
  Future<bool> permissionGranted() async {
    await _ready();
    return await _plugin.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ready();
    return await _plugin.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> openNotificationSettings() =>
      _settings.openNotificationSettings();
}
