// The consumer requirements (D-APK-016, AC-11.6) as the example meets them:
// from relay test/data/platform/local_auth_authenticator_test.dart @
// 09b28810's MainActivity check, with the USE_BIOMETRIC permission beside it,
// and the plugin's registration on the package's own channel.
import 'dart:io';

import 'package:apsira_lock/apsira_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const example = 'example/android/app/src/main';

  test('the example MainActivity is a FlutterFragmentActivity, which '
      'local_auth needs', () {
    final source = File(
      '$example/kotlin/com/apsiralabs/apsira_lock_example/MainActivity.kt',
    ).readAsStringSync();
    expect(
      source,
      contains('import io.flutter.embedding.android.FlutterFragmentActivity'),
    );
    expect(
      source,
      matches(RegExp(r'class MainActivity\s*:\s*FlutterFragmentActivity\(\)')),
    );
  });

  test('the example manifest declares USE_BIOMETRIC', () {
    expect(
      File('$example/AndroidManifest.xml').readAsStringSync(),
      contains(
        '<uses-permission android:name="android.permission.USE_BIOMETRIC" />',
      ),
    );
  });

  test('the Kotlin answers on the channel the Dart side calls', () {
    final kotlin = File(
      'android/src/main/kotlin/com/apsiralabs/apsira_lock/'
      'ScreenPrivacyModule.kt',
    ).readAsStringSync();
    expect(
      kotlin,
      contains('const val CHANNEL = "${FlagSecureScreenPrivacy.channelName}"'),
    );
    expect(kotlin, contains('"setHidden"'));
    expect(kotlin, contains('FLAG_SECURE'));
  });
}
