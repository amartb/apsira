// From relay test/data/platform/local_notifier_test.dart @ 09b28810, with
// viaticum test/data/platform/local_notifier_test.dart @ 78d38e0's channel and
// tap cases: the plugin's own Dart code runs and its method channel is
// answered by a recording handler. The channels are the apps' specs
// (D-APK-021): RELAY's and VIATICUM's ids reach the plugin unchanged.
import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_test/flutter_test.dart';

/// The background response entry the tests hand the notifier.
@pragma('vm:entry-point')
void _onBackground(Object response) {}

const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

// RELAY's four channels, as RELAY passes them.
const _reminders = NotificationChannelSpec(
  'relay_reminders',
  'Reminders',
  importance: NotificationImportance.high,
  category: NotificationCategory.reminder,
  privateOnLockScreen: true,
);
const _recording = NotificationChannelSpec(
  'relay_recording',
  'Recording',
  importance: NotificationImportance.low,
);
const _backups = NotificationChannelSpec('relay_backups', 'Backups');
const _calendar = NotificationChannelSpec(
  'relay_calendar',
  'Calendar',
  importance: NotificationImportance.high,
  category: NotificationCategory.event,
  privateOnLockScreen: true,
);

// VIATICUM's two, as VIATICUM passes them.
const _alerts = NotificationChannelSpec(
  'alerts',
  'Avisos',
  description: 'Recordatorios fuera del horario de sala',
);
const _quiet = NotificationChannelSpec(
  'quiet',
  'Silencioso',
  importance: NotificationImportance.low,
  description: 'Durante el horario de sala',
  silent: true,
);

const _actions = [
  NotificationAction(actionId: 'done', label: 'Done'),
  NotificationAction(actionId: 'snooze10', label: 'Snooze 10 min'),
  NotificationAction(actionId: 'snooze', label: 'Snooze…', opensApp: true),
];

const _reminder = AppNotification(
  notificationId: 41,
  title: 'Call the bank',
  body: 'Today 09:00',
  channel: _reminders,
  payload: 'r-1',
  actions: _actions,
);

LocalNotifier _relay({SystemSettings? settings}) => LocalNotifier(
  statusIcon: 'ic_stat_relay',
  onBackground: _onBackground,
  settings: settings ?? FakeSystemSettings(),
);

