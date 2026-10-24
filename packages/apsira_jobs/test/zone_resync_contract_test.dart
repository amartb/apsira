// The contract between the Android half (android/…/ZoneResync.kt, from relay
// android/app/src/main/kotlin/com/apsiralabs/relay/ZoneModule.kt @ 09b28810)
// and an app's background dispatcher: the job the receiver enqueues and the
// input key its zone arrives under. The Kotlin compiles only in an app's build,
// so this test reads its source and the package manifest.
import 'dart:io';

import 'package:apsira_jobs/apsira_jobs.dart';
import 'package:flutter_test/flutter_test.dart';

const _kotlin =
    'android/src/main/kotlin/com/apsiralabs/apsira_jobs/ZoneResync.kt';
const _manifest = 'android/src/main/AndroidManifest.xml';

void main() {
  test('the job name and input key are the apps\' names', () {
    expect(reminderResyncJob, 'reminderResync');
    expect(zoneIdInputKey, 'zoneId');
  });

  test('the receiver enqueues the same job with the zone under that key', () {
    final source = File(_kotlin).readAsStringSync();
    expect(source, contains('package com.apsiralabs.apsira_jobs'));
    expect(source, contains('const val RESYNC_JOB = "$reminderResyncJob"'));
    expect(
      source,
      contains(
        r'.putString("${PAYLOAD_PREFIX}'
        '$zoneIdInputKey", zoneId)',
      ),
    );
    expect(source, contains('BackgroundWorker.DART_TASK_KEY, RESYNC_JOB'));
    expect(
      source,
      contains(
        'enqueueUniqueWork(RESYNC_JOB, ExistingWorkPolicy.APPEND_OR_REPLACE',
      ),
    );
    expect(source, contains('class ZoneChangeReceiver : BroadcastReceiver()'));
  });

  test(
    'the manifest declares the receiver, unexported, for its broadcasts',
    () {
      final manifest = File(_manifest).readAsStringSync();
      expect(
        manifest,
        contains(
          'android:name="com.apsiralabs.apsira_jobs.ZoneChangeReceiver"',
        ),
      );
      expect(manifest, contains('android:exported="false"'));
      for (final action in [
        'android.intent.action.TIMEZONE_CHANGED',
        'android.intent.action.TIME_SET',
        'android.intent.action.BOOT_COMPLETED',
        'android.intent.action.MY_PACKAGE_REPLACED',
      ]) {
        expect(manifest, contains('<action android:name="$action" />'));
      }
    },
  );

  test('the receiver handles exactly the broadcasts the manifest lists', () {
    final source = File(_kotlin).readAsStringSync();
    for (final action in [
      'Intent.ACTION_TIMEZONE_CHANGED',
      'Intent.ACTION_TIME_CHANGED',
      'Intent.ACTION_BOOT_COMPLETED',
      'Intent.ACTION_MY_PACKAGE_REPLACED',
    ]) {
      expect(source, contains(action));
    }
  });
}
