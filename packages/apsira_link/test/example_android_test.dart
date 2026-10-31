import 'dart:io';

import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/src/link_channel.dart';
import 'package:apsira_link/testing/link_release_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

// The Kotlin half against the Dart half (AC-4.5, K1-02b.9; K2-02a): the
// names and limits both sides must agree on, read from the Kotlin sources and
// the plugin manifest.
const _kotlin = 'android/src/main/kotlin/com/apsiralabs/apsira_link';

String _read(String path) => File(path).readAsStringSync();

String? _constant(String source, String name) =>
    RegExp('const val $name = "([^"]*)"').firstMatch(source)?[1];

void main() {
  final plugin = _read('$_kotlin/ApsiraLinkPlugin.kt');
  final trust = _read('$_kotlin/LinkTrust.kt');
  final streams = _read('$_kotlin/LinkStreams.kt');
  final manifest = _read('android/src/main/AndroidManifest.xml');

  test('the Kotlin channel is ChannelApsiraLink.channelName, method call', () {
    expect(_constant(plugin, 'CHANNEL'), ChannelApsiraLink.channelName);
    expect(_constant(plugin, 'METHOD'), 'call');
  });

  test('the Kotlin stream methods are LinkChannel\'s (K2-02a)', () {
    expect(_constant(plugin, 'WRITE'), LinkChannel.writeMethod);
    expect(_constant(plugin, 'READ'), LinkChannel.readMethod);
    expect(_constant(plugin, 'CLOSE'), LinkChannel.closeMethod);
    expect(_constant(plugin, 'CANCEL'), LinkChannel.cancelMethod);
    expect(_constant(streams, 'STREAM'), 'stream');
    expect(streams, contains('const val MAX_READ = 64 * 1024'));
    expect(LinkChannel.chunkSize, 64 * 1024);
  });

  test('the Kotlin deadline is linkControlDeadline, on 2 threads', () {
    expect(
      RegExp(r'const val CONTROL_DEADLINE_MS = ([0-9_]+)L')
          .firstMatch(plugin)?[1]
          ?.replaceAll('_', ''),
      '${linkControlDeadline.inMilliseconds}',
    );
    expect(plugin, contains('const val CONTROL_THREADS = 2'));
  });

  test('F_APSIRA is unset: a release app trusts no APSIRA (ruling A-7)', () {
    expect(_constant(trust, 'F_APSIRA'), '');
  });

  test('the Kotlin switch name is linkDevSwitch (ruling R-2)', () {
    expect(_constant(trust, 'DEV_SWITCH'), linkDevSwitch);
  });

  test('the plugin manifest queries both APSIRA builds', () {
    final queries = RegExp(
      r'<queries>(.*?)</queries>',
      dotAll: true,
    ).firstMatch(manifest)?[1];
    expect(queries, isNotNull);
    for (final pkg in ['com.apsiralabs.apsira', 'com.apsiralabs.apsira.dev']) {
      expect(queries, contains('<package android:name="$pkg" />'));
    }
  });

  test('the plugin manifest declares no DEV_LINK switch (ruling R-5)', () {
    expect(declaresLinkDevSwitch(manifest), isFalse);
    expect(manifest, isNot(contains(linkDevSwitch)));
  });
}
