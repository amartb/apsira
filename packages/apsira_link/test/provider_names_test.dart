import 'dart:io';

import 'package:apsira_link/requests.dart';
import 'package:flutter_test/flutter_test.dart';

// The app-side provider's Kotlin against requests.dart (K2-02d): the names
// both halves, apsira_jobs' RunJobReceiver and an adopting app's manifest
// must agree on, read from the Kotlin sources. apsira_jobs pins the same
// receiver name and extra from its side (run_job_names_test.dart).
const _kotlin = 'android/src/main/kotlin/com/apsiralabs/apsira_link';

String _read(String path) => File(path).readAsStringSync();

String? _constant(String source, String name) =>
    RegExp('const val $name = "([^"]*)"').firstMatch(source)?[1];

void main() {
  final provider = _read('$_kotlin/AppLinkProvider.kt');
  final inbox = _read('$_kotlin/AppLinkInbox.kt');
  final plugin = _read('$_kotlin/ApsiraLinkPlugin.kt');
  final manifest = _read('android/src/main/AndroidManifest.xml');

  test('the provider class and its authority suffix (contract §2)', () {
    expect(provider, contains('package com.apsiralabs.apsira_link'));
    expect(provider, contains('class AppLinkProvider internal constructor('));
    expect(
      AppLinkNames.providerClass,
      'com.apsiralabs.apsira_link.AppLinkProvider',
    );
    expect(
      _constant(provider, 'AUTHORITY_SUFFIX'),
      AppLinkNames.authoritySuffix,
    );
    expect(AppLinkNames.authoritySuffix, '.apsira');
  });

  test('the methods on the app (§5.3, §5.4)', () {
    expect(_constant(provider, 'BACKUP_NOW'), AppLinkNames.backupNow);
    expect(_constant(provider, 'RESTORE_OFFER'), AppLinkNames.restoreOffer);
    expect(AppLinkNames.backupNow, 'backup_now');
    expect(AppLinkNames.restoreOffer, 'restore_offer');
  });

  test('the backup job meta-data and apsira_jobs\' receiver and extra', () {
    expect(_constant(provider, 'BACKUP_JOB'), AppLinkNames.backupJobMetaData);
    expect(
      AppLinkNames.backupJobMetaData,
      'com.apsiralabs.apsira_link.BACKUP_JOB',
    );
    expect(
      _constant(provider, 'RUN_JOB_RECEIVER'),
      AppLinkNames.runJobReceiver,
    );
    expect(
      AppLinkNames.runJobReceiver,
      'com.apsiralabs.apsira_jobs.RunJobReceiver',
    );
    expect(_constant(provider, 'JOB'), AppLinkNames.runJobExtra);
    expect(AppLinkNames.runJobExtra, 'job');
  });

  test('the inbox file and the offer keys RestoreOffer.fromWire reads', () {
    expect(_constant(inbox, 'DIR'), 'apsira_link');
    expect(_constant(inbox, 'FILE'), 'restore_offer.json');
    expect(_constant(inbox, 'NAME'), 'name');
    expect(_constant(inbox, 'SNAPSHOT'), 'snapshot');
    expect(_constant(inbox, 'MADE_UTC'), 'made_utc');
    expect(_constant(inbox, 'SIZE'), 'size');
    expect(_constant(inbox, 'REASON'), 'reason');
    expect(inbox, contains('setOf("user", "new_device")'));
    expect(RestoreReason.values.map((r) => r.wire), ['user', 'new_device']);
  });

  test('the requests channel is ChannelAppLinkRequests\'', () {
    expect(
      _constant(plugin, 'REQUESTS_CHANNEL'),
      ChannelAppLinkRequests.channelName,
    );
    expect(_constant(plugin, 'TAKE'), ChannelAppLinkRequests.takeMethod);
    expect(_constant(plugin, 'OFFER'), ChannelAppLinkRequests.offerMethod);
  });

  test('the library manifest declares no provider: each app does', () {
    expect(manifest, isNot(contains('<provider')));
    expect(manifest, isNot(contains('AppLinkProvider')));
  });
}