LocalNotifier _viaticum() =>
    LocalNotifier(statusIcon: '@drawable/ic_stat_viaticum');

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

  Map<Object?, Object?> args(String method) =>
      calls.lastWhere((c) => c.method == method).arguments as Map;

  Map<Object?, Object?> shownAndroid() =>
      args('show')['platformSpecifics'] as Map;

  Iterable<String> methods() => calls.map((c) => c.method);

  group('RELAY', () {
    test('the first call initialises the plugin once, with the status-bar '
        'icon and the background response entry', () async {
      final notifier = _relay();
      await notifier.show(_reminder);
      await notifier.cancel(41);
      expect(methods(), ['initialize', 'show', 'cancel']);
      final init = calls.first.arguments as Map;
      expect(init['defaultIcon'], 'ic_stat_relay');
      expect(init['callback_handle'], isA<int>());
      expect(init['dispatcher_handle'], isA<int>());
    });

    test('a reminder goes to the high-importance Reminders channel and stays '
        'when its body is tapped', () async {
      await _relay().show(_reminder);
      final shown = args('show');
      expect(shown['id'], 41);
      expect(shown['title'], 'Call the bank');
      expect(shown['body'], 'Today 09:00');
      expect(shown['payload'], 'r-1');
      final android = shownAndroid();
      expect(android['channelId'], 'relay_reminders');
      expect(android['channelName'], 'Reminders');
      expect(android['importance'], fln.Importance.high.value);
      expect(android['priority'], fln.Priority.high.value);
      expect(android['category'], 'reminder');
      expect(android['autoCancel'], isFalse, reason: 'critic R6, P3-R6');
    });

    test('Done and Snooze 10 min run in the background and dismiss; Snooze… '
        'opens the app and leaves the notification (P3-R6)', () async {
      await _relay().show(_reminder);
      final actions = (shownAndroid()['actions'] as List)
          .cast<Map<Object?, Object?>>();
      expect(
        [
          for (final a in actions)
            (
              a['id'],
              a['title'],
              a['showsUserInterface'],
              a['cancelNotification'],
            ),
        ],
        [
          ('done', 'Done', false, true),
          ('snooze10', 'Snooze 10 min', false, true),
          ('snooze', 'Snooze…', true, false),
        ],
      );
    });

    test('a reminder and a calendar item\'s reminder are private on the lock '
        'screen (R-8): their content shows only once unlocked', () async {
      final notifier = _relay();
      await notifier.show(_reminder);
      expect(
        shownAndroid()['visibility'],
        fln.NotificationVisibility.private.index,
      );
      await notifier.show(
        const AppNotification(
          notificationId: 42,
          title: 'Dentist',
          body: '10:00–11:00',
          channel: _calendar,
        ),
      );
      final android = shownAndroid();
      expect(android['channelId'], 'relay_calendar');
      expect(android['category'], 'event');
      expect(android['visibility'], fln.NotificationVisibility.private.index);
    });

    test(
      'a notification\'s public title is its lock-screen version (R-10, '
      'D-217): the patched plugin\'s publicVersion; none without one',
      () async {
        final notifier = _relay();
        await notifier.show(
          const AppNotification(
            notificationId: 43,
            title: 'Call the bank',
            body: 'Due today at 18:55',
            channel: _reminders,
            publicTitle: 'Reminder · 18:55',
          ),
        );
        final android = shownAndroid();
        expect(android['publicVersionTitle'], 'Reminder · 18:55');
        expect(android['publicVersionBody'], isNull);
        expect(android['visibility'], fln.NotificationVisibility.private.index);
        await notifier.show(_reminder);
        expect(shownAndroid().containsKey('publicVersionTitle'), isFalse);
      },
    );

    test('the Recording channel is at low importance', () async {
      await _relay().show(
        const AppNotification(
          notificationId: 1,
          title: 'Recording',
          body: '',
          channel: _recording,
        ),
      );
      final android = shownAndroid();
      expect(android['channelId'], 'relay_recording');
      expect(android['importance'], fln.Importance.low.value);
      expect(android['priority'], fln.Priority.low.value);
      expect(android['visibility'], isNull);
    });

    test('the Backups channel carries a failed scheduled backup at default '
        'importance, a tap opening the app (R-16, D-116)', () async {
      await _relay().show(
        const AppNotification(
          notificationId: -1,
          title: 'Backup failed',
          body: 'Relay can\'t reach the backup folder',
          channel: _backups,
        ),
      );
      final shown = args('show');
      expect(shown['id'], -1);
      final android = shownAndroid();
      expect(android['channelId'], 'relay_backups');
      expect(android['channelName'], 'Backups');
      expect(android['importance'], fln.Importance.defaultImportance.value);
      expect(android['priority'], fln.Priority.defaultPriority.value);
      expect(android['category'], isNull);
    });

    test('more than three actions are refused before any call', () async {
      await expectLater(
        _relay().show(
          const AppNotification(
            notificationId: 2,
            title: 't',
            body: 'b',
            channel: _reminders,
            actions: [
              ..._actions,
              NotificationAction(actionId: 'x', label: 'x'),
            ],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, isEmpty);
    });

    test('a group bundles a calendar day\'s reminders', () async {
      await _relay().show(
        const AppNotification(
          notificationId: 44,
          title: 'Dentist',
          body: '10:00',
          channel: _calendar,
          group: 'calendar:2026-10-24',
        ),
      );
      expect(shownAndroid()['groupKey'], 'calendar:2026-10-24');
    });

    test('a tap or an app-opening action while the app runs arrives on '
        'responses', () async {
      final notifier = _relay();
      final next = notifier.responses.first;
      await notifier.launchResponse();
      await messenger.handlePlatformMessage(
        _plugin.name,
        _plugin.codec.encodeMethodCall(
          const MethodCall('didReceiveNotificationResponse', {
            'notificationId': 41,
            'actionId': 'snooze',
            'payload': 'r-1',
            'notificationResponseType': 1,
          }),
        ),
        (_) {},
      );
      expect(
        await next,
        const NotificationResponse(
          notificationId: 41,
          actionId: 'snooze',
          payload: 'r-1',
        ),
      );
    });

    test('launchResponse is the tap that started the app, else null', () async {
      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 41,
          'payload': 'r-1',
          'notificationResponseType': 0,
        },
      };
      expect(
        await _relay().launchResponse(),
        const NotificationResponse(notificationId: 41, payload: 'r-1'),
      );
      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': false,
      };
      expect(await _relay().launchResponse(), isNull);
      answers['getNotificationAppLaunchDetails'] = null;
      expect(await _relay().launchResponse(), isNull);
    });

    test('the permission is read and asked through the plugin', () async {
      final notifier = _relay();
      answers['areNotificationsEnabled'] = false;
      expect(await notifier.permissionGranted(), isFalse);
      answers['requestNotificationsPermission'] = true;
      expect(await notifier.requestPermission(), isTrue);
      answers['requestNotificationsPermission'] = null;
      expect(await notifier.requestPermission(), isFalse);
      expect(
        methods(),
        containsAllInOrder([
          'areNotificationsEnabled',
          'requestNotificationsPermission',
        ]),
      );
    });

    test(
      'openNotificationSettings opens the app\'s notification settings',
      () async {
        final settings = FakeSystemSettings();
        await _relay(settings: settings).openNotificationSettings();
        expect(settings.notificationSettingsOpened, 1);
        expect(calls, isEmpty, reason: 'not through the plugin');
      },
    );

    test('responseOf turns the plugin\'s response into the port\'s', () {
      expect(
        LocalNotifier.responseOf(
          fln.NotificationResponse(
            notificationResponseType:
                fln.NotificationResponseType.selectedNotificationAction,
            id: 41,
            actionId: 'done',
            payload: 'r-1',
          ),
        ),
        const NotificationResponse(
          notificationId: 41,
          actionId: 'done',
          payload: 'r-1',
        ),
      );
      expect(LocalNotifier.responseOf('not a response'), isNull);
      expect(
        LocalNotifier.responseOf(
          const fln.NotificationResponse(
            notificationResponseType:
                fln.NotificationResponseType.selectedNotification,
          ),
        ),
        isNull,
        reason: 'no notification ID',
      );
    });

    test('construction touches no platform channel', () {
      _relay();
      expect(calls, isEmpty);
    });
  });

  group('VIATICUM: channels (07 §7.3)', () {
    test('ensureChannels initialises once, with the status-bar icon, and '
        'creates alerts and quiet under their localised names', () async {
      final notifier = _viaticum();
      await notifier.ensureChannels(const [_alerts, _quiet]);
      await notifier.ensureChannels(const [_alerts, _quiet]);
      expect(methods().where((m) => m == 'initialize'), hasLength(1));
      expect(args('initialize')['defaultIcon'], '@drawable/ic_stat_viaticum');
      expect(
        args('initialize').containsKey('dispatcher_handle'),
        isFalse,
        reason: 'no background actions',
      );
      final created = [
        for (final c in calls)
          if (c.method == 'createNotificationChannel') c.arguments as Map,
      ];
      expect(created, hasLength(4));
      final alerts = created[0];
      expect(alerts['id'], 'alerts');
      expect(alerts['name'], 'Avisos');
      expect(alerts['description'], _alerts.description);
      expect(alerts['importance'], fln.Importance.defaultImportance.value);
      expect(alerts['playSound'], isTrue);
      expect(alerts['enableVibration'], isTrue);
      final quiet = created[1];
      expect(quiet['id'], 'quiet');
      expect(quiet['name'], 'Silencioso');
      expect(quiet['description'], _quiet.description);
      expect(quiet['importance'], fln.Importance.low.value);
      expect(quiet['playSound'], isFalse);
      expect(quiet['enableVibration'], isFalse);
    });

    test('a failed initialisation is tried again on the next call', () async {
      messenger.setMockMethodCallHandler(_plugin, (call) async {
        calls.add(call);
        if (call.method == 'initialize' &&
            methods().where((m) => m == 'initialize').length == 1) {
          throw PlatformException(code: 'boom');
        }
        return answers[call.method] ?? true;
      });
      final notifier = _viaticum();
      await expectLater(
        notifier.ensureChannels(const [_alerts]),
        throwsA(anything),
      );
      await notifier.ensureChannels(const [_alerts]);
      expect(methods().where((m) => m == 'initialize'), hasLength(2));
    });

    test('the specs travel as JSON, so an alarm\'s background engine posts '
        'under the same channels', () {
      for (final spec in [_alerts, _quiet, _reminders, _calendar]) {
        expect(NotificationChannelSpec.fromJson(spec.toJson()), spec);
      }
      expect(
        () => NotificationChannelSpec.fromJson(const {'id': 'x'}),
        throwsFormatException,
      );
      expect(
        () => NotificationChannelSpec.fromJson({
          ..._alerts.toJson(),
          'importance': 'loud',
        }),
        throwsFormatException,
      );
    });

    test('an alerts notification is posted on alerts, at default importance, '
        'with sound and vibration as the phone is set, and no visibility '
        '(A-8)', () async {
      await _viaticum().show(
        AppNotification(
          notificationId: notificationIdFor('r-1'),
          channel: _alerts,
          title: 'Pedido',
          body: 'Vence mañana',
          payload: 'reminder:order_deadline:o-1',
          dismissOnTap: true,
        ),
      );
      final shown = args('show');
      expect(shown['id'], notificationIdFor('r-1'));
      expect(shown['payload'], 'reminder:order_deadline:o-1');
      final android = shownAndroid();
      expect(android['channelId'], 'alerts');
      expect(android['channelName'], 'Avisos');
      expect(android['channelDescription'], _alerts.description);
      expect(android['importance'], fln.Importance.defaultImportance.value);
      expect(android['playSound'], isTrue);
      expect(android['enableVibration'], isTrue);
      expect(android['silent'], isFalse);
      expect(android['autoCancel'], isTrue, reason: 'a tap opens the app');
      expect(android['visibility'], isNull);
      expect(android['actions'], isNull);
    });

    test('a quiet notification is posted on quiet: low importance, no sound, '
        'no vibration, silent', () async {
      await _viaticum().show(
        const AppNotification(
          notificationId: 2,
          channel: _quiet,
          title: 'Pedido',
          body: 'Hoy',
        ),
      );
      expect(args('show')['payload'], isEmpty, reason: 'none is sent as ""');
      final android = shownAndroid();
      expect(android['channelId'], 'quiet');
      expect(android['channelName'], 'Silencioso');
      expect(android['importance'], fln.Importance.low.value);
      expect(android['priority'], fln.Priority.low.value);
      expect(android['playSound'], isFalse);
      expect(android['enableVibration'], isFalse);
      expect(android['silent'], isTrue);
    });

    test('cancel removes the notification shown under the same ID', () async {
      await _viaticum().cancel(notificationIdFor('r-1'));
      expect(args('cancel')['id'], notificationIdFor('r-1'));
    });

    test('permissionGranted reads whether notifications are enabled, '
        'without asking; no answer is a refusal', () async {
      for (final (answer, granted) in [
        (true, true),
        (false, false),
        (null, false),
      ]) {
        answers['areNotificationsEnabled'] = answer;
        expect(
          await _viaticum().permissionGranted(),
          granted,
          reason: '$answer',
        );
      }
      expect(methods(), isNot(contains('requestNotificationsPermission')));
    });
  });

  group('VIATICUM: taps', () {
    Future<void> tap(String? payload) => messenger.handlePlatformMessage(
      _plugin.name,
      _plugin.codec.encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', {
          'notificationId': 7,
          'payload': payload,
          'notificationResponseType': 0,
        }),
      ),
      (_) {},
    );

    test('a tap while the app runs gives the notification\'s payload; one '
        'without a payload gives none', () async {
      final notifier = _viaticum();
      final taps = <NotificationResponse>[];
      final sub = notifier.responses.listen(taps.add);
      addTearDown(sub.cancel);
      await notifier.ensureChannels(const [_alerts, _quiet]);
      await tap('reminder:order_deadline:o-1');
      await tap(null);
      await tap('');
      await pumpEventQueue();
      expect(taps, const [
        NotificationResponse(
          notificationId: 7,
          payload: 'reminder:order_deadline:o-1',
        ),
        NotificationResponse(notificationId: 7),
        NotificationResponse(notificationId: 7),
      ]);
    });

    test('launchResponse is the payload of the tap that started the app, and '
        'null when no tap did', () async {
      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 7,
          'notificationResponseType': 0,
          'payload': 'reminder:credential_expiry:c-1',
        },
      };
      expect(
        (await _viaticum().launchResponse())?.payload,
        'reminder:credential_expiry:c-1',
      );
      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': false,
      };
      expect(await _viaticum().launchResponse(), isNull);
    });
  });

  group('the fake', () {
    test('records channels, refuses a duplicate id and four actions, and '
        'answers the launch once', () async {
      final fake = FakeNotifier();
      addTearDown(fake.dispose);
      await fake.ensureChannels(const [_alerts, _quiet]);
      expect(fake.channels.keys, ['alerts', 'quiet']);
      expect(
        () => fake.ensureChannels(const [_alerts, _alerts]),
        throwsArgumentError,
      );
      await expectLater(
        fake.show(
          const AppNotification(
            notificationId: 1,
            title: 't',
            body: 'b',
            channel: _reminders,
            actions: [
              ..._actions,
              NotificationAction(actionId: 'x', label: 'x'),
            ],
          ),
        ),
        throwsArgumentError,
      );
      fake.launchedBy = const NotificationResponse(notificationId: 1);
      expect(await fake.launchResponse(), isNotNull);
      expect(await fake.launchResponse(), isNull);
    });
  });
}
