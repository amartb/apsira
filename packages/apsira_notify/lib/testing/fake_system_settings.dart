import '../src/system_settings.dart';

/// Counts the settings screens opened.
final class FakeSystemSettings implements SystemSettings {
  int notificationSettingsOpened = 0;
  int batterySettingsOpened = 0;
  int appDetailsOpened = 0;

  @override
  Future<void> openNotificationSettings() async => notificationSettingsOpened++;

  @override
  Future<void> openBatteryOptimisationSettings() async =>
      batterySettingsOpened++;

  @override
  Future<void> openAppDetails() async => appDetailsOpened++;
}
