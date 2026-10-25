// The crash matrix of apsira_notify (D-APK-021, kill points KP-N1…N3 of the
// packages-v0-4 task specs), written before the code. A kill is a
// `SimulatedCrash` thrown at the named step; the test then drops every object
// and builds new ones from what is on disk and on the platform, as a restarted
// process would.
import 'dart:io';

import 'package:apsira_app/apsira_app.dart';
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

/// The process dies while Android's prompt is up.
final class _DiesInPrompt extends FakeNotifier {
  @override
  Future<bool> requestPermission() async {
    await super.requestPermission();
    throw const SimulatedCrash('prompt');
  }
}

const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

const _reminders = NotificationChannelSpec(
  'relay_reminders',
  'Reminders',
  importance: NotificationImportance.high,
  category: NotificationCategory.reminder,
  privateOnLockScreen: true,
);

const _quiet = NotificationChannelSpec(
  'quiet',
  'Silencioso',
  importance: NotificationImportance.low,
  description: 'Durante el horario de sala',
  silent: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  final answers = <String, Object?>{};

  setUp(() {
    calls = [];
    answers
      ..clear()
      ..['initialize'] = true;
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      calls.add(call);
      return answers[call.method];
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_plugin, null));

  test('KP-N1 the asked flag is written before the prompt: a crash in the '
      'prompt leaves it set, and the next askFor opens the settings', () async {
    final storage = Directory.systemTemp.createTempSync('kp-n1-');
    addTearDown(() => storage.deleteSync(recursive: true));
    InstallFlag flag() => InstallFlag(
      directory: () async => storage,
      path: 'reminders/permission_asked.json',
    );

    final dying = _DiesInPrompt()..granted = false;
    await expectLater(
      NotificationPermissionFlow(
        dying,
        asked: flag(),
      ).askFor(explain: () async => true),
      throwsA(isA<SimulatedCrash>()),
    );
    expect(dying.permissionRequests, 1);
    expect(await flag().isSet(), isTrue, reason: 'written before the prompt');

    // The next start: the flag is on disk, the permission still missing.
    final notifier = FakeNotifier()..granted = false;
    var explained = 0;
    final access = await NotificationPermissionFlow(notifier, asked: flag())
        .askFor(
          explain: () async {
            explained++;
            return true;
          },
        );
    expect(access, ReminderAccess.notificationsDenied);
    expect(explained, 1);
    expect(notifier.permissionRequests, 0, reason: 'no second prompt');
    expect(notifier.settingsOpened, 1, reason: 'the settings path');
  });

  test('KP-N2 an action tapped while the process is dead is delivered once '
      'by launchResponse, and never again on the next start', () async {
    answers['getNotificationAppLaunchDetails'] = {
      'notificationLaunchedApp': true,
      'notificationResponse': {
        'notificationId': 41,
        'actionId': 'snooze',
        'payload': 'r-1',
        'notificationResponseType': 1,
      },
    };
    final first = LocalNotifier(statusIcon: 'ic_stat_test');
    expect(
      await first.launchResponse(),
      const NotificationResponse(
        notificationId: 41,
        actionId: 'snooze',
        payload: 'r-1',
      ),
    );
    expect(await first.launchResponse(), isNull, reason: 'delivered once');

    // The next start comes from recents: the plugin reports no launch by a
    // notification (its FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY check).
    answers['getNotificationAppLaunchDetails'] = {
      'notificationLaunchedApp': false,
    };
    expect(
      await LocalNotifier(statusIcon: 'ic_stat_test').launchResponse(),
      isNull,
    );
  });

  test('KP-N3 a crash after ensureChannels and before show leaves the '
      'channels as specified: the next start creates the same ones, no '
      'duplicate', () async {
    Iterable<Map<Object?, Object?>> created() => [
      for (final c in calls)
        if (c.method == 'createNotificationChannel') c.arguments as Map,
    ];

    await LocalNotifier(statusIcon: 'ic_stat_test')
        .ensureChannels(const [_reminders, _quiet]);
    final before = created().toList();
    expect(before.map((c) => c['id']), ['relay_reminders', 'quiet']);
    // Killed here, before any show.
    calls.clear();

    final next = LocalNotifier(statusIcon: 'ic_stat_test');
    await next.ensureChannels(const [_reminders, _quiet]);
    expect(created().toList(), before, reason: 'the same channels, by id');
    await next.show(
      const AppNotification(
        notificationId: 7,
        title: 'Call the bank',
        body: 'Today 09:00',
        channel: _reminders,
      ),
    );
    final shown = calls.lastWhere((c) => c.method == 'show').arguments as Map;
    expect((shown['platformSpecifics'] as Map)['channelId'], 'relay_reminders');
    expect(
      () => next.ensureChannels(const [_reminders, _reminders]),
      throwsArgumentError,
      reason: 'two specs with one id are refused',
    );
  });
}
