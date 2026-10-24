// From relay test/data/platform/zone_module_test.dart @ 09b28810 (the
// channel half; the receiver is apsira_jobs', ruling R-3). The Kotlin source
// checks stand in for a compile, which the apps' adoption lanes prove (R-3).
import 'dart:io';

import 'package:apsira_app/apsira_app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _kotlin = 'android/src/main/kotlin/com/apsiralabs/apsira_app';

String _read(String path) => File(path).readAsStringSync();

/// The body of the Kotlin function [name], up to its closing brace at the
/// function's own indentation.
String _function(String source, String name) {
  final match = RegExp(
    '\n( *)override fun $name\\b.*?\n\\1\\}',
    dotAll: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'fun $name');
  return match![0]!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(ZoneChannel.name);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SystemClock.forgetZone();
  });

  group('zone channel', () {
    test('is apsira_app/zone', () {
      expect(ZoneChannel.name, 'apsira_app/zone');
    });

    test('ZoneChannel.zoneId reads the module\'s zoneId', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return 'America/Mexico_City';
      });
      expect(await const ZoneChannel().zoneId(), 'America/Mexico_City');
      expect(calls, ['zoneId']);
    });

    test('a zone channel that answers no ID, or is missing, throws', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => '');
      await expectLater(const ZoneChannel().zoneId(), throwsStateError);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await expectLater(const ZoneChannel().zoneId(), throwsStateError);
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        const ZoneChannel().zoneId(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('SystemClock.refreshZone keeps the zone read; a failed read keeps '
        'the last one', () async {
      var zone = 'Europe/Madrid';
      messenger.setMockMethodCallHandler(channel, (_) async => zone);
      await SystemClock.refreshZone(const ZoneChannel().zoneId);
      expect(const SystemClock().timeZoneName(), 'Europe/Madrid');
      zone = 'Asia/Tokyo';
      await SystemClock.refreshZone(const ZoneChannel().zoneId);
      expect(const SystemClock().timeZoneName(), 'Asia/Tokyo');
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        SystemClock.refreshZone(const ZoneChannel().zoneId),
        throwsA(anything),
      );
      expect(const SystemClock().timeZoneName(), 'Asia/Tokyo');
    });
  });

  group('ZoneModule.kt and the plugin (AC-5.2)', () {
    test('ZoneModule.kt is the channel half: the channel, zoneId and the '
        'default zone, nothing else', () {
      final source = _read('$_kotlin/ZoneModule.kt');
      expect(source.split('\n').length, lessThan(60));
      expect(source, contains('"${ZoneChannel.name}"'));
      expect(source, contains('"zoneId"'));
      expect(source, contains('TimeZone.getDefault().id'));
      expect(source, isNot(contains('BroadcastReceiver')));
    });

    test('the plugin sets the handler when an activity attaches and clears '
        'it when the activity goes: the UI engine only', () {
      final source = _read('$_kotlin/ApsiraAppPlugin.kt');
      expect(source, contains('class ApsiraAppPlugin'));
      expect(source, contains('ActivityAware'));
      expect(
        _function(source, 'onAttachedToActivity'),
        contains('ZoneModule.register('),
      );
      expect(
        _function(source, 'onReattachedToActivityForConfigChanges'),
        contains('ZoneModule.register('),
      );
      expect(
        _function(source, 'onDetachedFromActivity'),
        contains('ZoneModule.unregister('),
      );
      // A background engine attaches to no activity: attaching to an engine
      // only keeps its messenger.
      expect(
        _function(source, 'onAttachedToEngine'),
        isNot(contains('ZoneModule.register(')),
      );
    });

    test('nothing in the package names the background-job plugin', () {
      // Spelled in two parts, so this file passes the AC-5.2 grep too.
      const plugin =
          'work'
          'manager';
      final hits = [
        for (final dir in ['lib', 'android', 'test'])
          for (final f in Directory(dir).listSync(recursive: true))
            if (f is File &&
                !f.path.contains('/build/') &&
                !f.path.contains('/.gradle/') &&
                f.readAsStringSync().toLowerCase().contains(plugin))
              f.path,
      ];
      expect(hits, isEmpty);
    });
  });
}
