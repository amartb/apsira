// The consumer requirements (D-APK-021, AC-16.5) as the example meets them:
// POST_NOTIFICATIONS in its manifest, the Java library desugaring the
// vendored flutter_local_notifications needs, and the plugin's Kotlin on the
// channel and methods the Dart side calls (ChannelSystemSettings).
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const example = 'example/android/app';

  test('the example manifest declares POST_NOTIFICATIONS', () {
    expect(
      File('$example/src/main/AndroidManifest.xml').readAsStringSync(),
      contains(
        '<uses-permission '
        'android:name="android.permission.POST_NOTIFICATIONS" />',
      ),
    );
  });

  test('the example enables core library desugaring, which '
      'flutter_local_notifications needs', () {
    final gradle = File('$example/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(
      gradle,
      contains('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:'),
    );
  });

  test('the Kotlin answers the three methods on the channel the Dart side '
      'calls, with the intents app_settings starts', () {
    final kotlin = File(
      'android/src/main/kotlin/com/apsiralabs/apsira_notify/'
      'NotifySettingsModule.kt',
    ).readAsStringSync();
    expect(
      kotlin,
      contains('const val CHANNEL = "${ChannelSystemSettings.channelName}"'),
    );
    for (final method in [
      'openNotificationSettings',
      'openBatteryOptimisationSettings',
      'openAppDetails',
    ]) {
      expect(kotlin, contains('"$method"'), reason: method);
    }
    for (final intent in [
      'ACTION_APP_NOTIFICATION_SETTINGS',
      'ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      'ACTION_APPLICATION_DETAILS_SETTINGS',
    ]) {
      expect(kotlin, contains('Settings.$intent'), reason: intent);
    }
  });

  test('the package depends on no app_settings (ruling R-2 Q4-c)', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('app_settings:')),
    );
  });
}
