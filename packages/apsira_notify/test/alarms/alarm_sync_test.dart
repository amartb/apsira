// From viaticum test/critical/reminder_sync_test.dart @ 78d38e0 (a boot, a
// restore, every database binding, an app update, a zone change, refused
// notifications) and relay test/domain/reminders/window_test.dart @ 09b28810,
// at the level of the shared sync: the app's database is the `wanted` list it
// passes (D-APK-022).
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 10, 24, 7);

DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

ScheduledAlarm alarm(String id, {int minutes = 60, String title = 'T'}) =>
    ScheduledAlarm(
      alarmId: id,
      atUtc: at(minutes),
      content: {'channel': 'alerts', 'title': '$title $id', 'body': 'b'},
    );

/// The fifteen alarms of a database.
final fifteen = [for (var i = 0; i < 15; i++) alarm('r$i', minutes: 10 + i)];

Map<String, DateTime> ringing(FakeAlarmScheduler platform) => {
  for (final a in platform.armed.values) a.alarmId: a.atUtc,
};

void main() {
  late Directory dir;
  late FakeAlarmScheduler platform;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('alarm_sync_');
    platform = FakeAlarmScheduler();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  AlarmRegistry registry() => AlarmRegistry(() async => dir);
  AlarmSync sync({
    AlarmScheduler? on,
    AlarmRegistry? with_,
    Duration? lateGrace,
    int windowSize = reminderWindowSize,
  }) => AlarmSync(
    on ?? platform,
    with_ ?? registry(),
    snoozes: SnoozeStore(() async => dir),
    lateGrace: lateGrace,
    windowSize: windowSize,
  );

  test(
    'arms the wanted set under the registry\'s ids and reports it',
    () async {
      final report = await sync().resync(wanted: fifteen, now: t0);
      expect(report.scheduled, 15);
      expect(report.cancelled, 0);
      expect(report.refused, 0);
      expect(ringing(platform), {for (final a in fifteen) a.alarmId: a.atUtc});
      expect(platform.armed.keys.toSet(), {
        for (final e in await registry().entries()) e.platformId,
      });
      expect(platform.armed.values.first.content['title'], 'T r0');
    },
  );

  test('a second run with nothing changed cancels nothing, writes nothing '
      'and arms the same alarms again', () async {
    await sync().resync(wanted: fifteen, now: t0);
    final steps = <String>[];
    final watched = registry()..afterStep = steps.add;
    platform.scheduled.clear();
    final report = await sync(with_: watched).resync(wanted: fifteen, now: t0);
    expect(report.cancelled, 0);
    expect(steps, isEmpty, reason: 'no registry write');
    expect(platform.scheduled, hasLength(15));
    expect(platform.cancelled, isEmpty);
  });

  group('resync after', () {
    test('a boot: alarms the plugin re-armed stay under their ids; a platform '
        'that lost them gets all of them', () async {
      await sync().resync(wanted: fifteen, now: t0);
      final ids = {...platform.armed.keys};
      final lost = FakeAlarmScheduler();
      final report = await sync(on: lost).resync(wanted: fifteen, now: t0);
      expect(report.scheduled, 15);
      expect(lost.armed.keys.toSet(), ids);
      expect(ringing(lost), ringing(platform));
    });

    test('an app update: changed texts are armed again', () async {
      await sync().resync(wanted: fifteen, now: t0);
      await sync().resync(
        wanted: [
          for (var i = 0; i < 15; i++)
            alarm('r$i', minutes: 10 + i, title: 'New'),
        ],
        now: t0,
      );
      expect(
        platform.armed.values.every(
          (a) => (a.content['title']! as String).startsWith('New '),
        ),
        isTrue,
      );
      expect(
        (await registry().entries()).every(
          (e) => (e.content['title']! as String).startsWith('New '),
        ),
        isTrue,
      );
    });

    test('a zone change: the same alarm ids at new instants, same platform '
        'ids', () async {
      await sync().resync(wanted: fifteen, now: t0);
      final ids = {
        for (final a in platform.armed.values) a.alarmId: a.platformId,
      };
      final moved = [
        for (final a in fifteen)
          ScheduledAlarm(
            alarmId: a.alarmId,
            atUtc: a.atUtc.add(const Duration(hours: 1)),
            content: a.content,
          ),
      ];
      await sync().resync(wanted: moved, now: t0);
      expect(ringing(platform), {for (final a in moved) a.alarmId: a.atUtc});
      expect({
        for (final a in platform.armed.values) a.alarmId: a.platformId,
      }, ids);
    });

    test('a restore: alarms whose source is gone are cancelled', () async {
      await sync().resync(wanted: fifteen, now: t0);
      final report = await sync().resync(wanted: fifteen.skip(2), now: t0);
      expect(report.cancelled, 2);
      expect(platform.armed, hasLength(13));
      expect(ringing(platform).keys, isNot(contains('r0')));
      expect(await registry().entries(), hasLength(13));
    });

    test('every database binding: the second database\'s alarms replace the '
        'first\'s', () async {
      await sync().resync(wanted: fifteen, now: t0);
      final second = [alarm('o9-a', minutes: 5), alarm('o9-b', minutes: 6)];
      await sync().resync(wanted: second, now: t0);
      expect(ringing(platform).keys, ['o9-a', 'o9-b']);
    });
  });

  test('refused notifications leave alarms off: nothing wanted cancels all; '
      'allowed again, all are armed', () async {
    await sync().resync(wanted: fifteen, now: t0);
    final off = await sync().resync(wanted: const [], now: t0);
    expect(off.cancelled, 15);
    expect(platform.armed, isEmpty);
    expect(await registry().entries(), isEmpty);
    await sync().resync(wanted: fifteen, now: t0);
    expect(platform.armed, hasLength(15));
  });

  test(
    'the window arms the nearest only; one pushed out is cancelled',
    () async {
      await sync(windowSize: 3).resync(wanted: fifteen.skip(1), now: t0);
      expect(ringing(platform).keys, ['r1', 'r2', 'r3']);
      await sync(windowSize: 3).resync(wanted: fifteen, now: t0);
      expect(ringing(platform).keys, unorderedEquals(['r0', 'r1', 'r2']));
      expect((await registry().entries()).map((e) => e.alarmId), hasLength(3));
    },
  );

  test('a refused alarm is cancelled, unregistered and reported', () async {
    platform.refuses = (a) => a.alarmId == 'r3';
    final report = await sync().resync(wanted: fifteen, now: t0);
    expect(report.refused, 1);
    expect(report.scheduled, 14);
    expect(ringing(platform).keys, isNot(contains('r3')));
    expect(
      (await registry().entries()).map((e) => e.alarmId),
      isNot(contains('r3')),
    );
  });

  test('a past alarm is armed (it goes off at once) unless older than '
      'lateGrace', () async {
    final late = alarm('late', minutes: -30);
    await sync().resync(wanted: [late], now: t0);
    expect(ringing(platform).keys, ['late']);
    await sync(lateGrace: const Duration(minutes: 10))
        .resync(wanted: [late], now: t0);
    expect(platform.armed, isEmpty);
    await sync(lateGrace: const Duration(hours: 1))
        .resync(wanted: [late], now: t0);
    expect(ringing(platform).keys, ['late']);
    expect(
      () => sync(lateGrace: const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });

  test('an alarm that fired at its instant is not armed again there; moved '
      'later, it is', () async {
    await sync().resync(wanted: [alarm('r', minutes: 0)], now: t0);
    final entry = platform.fire(platform.armed.keys.single);
    await registry().markFired(
      FiredAlarm(
        alarmId: 'r',
        platformId: entry.platformId,
        scheduledAtUtc: entry.atUtc,
        firedAtUtc: at(0),
      ),
    );
    await sync().resync(wanted: [alarm('r', minutes: 0)], now: at(1));
    expect(platform.armed, isEmpty);
    expect(await registry().entries(), isEmpty);
    await sync().resync(wanted: [alarm('r', minutes: 90)], now: at(1));
    expect(ringing(platform), {'r': at(90)});
  });

  test(
    'two wanted alarms with one id are refused before anything happens',
    () async {
      await expectLater(
        sync().resync(wanted: [alarm('a'), alarm('a', minutes: 5)], now: t0),
        throwsArgumentError,
      );
      expect(platform.scheduled, isEmpty);
    },
  );

  test('resyncs of one object run one after another: the last one asked '
      'wins', () async {
    final s = sync();
    final first = s.resync(wanted: fifteen, now: t0);
    final second = s.resync(wanted: [alarm('only')], now: t0);
    await Future.wait([first, second]);
    expect(ringing(platform).keys, ['only']);
  });

  test('snooze without a store is a StateError', () async {
    final bare = AlarmSync(platform, registry());
    await expectLater(bare.snooze(alarm('a'), until: at(10)), throwsStateError);
  });

  test(
    'a snooze stands in for its alarm only while that alarm is wanted',
    () async {
      final s = sync();
      await s.resync(wanted: [alarm('a'), alarm('b')], now: t0);
      expect(await s.snooze(alarm('a'), until: at(90)), isTrue);
      await s.resync(wanted: [alarm('a'), alarm('b')], now: t0);
      expect(ringing(platform), {'a': at(90), 'b': at(60)});
      // Done: the app no longer wants a.
      await s.resync(wanted: [alarm('b')], now: t0);
      expect(ringing(platform), {'b': at(60)});
      expect(await SnoozeStore(() async => dir).all(), isEmpty);
    },
  );
}
