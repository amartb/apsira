// From relay test/fakes/fake_notifier.dart @ 09b28810, with the channels
// VIATICUM's ensureChannels creates (D-APK-021).
import 'dart:async';

import '../src/notifier.dart';

/// Records shown notifications and channels, and lets tests tap them.
class FakeNotifier implements Notifier {
  /// The notifications showing, by ID.
  final Map<int, AppNotification> showing = {};

  /// The channels created, by ID.
  final Map<String, NotificationChannelSpec> channels = {};

  final _responses = StreamController<NotificationResponse>.broadcast();

  /// What [launchResponse] answers once: the tap that started the app.
  NotificationResponse? launchedBy;

  /// Whether `POST_NOTIFICATIONS` is granted, and what a request grants.
  bool granted = true;
  bool grantOnRequest = true;

  /// How many times the permission was asked for, and the notification
  /// settings opened.
  int permissionRequests = 0;
  int settingsOpened = 0;

  /// Simulates the user tapping a notification or one of its actions while
  /// the app runs.
  void tap(int notificationId, {String? actionId, String? payload}) =>
      _responses.add(
        NotificationResponse(
          notificationId: notificationId,
          actionId: actionId,
          payload: payload,
        ),
      );

  Future<void> dispose() => _responses.close();

  @override
  Future<void> ensureChannels(List<NotificationChannelSpec> specs) async {
    final ids = {for (final spec in specs) spec.id};
    if (ids.length != specs.length) {
      throw ArgumentError.value(specs, 'channels', 'two specs with one id');
    }
    for (final spec in specs) {
      channels[spec.id] = spec;
    }
  }

  @override
  Future<void> show(AppNotification notification) async {
    if (notification.actions.length > AppNotification.maxActions) {
      throw ArgumentError.value(notification.actions.length, 'actions');
    }
    showing[notification.notificationId] = notification;
  }

  @override
  Future<void> cancel(int notificationId) async =>
      showing.remove(notificationId);

  @override
  Stream<NotificationResponse> get responses => _responses.stream;

  @override
  Future<NotificationResponse?> launchResponse() async {
    final response = launchedBy;
    launchedBy = null;
    return response;
  }

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted = granted || grantOnRequest;
  }

  @override
  Future<void> openNotificationSettings() async => settingsOpened++;
}
