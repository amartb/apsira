// ChannelSystemSettings (D-APK-021, ruling R-2 Q4-c) against a mocked
// channel: the package's own `apsira_notify/settings` in place of
// app_settings. The Kotlin half (NotifySettingsModule.kt) answers the three
// methods; example_android_test.dart checks it names the same ones.
import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apsira_notify/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  void answer(Object? Function(MethodCall call) reply) =>
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return reply(call);
      });

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('the channel is the package\'s own', () {
    expect(ChannelSystemSettings.channelName, 'apsira_notify/settings');
  });

  test('each screen is one method, with no argument', () async {
    answer((_) => null);
    const settings = ChannelSystemSettings();
    await settings.openNotificationSettings();
    await settings.openBatteryOptimisationSettings();
    await settings.openAppDetails();
    expect(calls.map((c) => (c.method, c.arguments)), [
      ('openNotificationSettings', null),
      ('openBatteryOptimisationSettings', null),
      ('openAppDetails', null),
    ]);
  });

  test('no activity attached: the platform error reaches the caller', () {
    answer((_) => throw PlatformException(code: 'noActivity', message: 'none'));
    expect(
      const ChannelSystemSettings().openAppDetails(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'noActivity'),
      ),
    );
  });

  test('anywhere but Android (no plugin): UnsupportedError', () {
    expect(
      const ChannelSystemSettings().openNotificationSettings(),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('the fake counts each screen', () async {
    final fake = FakeSystemSettings();
    await fake.openNotificationSettings();
    await fake.openBatteryOptimisationSettings();
    await fake.openBatteryOptimisationSettings();
    await fake.openAppDetails();
    expect(
      (
        fake.notificationSettingsOpened,
        fake.batterySettingsOpened,
        fake.appDetailsOpened,
      ),
      (1, 2, 1),
    );
  });
}
