// The crash matrix of the per-install alarm registry (D-APK-022, kill points
// KP-A1…A9 of the packages-v0-4 task specs and KP-A10 of F1), written before
// the code. A kill
// is a `SimulatedCrash` thrown by a step hook after the named step; the test
// then drops every object and builds new ones from the files on disk and the
// platform's alarms, as a restarted process would. The platform is the
// recording `FakeAlarmScheduler`: what it holds in `armed` is what would ring.
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A kill at a named step.
final class SimulatedCrash implements Exception {
  const SimulatedCrash(this.step);

  final String step;

  @override
  String toString() => 'SimulatedCrash($step)';
}

/// A hook that kills the process after [step].
void Function(String) killAfter(String step) => (done) {
  if (done == step) throw SimulatedCrash(done);
};

final t0 = DateTime.utc(2026, 10, 24, 7);

ScheduledAlarm alarm(String id, {int minutes = 60}) => ScheduledAlarm(
  alarmId: id,
  atUtc: t0.add(Duration(minutes: minutes)),
  content: {'title': 'Reminder $id'},
);

/// What would ring: alarm id → instant.
Map<String, DateTime> ringing(FakeAlarmScheduler platform) => {
  for (final a in platform.armed.values) a.alarmId: a.atUtc,
};

DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('alarm_crash_'));
  tearDown(() => dir.deleteSync(recursive: true));

  AlarmRegistry registry([Directory? on]) =>
      AlarmRegistry(() async => on ?? dir);
  SnoozeStore snoozes([Directory? on]) => SnoozeStore(() async => on ?? dir);
  AlarmSync sync(
    AlarmScheduler platform, {
    AlarmRegistry? on,
    Directory? storage,
    Duration? lateGrace,
  }) => AlarmSync(
    platform,
    on ?? registry(storage),
    snoozes: snoozes(storage),
    lateGrace: lateGrace,
  );

  test('KP-A1 a restore finished and killed before the first resync arms '
      'nothing from the restored rows; the resync arms exactly the wanted '
      'set', () async {
    final platform = FakeAlarmScheduler();
    await sync(platform).resync(wanted: [alarm('a'), alarm('b')], now: t0);
    // The swap replaces the database, never alarms/; the process dies before
    // any resync: what rings is still this install's own set.
    expect(ringing(platform), {'a': at(60), 'b': at(60)});
    final restoredWants = [alarm('b', minutes: 90), alarm('c')];
    expect(ringing(platform).keys, isNot(contains('c')));
    await sync(platform).resync(wanted: restoredWants, now: t0);
    expect(ringing(platform), {'b': at(90), 'c': at(60)});
  });

  test('KP-A2 a backup from another phone restored: the other phone\'s '
      'alarms are never armed; this install\'s whose source is gone are '
      'cancelled', () async {
    final other = Directory.systemTemp.createTempSync('alarm_other_');
    addTearDown(() => other.deleteSync(recursive: true));
    final otherPhone = FakeAlarmScheduler();
    await sync(
      otherPhone,
      storage: other,
    ).resync(wanted: [alarm('x'), alarm('y')], now: t0);

    final platform = FakeAlarmScheduler();
    await sync(platform).resync(wanted: [alarm('a'), alarm('b')], now: t0);
    final mine = await registry().entries();
    // The restored database wants c only; the other phone's registry never
    // travels with it.
    await sync(platform).resync(wanted: [alarm('c')], now: t0);
    expect(ringing(platform), {'c': at(60)});
    expect(
      platform.cancelled,
      containsAll([for (final e in mine) e.platformId]),
    );
    expect(platform.scheduled.map((a) => a.alarmId), isNot(contains('x')));
    expect(platform.scheduled.map((a) => a.alarmId), isNot(contains('y')));
    expect((await registry().entries()).single.platformId, 3);
  });

  test('KP-A3 killed inside the registry write (.tmp written): the registry '
      'reads whole, the old one', () async {
    final platform = FakeAlarmScheduler();
    await sync(platform).resync(wanted: [alarm('a')], now: t0);
    final dying = registry()..afterStep = killAfter('tmpWritten');
    await expectLater(
      sync(
        platform,
        on: dying,
      ).resync(wanted: [alarm('a'), alarm('b')], now: t0),
      throwsA(isA<SimulatedCrash>()),
    );
    expect(File('${dir.path}/alarms/registry.json.tmp').existsSync(), isTrue);
    expect((await registry().entries()).map((e) => e.alarmId), ['a']);
    expect(ringing(platform), {'a': at(60)});
    await sync(platform).resync(wanted: [alarm('a'), alarm('b')], now: t0);
    expect(ringing(platform), {'a': at(60), 'b': at(60)});
  });

  test('KP-A4 killed after register, before the platform schedule: the next '
      'start schedules it (registry ⊇ armed)', () async {
    final platform = FakeAlarmScheduler();
    await expectLater(
      (sync(platform)..afterStep = killAfter('registered')).resync(
        wanted: [alarm('a')],
        now: t0,
      ),
      throwsA(isA<SimulatedCrash>()),
    );
    final registered = await registry().entries();
    expect(registered.map((e) => e.alarmId), ['a']);
    expect(platform.armed, isEmpty);
    await sync(platform).resync(wanted: [alarm('a')], now: t0);
    expect(ringing(platform), {'a': at(60)});
    expect(platform.armed.keys, [registered.single.platformId]);
  });

  test('KP-A5 killed after the platform cancel, before unregister: cancelled '
      'again, idempotently, then gone from the registry', () async {
    final platform = FakeAlarmScheduler();
    await sync(platform).resync(wanted: [alarm('a'), alarm('b')], now: t0);
    final b = (await registry().entries()).singleWhere((e) => e.alarmId == 'b');
    await expectLater(
      (sync(platform)..afterStep = killAfter('cancelled')).resync(
        wanted: [alarm('a')],
        now: t0,
      ),
      throwsA(isA<SimulatedCrash>()),
    );
    expect(ringing(platform), {'a': at(60)});
    expect(
      (await registry().entries()).map((e) => e.alarmId),
      containsAll(['a', 'b']),
    );
    await sync(platform).resync(wanted: [alarm('a')], now: t0);
    expect(platform.cancelled.where((id) => id == b.platformId), hasLength(2));
    expect((await registry().entries()).map((e) => e.alarmId), ['a']);
    expect(ringing(platform), {'a': at(60)});
  });

  test('KP-A6 a reboot that forgot every alarm: every wanted alarm armed '
      'again, none twice', () async {
    final platform = FakeAlarmScheduler();
    final wanted = [alarm('a'), alarm('b', minutes: 30), alarm('c')];
    await sync(platform).resync(wanted: wanted, now: t0);
    final ids = {
      for (final a in platform.armed.values) a.alarmId: a.platformId,
    };
    platform.forgetAll();
    platform.scheduled.clear();
    await sync(platform).resync(wanted: wanted, now: t0);
    expect(ringing(platform), {'a': at(60), 'b': at(30), 'c': at(60)});
    expect(platform.scheduled, hasLength(3));
    expect({
      for (final a in platform.armed.values) a.alarmId: a.platformId,
    }, ids);
  });

  test('KP-A7 an old database with RELAY\'s registered_alarms restored: no '
      'row is armed; this install\'s own codes are cancelled once', () async {
    // The restored table's rows (request codes from RELAY's FNV hash). The
    // package never reads a database: the app passes what its reminders want.
    const restoredCodes = [1234567890, 987654321];
    const ownCodes = [555555555];
    final platform = FakeAlarmScheduler();
    await registry().addPendingCancels(ownCodes);
    await sync(platform).resync(wanted: [alarm('r1')], now: t0);
    expect(ringing(platform), {'r1': at(60)});
    for (final code in restoredCodes) {
      expect(platform.armed.keys, isNot(contains(code)));
      expect(
        platform.scheduled.map((a) => a.platformId),
        isNot(contains(code)),
      );
    }
    expect(platform.cancelled, ownCodes);
    await sync(platform).resync(wanted: [alarm('r1')], now: t0);
    expect(platform.cancelled, ownCodes, reason: 'cancelled once');
    expect(await registry().pendingCancels(), isEmpty);
  });

  test('KP-A8 a foreign registry from a device transfer on a fresh platform: '
      'resync arms only what this install wants and keeps nothing it did not '
      'schedule', () async {
    final other = Directory.systemTemp.createTempSync('alarm_transfer_');
    addTearDown(() => other.deleteSync(recursive: true));
    final otherPhone = FakeAlarmScheduler();
    await sync(otherPhone, storage: other).resync(
      wanted: [alarm('x'), alarm('a', minutes: 20), alarm('y')],
      now: t0,
    );
    await snoozes(other).snooze('y', at(25));
    // The transfer copies alarms/ without the exclusion.
    Directory('${dir.path}/alarms').createSync(recursive: true);
    for (final name in ['registry.json', 'snoozes.json']) {
      File('${other.path}/alarms/$name').copySync('${dir.path}/alarms/$name');
    }

    final platform = FakeAlarmScheduler();
    await sync(platform)
        .resync(wanted: [alarm('a', minutes: 20), alarm('b')], now: t0);
    expect(ringing(platform), {'a': at(20), 'b': at(60)});
    for (final entry in await registry().entries()) {
      expect(
        platform.scheduled.where(
          (s) => s.alarmId == entry.alarmId && s.platformId == entry.platformId,
        ),
        isNotEmpty,
        reason: '${entry.alarmId} stays registered without a schedule call',
      );
    }
    expect(
      (await registry().entries()).map((e) => e.alarmId),
      unorderedEquals(['a', 'b']),
    );
    expect(await snoozes().all(), isEmpty, reason: 'y is not wanted here');
  });

  test('KP-A9 a snooze written from the background, then a resume resync: '
      'armed at its new time; pruned once it fired or expired', () async {
    final platform = FakeAlarmScheduler();
    // LYCEUM's alerts: a fire that is past is not armed again.
    const grace = Duration.zero;
    final r = alarm('r', minutes: 0);
    await sync(platform, lateGrace: grace).resync(wanted: [r], now: t0);
    platform.fire(platform.armed.keys.single);
    // +10 min from the notification, in the background engine.
    expect(
      await sync(platform, lateGrace: grace).snooze(r, until: at(10)),
      isTrue,
    );
    expect(ringing(platform), {'r': at(10)});
    // The app resumes: r is still wanted at its first time (not Done).
    await sync(platform, lateGrace: grace).resync(wanted: [r], now: at(1));
    expect(ringing(platform), {'r': at(10)});
    expect((await snoozes().all()).single.alarmId, 'r');
    platform.fire(platform.armed.keys.single);
    await sync(platform, lateGrace: grace).resync(wanted: [r], now: at(11));
    expect(await snoozes().all(), isEmpty);
    expect(platform.armed, isEmpty);
    expect(await registry().entries(), isEmpty);
  });

  group('KP-A10 a restore or transfer that brought the plugin\'s own list', () {
    // The backup copied the scheduling plugin's persisted list (FLN's
    // scheduled_notifications, android_alarm_manager_plus's
    // persistent_alarm_ids), which its boot receiver re-arms: the platform
    // holds pending ids that this install's registry never handed out.
    RegisteredAlarm foreign(String id, int platformId) => RegisteredAlarm(
      alarmId: id,
      platformId: platformId,
      atUtc: at(45),
      content: {'title': 'Other phone $id'},
    );

    test('with an empty registry: after the resync only this install\'s '
        'alarms are pending; every other id is cancelled', () async {
      final platform = FakeAlarmScheduler();
      for (final f in [foreign('x', 0), foreign('y', 1), foreign('z', 7)]) {
        platform.armed[f.platformId] = f;
      }
      final report = await sync(platform)
          .resync(wanted: [alarm('a'), alarm('b')], now: t0);
      expect(ringing(platform), {'a': at(60), 'b': at(60)});
      final mine = {for (final e in await registry().entries()) e.platformId};
      expect(await platform.pendingPlatformIds(), mine);
      expect(platform.cancelled, containsAll([0, 1, 7]));
      expect(report.cancelled, 3);
      platform.cancelled.clear();
      await sync(platform).resync(wanted: [alarm('a'), alarm('b')], now: t0);
      expect(platform.cancelled, isEmpty, reason: 'nothing foreign is left');
    });

    test('with a foreign registry beside the foreign list: the same', () async {
      final other = Directory.systemTemp.createTempSync('alarm_list_');
      addTearDown(() => other.deleteSync(recursive: true));
      final otherPhone = FakeAlarmScheduler();
      await sync(otherPhone, storage: other).resync(
        wanted: [alarm('x'), alarm('a', minutes: 20), alarm('y')],
        now: t0,
      );
      Directory('${dir.path}/alarms').createSync(recursive: true);
      File('${other.path}/alarms/registry.json')
          .copySync('${dir.path}/alarms/registry.json');
      final platform = FakeAlarmScheduler();
      platform.armed.addAll(otherPhone.armed);
      platform.armed[9] = foreign('stale', 9);

      await sync(platform)
          .resync(wanted: [alarm('a', minutes: 20), alarm('b')], now: t0);
      expect(ringing(platform), {'a': at(20), 'b': at(60)});
      expect(await platform.pendingPlatformIds(), {
        for (final e in await registry().entries()) e.platformId,
      });
      expect(platform.cancelled, contains(9));
    });

    test('on the notification plugin (FlnAlarmScheduler): the restored '
        'scheduled list is cancelled, this install\'s alarms stay', () async {
      // The plugin's own check of a future date reads the real clock.
      final now = DateTime.utc(2099, 1, 1, 9);
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final pending = <int, Map<String, Object?>>{
        for (final id in [0, 3, 12000])
          id: {'id': id, 'title': 'Other', 'body': 'o', 'payload': 'x$id'},
      };
      final cancelled = <int>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments;
        switch (call.method) {
          case 'pendingNotificationRequests':
            return [...pending.values];
          case 'zonedSchedule':
            final id = (args as Map)['id'] as int;
            pending[id] = {
              'id': id,
              'title': args['title'],
              'body': args['body'],
              'payload': args['payload'],
            };
          case 'cancel':
            final id = (args as Map)['id'] as int;
            cancelled.add(id);
            pending.remove(id);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const spec = NotificationChannelSpec('alerts', 'Alerts');
      final scheduler = FlnAlarmScheduler(
        notificationOf: (a) => AppNotification(
          notificationId: a.platformId,
          title: a.content['title']! as String,
          body: 'b',
          channel: spec,
        ),
        now: () => now,
      );
      ScheduledAlarm soon(String id) => ScheduledAlarm(
        alarmId: id,
        atUtc: now.add(const Duration(hours: 1)),
        content: {'title': 'Mine $id'},
      );

      await AlarmSync(
        scheduler,
        registry(),
        lateGrace: Duration.zero,
      ).resync(wanted: [soon('a'), soon('b')], now: now);
      final mine = {for (final e in await registry().entries()) e.platformId};
      expect(pending.keys.toSet(), mine);
      expect(cancelled, containsAll([0, 3, 12000]));
      expect(
        pending.values.map((p) => p['payload']),
        unorderedEquals(['a', 'b']),
      );
    });
  });
}
