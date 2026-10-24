// From relay test/data/platform/fln_public_version_test.dart @ 09b28810,
// unchanged but for this header: the patch now lives in
// packages/third_party/flutter_local_notifications (D-APK-021).
// The RELAY PATCH of flutter_local_notifications (R-10, D-217, its
// RELAY_PATCH.md), in the plugin's own test style:
// `AndroidNotificationDetails.publicVersion` reaches the method channel's
// `platformSpecifics` as `publicVersionTitle` and `publicVersionBody`, which
// the Java side builds into `NotificationCompat.Builder.setPublicVersion`;
// without one, the map is the published plugin's.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  TestWidgetsFlutterBinding.ensureInitialized();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  group('Android public version (RELAY PATCH, R-10)', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final log = <MethodCall>[];

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            log.add(methodCall);
            return methodCall.method == 'initialize' ? true : null;
          });
    });

    tearDown(() {
      log.clear();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<Map<Object?, Object?>> shown(
      AndroidNotificationDetails details,
    ) async {
      await flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('app_icon'),
        ),
      );
      await flutterLocalNotificationsPlugin.show(
        id: 1,
        title: 'Call the bank',
        body: 'Due today at 18:55',
        notificationDetails: NotificationDetails(android: details),
      );
      final call = log.lastWhere((c) => c.method == 'show');
      return (call.arguments as Map)['platformSpecifics'] as Map;
    }

    test('show carries the public version\'s title and body', () async {
      final android = await shown(
        const AndroidNotificationDetails(
          'channelId',
          'channelName',
          visibility: NotificationVisibility.private,
          publicVersion: AndroidNotificationPublicVersion(
            title: 'Reminder · 18:55',
            body: 'Relay',
          ),
        ),
      );
      expect(android['publicVersionTitle'], 'Reminder · 18:55');
      expect(android['publicVersionBody'], 'Relay');
      expect(android['visibility'], NotificationVisibility.private.index);
    });

    test('a public version without a body sends only its title', () async {
      final android = await shown(
        const AndroidNotificationDetails(
          'channelId',
          'channelName',
          publicVersion: AndroidNotificationPublicVersion(
            title: 'Recordatorio · 07:05',
          ),
        ),
      );
      expect(android['publicVersionTitle'], 'Recordatorio · 07:05');
      expect(android.containsKey('publicVersionBody'), isTrue);
      expect(android['publicVersionBody'], isNull);
    });

    test('without a public version the map is the published plugin\'s: no '
        'public-version keys', () async {
      final android = await shown(
        const AndroidNotificationDetails('channelId', 'channelName'),
      );
      expect(android.containsKey('publicVersionTitle'), isFalse);
      expect(android.containsKey('publicVersionBody'), isFalse);
    });
  });
}
