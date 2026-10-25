// From relay lib/data/platform/local_notifier.dart,
// lib/data/platform/alarm_manager_scheduler.dart and
// lib/data/platform/record_audio_recorder.dart @ 09b28810, which opened these
// screens through app_settings; the package's own channel instead (D-APK-021,
// ruling R-2 Q4-c).
import 'package:flutter/services.dart';

/// The system settings screens the apps send the user to.
abstract interface class SystemSettings {
  /// The app's notification settings (its channels and the permission).
  Future<void> openNotificationSettings();

  /// The battery-optimisation list, where the user exempts the app so its
  /// alarms are not delayed.
  Future<void> openBatteryOptimisationSettings();

  /// The app's details page (permissions, storage), as for the microphone.
  Future<void> openAppDetails();
}

/// The [SystemSettings] on the package's Kotlin (`NotifySettingsModule.kt`):
/// one method per screen on the channel [channelName], each starting the
/// intent `app_settings` 9.0.1 starts and falling back to the app's details
/// page when that one cannot start.
///
/// Platform errors (no activity attached: `noActivity`) reach the caller.
/// Anywhere but Android there is no plugin, which is an [UnsupportedError].
final class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings();

  /// The channel the Kotlin half answers on.
  static const channelName = 'apsira_notify/settings';

  static const _channel = MethodChannel(channelName);

  Future<void> _open(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      throw UnsupportedError('The system settings are Android only');
    }
  }

  @override
  Future<void> openNotificationSettings() => _open('openNotificationSettings');

  @override
  Future<void> openBatteryOptimisationSettings() =>
      _open('openBatteryOptimisationSettings');

  @override
  Future<void> openAppDetails() => _open('openAppDetails');
}
