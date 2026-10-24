// From relay test/data/platform/alarm_manager_scheduler_test.dart @ 09b28810
// and viaticum test/data/platform/alarm_manager_scheduler_test.dart
// @ 78d38e0: exact, waking, allow-while-idle alarms that survive a reboot,
// under the registry's platform ids; cancel, which prunes the plugin's reboot
// list; and the fire entry, which records the fire, delivers it and cancels
// the platform alarm (D-APK-022, ruling R-1 Q1-c). The plugin's own Dart code
// runs; its method channel is answered by a recording handler. That an alarm
// fires on time on the phone, in Doze and after a reboot, is a device check.
import 'dart:io';
import 'dart:ui' show CallbackHandle;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:apsira_jobs/apsira_jobs.dart';
import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fire entry the tests hand the scheduler; never called here.
@pragma('vm:entry-point')
Future<void> _onFire(int platformId, Map<String, dynamic> params) async {}

const _firedHandle = 42;
const _dispatcherHandle = 7;

final t0 = DateTime.utc(2026, 10, 24, 7);

RegisteredAlarm entry({
  int platformId = 41,
  String id = 'reminder:order_deadline:o1:2026-11-03',
  Duration after = const Duration(hours: 2),
}) => RegisteredAlarm(
  alarmId: id,
  platformId: platformId,
  atUtc: t0.add(after),
  content: const {'channel': 'quiet', 'title': 'Pedido', 'body': 'Mañana'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late bool accepted;
  late Directory dir;

  setUp(() {
    calls = [];
    accepted = true;
    dir = Directory.systemTemp.createTempSync('alarm_manager_');
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'Alarm.oneShotAt' ? accepted : true;
    });
    AndroidAlarmManager.setTestOverrides(
      getCallbackHandle: (callback) => CallbackHandle.fromRawHandle(
        identical(callback, _onFire) ? _firedHandle : _dispatcherHandle,
      ),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
    dir.deleteSync(recursive: true);
  });

  Iterable<MethodCall> named(String method) =>
      calls.where((c) => c.method == method);

  List<Object?> oneShotArgs() =>
      named('Alarm.oneShotAt').last.arguments as List<Object?>;

  group('schedule', () {
    test('starts the service once, then sets an exact, idle-proof, waking '
        'alarm that survives a reboot, under the registry\'s id, carrying '
        'the alarm to the fire entry', () async {
      final scheduler = AlarmManagerScheduler(_onFire);
      expect(await scheduler.schedule(entry()), isTrue);
      expect(await scheduler.schedule(entry(platformId: 42)), isTrue);
      expect(calls.map((c) => c.method), [
        'AlarmService.start',
        'Alarm.oneShotAt',
        'Alarm.oneShotAt',
      ]);
      expect(calls.first.arguments, [_dispatcherHandle]);
      final args = named('Alarm.oneShotAt').first.arguments as List<Object?>;
      // [id, alarmClock, allowWhileIdle, exact, wakeup, startMillis,
      //  rescheduleOnReboot, callbackHandle, params]
      expect(args.sublist(0, 8), [
        41,
        false,
        true,
        true,
        true,
        entry().atUtc.millisecondsSinceEpoch,
        true,
        _firedHandle,
      ]);
      final params = (args[8]! as Map<Object?, Object?>)
          .cast<String, Object?>();
      expect(alarmFromParams(params), entry().alarm);
    });

    test('the alarmClock flag (RELAY\'s P3-R3) sets an alarm clock', () async {
      await AlarmManagerScheduler(_onFire, alarmClock: true).schedule(entry());
      expect(oneShotArgs()[1], isTrue);
    });

    test('a refused alarm answers false', () async {
      final scheduler = AlarmManagerScheduler(_onFire);
      accepted = false;
      expect(await scheduler.schedule(entry()), isFalse);
    });

    test('a platform id the system cannot take, or a local instant, is '
        'refused before any call', () async {
      final scheduler = AlarmManagerScheduler(_onFire);
      for (final id in [-1, 1 << 31]) {
        await expectLater(
          scheduler.schedule(entry(platformId: id)),
          throwsArgumentError,
        );
      }
      await expectLater(
        scheduler.schedule(
          RegisteredAlarm(
            alarmId: 'r',
            platformId: 1,
            atUtc: DateTime(2026, 10, 24, 9),
          ),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });
  });

  test(
    'cancel calls the plugin\'s cancel, which prunes its reboot list',
    () async {
      await AlarmManagerScheduler(_onFire).cancel(41);
      expect(calls.single.method, 'Alarm.cancel');
      expect(calls.single.arguments, [41]);
    },
  );

  test(
    'canScheduleExact: USE_EXACT_ALARM by default, or the app\'s answer',
    () async {
      expect(await AlarmManagerScheduler(_onFire).canScheduleExact(), isTrue);
      var answer = false;
      final scheduler = AlarmManagerScheduler(
        _onFire,
        canScheduleExact: () async => answer,
      );
      expect(await scheduler.canScheduleExact(), isFalse);
      answer = true;
      expect(await scheduler.canScheduleExact(), isTrue);
    },
  );

  test(
    'the battery-optimisation settings open through SystemSettings',
    () async {
      final settings = FakeSystemSettings();
      await AlarmManagerScheduler(
        _onFire,
        settings: settings,
      ).openBatteryOptimisationSettings();
      expect(settings.batterySettingsOpened, 1);
    },
  );

  test('construction touches no platform channel', () {
    AlarmManagerScheduler(_onFire);
    expect(calls, isEmpty);
  });

  group('the fire entry', () {
    AlarmRegistry registry() => AlarmRegistry(() async => dir);

    Future<Map<String, dynamic>> scheduledParams() async {
      await AlarmManagerScheduler(_onFire).schedule(entry(platformId: 1));
      return (oneShotArgs()[8]! as Map<Object?, Object?>).cast();
    }

    test('records the fire, delivers the alarm, then cancels the platform '
        'alarm', () async {
      final params = await scheduledParams();
      final fired = entry().atUtc.add(const Duration(seconds: 3));
      final delivered = <ScheduledAlarm>[];
      await onAlarmFired(
        platformId: 1,
        params: params,
        firedUtc: fired,
        registry: registry(),
        deliver: (alarm) async => delivered.add(alarm),
      );
      expect(await registry().fires(), [
        FiredAlarm(
          alarmId: entry().alarmId,
          platformId: 1,
          scheduledAtUtc: entry().atUtc,
          firedAtUtc: fired,
        ),
      ]);
      expect(delivered, [entry().alarm]);
      expect(named('Alarm.cancel').single.arguments, [1]);
    });

    test('a delivery that fails still leaves the fire recorded and the '
        'platform alarm cancelled, and is thrown', () async {
      final params = await scheduledParams();
      await expectLater(
        onAlarmFired(
          platformId: 1,
          params: params,
          firedUtc: t0,
          registry: registry(),
          deliver: (_) async => throw PlatformException(code: 'boom'),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(await registry().fires(), hasLength(1));
      expect(named('Alarm.cancel'), hasLength(1));
    });

    test('params that are not an alarm\'s are refused before anything is '
        'recorded or delivered', () async {
      var delivered = 0;
      await expectLater(
        onAlarmFired(
          platformId: 1,
          params: const {'alarmId': 'r-1'},
          firedUtc: t0,
          registry: registry(),
          deliver: (_) async => delivered++,
        ),
        throwsFormatException,
      );
      expect(await registry().fires(), isEmpty);
      expect(delivered, 0);
      expect(calls, isEmpty);
    });

    test('through AlarmSync: a fired alarm is not armed again at its '
        'instant, and its entry is dropped', () async {
      final scheduler = AlarmManagerScheduler(_onFire);
      final sync = AlarmSync(scheduler, registry());
      final wanted = [entry().alarm];
      await sync.resync(wanted: wanted, now: t0);
      final params = (oneShotArgs()[8]! as Map<Object?, Object?>)
          .cast<String, dynamic>();
      await onAlarmFired(
        platformId: oneShotArgs().first! as int,
        params: params,
        firedUtc: entry().atUtc,
        registry: registry(),
        deliver: (_) async {},
      );
      calls.clear();
      await sync.resync(wanted: wanted, now: entry().atUtc);
      expect(named('Alarm.oneShotAt'), isEmpty);
      expect(await registry().entries(), isEmpty);
    });
  });
}
