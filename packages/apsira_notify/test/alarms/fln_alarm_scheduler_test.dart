// From lyceum test/services/notification_service_test.dart @ 9f4ff27 (a past
// time dropped, exact while idle, in UTC), against the patched plugin's own
// Dart code with its method channel answered by a recording handler; the
// ids are the registry's (D-APK-022).
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

const _alerts = NotificationChannelSpec(
  'lyceum_alerts',
  'Submission alerts',
  privateOnLockScreen: true,
);

const _actions = [
  NotificationAction(actionId: 'done', label: 'Done'),
  NotificationAction(actionId: 'snooze10', label: '+10 min'),
  NotificationAction(actionId: 'snooze', label: 'Snooze…', opensApp: true),
];

// The plugin's own check of a future date reads the real clock.
final t0 = DateTime.utc(2099, 1, 1, 9);

RegisteredAlarm entry({
  int platformId = 7,
  Duration after = const Duration(hours: 1),
}) => RegisteredAlarm(
  alarmId: 'submission:s1:followup',
  platformId: platformId,
  atUtc: t0.add(after),
  content: const {'title': 'Follow up', 'body': 'Journal X'},
);

AppNotification notificationOf(RegisteredAlarm alarm) => AppNotification(
  notificationId: alarm.platformId,
  title: alarm.content['title']! as String,
  body: alarm.content['body']! as String,
  channel: _alerts,
  actions: _actions,
  publicTitle: 'LYCEUM · alert',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<Map<String, Object?>> pending;

  setUp(() {
    calls = [];
    pending = [];
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      calls.add(call);
      return switch (call.method) {
        'pendingNotificationRequests' => pending,
        'canScheduleExactNotifications' => true,
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(_plugin, null));

  FlnAlarmScheduler scheduler({
    AlarmNotificationBuilder build = notificationOf,
    Future<void> Function()? ready,
    FakeSystemSettings? settings,
  }) => FlnAlarmScheduler(
    notificationOf: build,
    ready: ready,
    settings: settings ?? FakeSystemSettings(),
    now: () => t0,
  );

  test('schedules exact while idle, in UTC, under the registry\'s id, with '
      'the notification\'s channel, actions and public version', () async {
    var readied = 0;
    final s = scheduler(ready: () async => readied++);
    expect(await s.schedule(entry()), isTrue);
    expect(readied, 1);
    final call = calls.single;
    expect(call.method, 'zonedSchedule');
    final args = call.arguments as Map;
    expect(args['id'], 7);
    expect(args['title'], 'Follow up');
    expect(args['body'], 'Journal X');
    expect(args['payload'], 'submission:s1:followup');
    expect(args['timeZoneName'], 'Etc/UTC');
    expect(args['scheduledDateTime'], '2099-01-01T10:00:00');
    final android = args['platformSpecifics'] as Map;
    expect(android['scheduleMode'], 'exactAllowWhileIdle');
    expect(android['channelId'], 'lyceum_alerts');
    expect((android['actions'] as List).map((a) => (a as Map)['id']), [
      'done',
      'snooze10',
      'snooze',
    ]);
    expect(android['publicVersionTitle'], 'LYCEUM · alert');
    expect(android['visibility'], isNotNull);
  });

  test(
    'a time that is not ahead is skipped before the plugin is asked',
    () async {
      final s = scheduler();
      expect(await s.schedule(entry(after: Duration.zero)), isFalse);
      expect(
        await s.schedule(entry(after: const Duration(minutes: -5))),
        isFalse,
      );
      expect(calls, isEmpty);
    },
  );

  test('a notification under another id than the platform id, or with more '
      'than three actions, is refused before the plugin is asked', () async {
    await expectLater(
      scheduler(
        build: (a) => AppNotification(
          notificationId: a.platformId + 1,
          title: 't',
          body: 'b',
          channel: _alerts,
        ),
      ).schedule(entry()),
      throwsArgumentError,
    );
    await expectLater(
      scheduler(
        build: (a) => AppNotification(
          notificationId: a.platformId,
          title: 't',
          body: 'b',
          channel: _alerts,
          actions: [..._actions, _actions.first],
        ),
      ).schedule(entry()),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });

  test('cancel cancels a pending alarm only: a notification already showing '
      'stays', () async {
    final s = scheduler();
    await s.cancel(7);
    expect(calls.map((c) => c.method), ['pendingNotificationRequests']);
    pending = [
      {'id': 7, 'title': 'Follow up', 'body': 'Journal X', 'payload': 'p'},
    ];
    calls.clear();
    await s.cancel(7);
    expect(calls.map((c) => c.method), [
      'pendingNotificationRequests',
      'cancel',
    ]);
    expect((calls.last.arguments as Map)['id'], 7);
  });

  test('canScheduleExact asks the plugin; the battery settings open through '
      'SystemSettings', () async {
    final settings = FakeSystemSettings();
    final s = scheduler(settings: settings);
    expect(await s.canScheduleExact(), isTrue);
    await s.openBatteryOptimisationSettings();
    expect(settings.batterySettingsOpened, 1);
  });

  test('ids come from the registry through AlarmSync, which drops past '
      'alerts with lateGrace zero', () async {
    final dir = await Directory.systemTemp.createTemp('fln_sync_');
    addTearDown(() => dir.delete(recursive: true));
    final sync = AlarmSync(
      scheduler(),
      AlarmRegistry(() async => dir),
      lateGrace: Duration.zero,
    );
    final report = await sync.resync(
      wanted: [
        ScheduledAlarm(
          alarmId: 'a',
          atUtc: t0.add(const Duration(hours: 2)),
          content: const {'title': 'A', 'body': 'a'},
        ),
        ScheduledAlarm(
          alarmId: 'past',
          atUtc: t0.subtract(const Duration(hours: 2)),
          content: const {'title': 'P', 'body': 'p'},
        ),
      ],
      now: t0,
    );
    expect(report.scheduled, 1);
    expect(
      [
        for (final c in calls)
          if (c.method == 'zonedSchedule') (c.arguments as Map)['id'],
      ],
      [1],
    );
  });
}
