// From viaticum test/data/platform/alarm_manager_scheduler_test.dart
// @ 78d38e0 (the registry's cases: platform ids kept and never handed out
// twice, soonest first, the torn fire line), with a VIATICUM 1.0.0
// registry read unchanged and RELAY's codes as pending cancels (D-APK-022).
import 'dart:convert';
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 10, 24, 7);

ScheduledAlarm alarm(String id, {int hours = 2}) => ScheduledAlarm(
  alarmId: id,
  atUtc: t0.add(Duration(hours: hours)),
  content: {'title': 'Pedido $id'},
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('alarm_registry_'));
  tearDown(() => dir.deleteSync(recursive: true));

  AlarmRegistry registry() => AlarmRegistry(() async => dir);
  File file(String name) => File('${dir.path}/alarms/$name');

  test('VIATICUM\'s path and names', () {
    expect(AlarmRegistry.defaultPath, 'alarms/registry.json');
    expect(AlarmRegistry.firedName, 'fired.jsonl');
  });

  group('a VIATICUM 1.0.0 registry', () {
    setUp(() {
      Directory('${dir.path}/alarms').createSync(recursive: true);
      File('test/alarms/fixtures/viaticum_1_0_0_registry.json')
          .copySync(file('registry.json').path);
      File('test/alarms/fixtures/viaticum_1_0_0_fired.jsonl')
          .copySync(file('fired.jsonl').path);
    });

    test('reads unchanged: ids, instants, platform ids and content', () async {
      expect(await registry().entries(), [
        RegisteredAlarm(
          alarmId: 'reminder:order_deadline:o1:2026-11-03',
          platformId: 1,
          atUtc: DateTime.utc(2026, 11, 3, 8),
          content: const {
            'channel': 'alerts',
            'title': 'Pedido AHN',
            'body': 'Vence mañana',
          },
        ),
        RegisteredAlarm(
          alarmId: 'reminder:morning_card:d4:2026-11-10',
          platformId: 3,
          atUtc: DateTime.utc(2026, 11, 10, 7),
          content: const {
            'channel': 'quiet',
            'title': 'Hoy: AHN',
            'body': 'Abre 08:00',
          },
        ),
      ]);
      expect(await registry().pendingCancels(), isEmpty);
      expect(await registry().fires(), [
        FiredAlarm(
          alarmId: 'reminder:order_unconfirmed:o2:2026-10-30',
          platformId: 2,
          scheduledAtUtc: DateTime.utc(2026, 10, 30, 9),
          firedAtUtc: DateTime.utc(2026, 10, 30, 9, 0, 3),
        ),
      ]);
    });

    test('registering what it holds writes nothing; a new alarm takes the '
        'next id and keeps VIATICUM\'s format', () async {
      final before = file('registry.json').readAsStringSync();
      await registry().registerAll([
        for (final e in await registry().entries()) e.alarm,
      ]);
      expect(file('registry.json').readAsStringSync(), before);
      final added = await registry().register(alarm('reminder:x:1'));
      expect(added.platformId, 4);
      final json = jsonDecode(
        file('registry.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(json.keys, ['nextPlatformId', 'alarms']);
      final old =
          (jsonDecode(before) as Map<String, Object?>)['alarms']! as List;
      final alarms = json['alarms']! as List;
      expect(alarms.sublist(0, 2), old);
      expect((alarms.last as Map).keys, [
        'alarmId',
        'atUtcMs',
        'title',
        'platformId',
      ]);
      expect(json['nextPlatformId'], 5);
    });
  });

  test('an alarm id keeps its platform id while registered; a new one gets '
      'the next, never one handed out before', () async {
    final r = registry();
    expect((await r.register(alarm('r-1'))).platformId, 1);
    expect((await r.register(alarm('r-1', hours: 1))).platformId, 1);
    expect((await r.register(alarm('r-2'))).platformId, 2);
    await r.unregister('r-2');
    expect((await r.register(alarm('r-3'))).platformId, 3);
    expect((await r.register(alarm('r-2'))).platformId, 4);
    expect((await registry().entries()).map((e) => e.alarmId), [
      'r-1',
      'r-3',
      'r-2',
    ]);
  });

  test('registered is soonest first, by id at the same instant, leaves out '
      'what fired at its instant, and survives a new object', () async {
    final r = registry();
    await r.registerAll([
      alarm('r-b', hours: 3),
      alarm('r-c', hours: 1),
      alarm('r-a', hours: 3),
      alarm('r-d', hours: 4),
    ]);
    final d = (await r.entries()).last;
    await r.markFired(
      FiredAlarm(
        alarmId: 'r-d',
        platformId: d.platformId,
        scheduledAtUtc: d.atUtc,
        firedAtUtc: d.atUtc,
      ),
    );
    expect((await registry().registered()).map((e) => e.alarmId), [
      'r-c',
      'r-a',
      'r-b',
    ]);
    await r.register(alarm('r-d', hours: 30));
    expect((await registry().registered()).last.alarmId, 'r-d');
  });

  test('a torn last line of the fire record is skipped', () async {
    final r = registry();
    await r.markFired(
      FiredAlarm(
        alarmId: 'r-1',
        platformId: 1,
        scheduledAtUtc: t0,
        firedAtUtc: t0,
      ),
    );
    file('fired.jsonl')
        .writeAsStringSync('{"alarmId":"r-', mode: FileMode.append);
    expect(await r.fires(), hasLength(1));
  });

  test(
    'a write goes to .tmp, flushed, then renamed over the registry',
    () async {
      final steps = <String>[];
      final r = registry()
        ..afterStep = (step) {
          steps.add(step);
          if (step == 'tmpWritten') {
            expect(file('registry.json.tmp').existsSync(), isTrue);
            expect(file('registry.json').existsSync(), isFalse);
          }
        };
      await r.register(alarm('r-1'));
      expect(steps, ['tmpWritten', 'renamed']);
      expect(file('registry.json.tmp').existsSync(), isFalse);
    },
  );

  test('pending cancels: RELAY\'s codes, kept once each, cleared by '
      'unregisterAll, never a platform id handed out', () async {
    final r = registry();
    await r.addPendingCancels([7, 9, 7]);
    expect(await r.pendingCancels(), [7, 9]);
    await r.unregisterAll(const [], pendingCancels: [7]);
    expect(await registry().pendingCancels(), [9]);
    expect((await r.register(alarm('r-1'))).platformId, 1);
    await expectLater(r.addPendingCancels([-1]), throwsArgumentError);
    await expectLater(r.addPendingCancels([1 << 31]), throwsArgumentError);
  });

  test('a local instant or a content key of the registry is refused before '
      'anything is written', () async {
    await expectLater(
      registry().register(
        ScheduledAlarm(alarmId: 'r-1', atUtc: DateTime(2026, 10, 24, 9)),
      ),
      throwsArgumentError,
    );
    await expectLater(
      registry().register(
        ScheduledAlarm(
          alarmId: 'r-1',
          atUtc: t0,
          content: const {'platformId': 3},
        ),
      ),
      throwsArgumentError,
    );
    expect(file('registry.json').existsSync(), isFalse);
  });

  test('a registry that does not read is a FormatException', () async {
    file('registry.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"alarms":');
    await expectLater(registry().entries(), throwsFormatException);
    file('registry.json').writeAsStringSync('{"alarms":[]}');
    await expectLater(registry().entries(), throwsFormatException);
  });
}
