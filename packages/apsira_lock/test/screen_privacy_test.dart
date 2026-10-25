// FlagSecureScreenPrivacy (D-APK-016, ruling R-1 Q3): RELAY's port of
// relay lib/data/platform/screen_privacy.dart @ 09b28810 on the package's own
// channel `apsira_lock/screen_privacy`, against a mocked channel. The Kotlin
// half (ScreenPrivacyModule.kt) answers `setHidden` with a bool argument.
import 'package:apsira_lock/apsira_lock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apsira_lock/screen_privacy');
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
    expect(FlagSecureScreenPrivacy.channelName, 'apsira_lock/screen_privacy');
  });

  test(
    'hiding sends setHidden(true); showing sends setHidden(false)',
    () async {
      answer((_) => null);
      const privacy = FlagSecureScreenPrivacy();
      await privacy.setHidden(true);
      await privacy.setHidden(false);
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('setHidden', true),
        ('setHidden', false),
      ]);
    },
  );

  test('no activity attached: the platform error reaches the caller', () {
    answer((_) => throw PlatformException(code: 'noActivity', message: 'none'));
    expect(
      const FlagSecureScreenPrivacy().setHidden(true),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'noActivity'),
      ),
    );
  });

  test('anywhere but Android (no plugin): UnsupportedError', () {
    expect(
      const FlagSecureScreenPrivacy().setHidden(true),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
