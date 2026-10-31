// RunJobReceiver (android/…/RunJobReceiver.kt; K2-02d, contract app-link.md
// §5.3): apsira_link's AppLinkProvider sends it an explicit in-app broadcast
// naming the app's Dart backup job, and it queues that job once through
// ZoneResync's mechanism. There is no compile edge between the packages, so
// the class name and the extra are pinned here and in apsira_link's
// provider_names_test.dart to the same values. The Kotlin compiles only in
// an app's build, so this test reads its sources and the package manifest.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dir = 'android/src/main/kotlin/com/apsiralabs/apsira_jobs';
const _manifest = 'android/src/main/AndroidManifest.xml';

// apsira_link's AppLinkNames.runJobReceiver and AppLinkNames.runJobExtra.
const _receiver = 'com.apsiralabs.apsira_jobs.RunJobReceiver';
const _extra = 'job';

void main() {
  final receiver = File('$_dir/RunJobReceiver.kt').readAsStringSync();
  final resync = File('$_dir/ZoneResync.kt').readAsStringSync();
  final manifest = File(_manifest).readAsStringSync();

  test('the receiver is the class apsira_link names, reading its extra', () {
    expect(receiver, contains('package com.apsiralabs.apsira_jobs'));
    expect(
      '${RegExp(r'package ([\w.]+)').firstMatch(receiver)![1]}.'
      '${RegExp(r'class (\w+) : BroadcastReceiver\(\)').firstMatch(receiver)![1]}',
      _receiver,
    );
    expect(receiver, contains('const val JOB = "$_extra"'));
    expect(receiver, contains('intent.getStringExtra(JOB)'));
  });

  test('it queues the named job once, through ZoneResync.enqueueOnce', () {
    expect(receiver, contains('ZoneResync.enqueueOnce(context, job, '));
    expect(
      resync,
      contains(
        'fun enqueueOnce(context: Context, job: String, '
        'payload: Map<String, String>)',
      ),
    );
    expect(
      resync,
      contains('enqueueUniqueWork(job, ExistingWorkPolicy.APPEND_OR_REPLACE'),
    );
    expect(resync, contains('.putString(BackgroundWorker.DART_TASK_KEY, job)'));
  });

  test('the manifest declares it, not exported, with no intent filter', () {
    final element = RegExp(
      r'<receiver\s+android:name="' +
          RegExp.escape(_receiver) +
          r'"\s+android:exported="false"\s*/>',
    );
    expect(element.allMatches(manifest), hasLength(1));
    expect(RegExp('<receiver').allMatches(manifest), hasLength(2));
  });
}
