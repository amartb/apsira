// From relay test/app/services/notification_permission_service_test.dart @
// 09b28810 (the access and askForReminder groups; the late-delivery card stays
// in RELAY) and viaticum
// test/app/services/notification_permission_service_test.dart @ 78d38e0 (the
// per-install asked flag): the flow of D-APK-021.
import 'dart:io';

import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _askedPath = 'reminders/permission_asked.json';

void main() {
  late Directory storage;
  late FakeNotifier notifier;
  late bool exactAllowed;

  InstallFlag flag() =>
      InstallFlag(directory: () async => storage, path: _askedPath);

  NotificationPermissionFlow build() => NotificationPermissionFlow(
    notifier,
    asked: flag(),
    exactAlarmsAllowed: () async => exactAllowed,
  );

  setUp(() {
    storage = Directory.systemTemp.createTempSync('apsira-notify-permission-');
    notifier = FakeNotifier();
    exactAllowed = true;
  });

  tearDown(() async {
    await notifier.dispose();
    storage.deleteSync(recursive: true);
  });

  group('access', () {
    test('allowed with notifications and exact alarms', () async {
      expect(await build().access(), ReminderAccess.allowed);
      expect(ReminderAccess.allowed.isAllowed, isTrue);
    });

    test('notifications denied comes first', () async {
      notifier.granted = false;
      exactAllowed = false;
      expect(await build().access(), ReminderAccess.notificationsDenied);
      expect(ReminderAccess.notificationsDenied.isAllowed, isFalse);
    });

    test('exact alarms not allowed', () async {
      exactAllowed = false;
      expect(await build().access(), ReminderAccess.exactAlarmsDenied);
      expect(ReminderAccess.exactAlarmsDenied.isAllowed, isFalse);
    });

    test('without an exact-alarm check they count as allowed', () async {
      expect(
        await NotificationPermissionFlow(notifier, asked: flag()).access(),
        ReminderAccess.allowed,
      );
    });

    test('asks nothing', () async {
      notifier.granted = false;
      await build().access();
      expect(notifier.permissionRequests, 0);
      expect(await flag().isSet(), isFalse);
    });
  });

  group('askFor', () {
    test('granted: no explanation, no prompt, no flag', () async {
      var explained = 0;
      final access = await build().askFor(
        explain: () async {
          explained++;
          return true;
        },
      );
      expect(access, ReminderAccess.allowed);
      expect(explained, 0);
      expect(notifier.permissionRequests, 0);
      expect(await flag().isSet(), isFalse);
    });

    test('not granted: the explanation first, then the prompt, the flag '
        'written before it', () async {
      notifier.granted = false;
      final requestsWhenExplained = <int>[];
      final flow = build();
      final access = await flow.askFor(
        explain: () async {
          requestsWhenExplained.add(notifier.permissionRequests);
          return true;
        },
      );
      expect(requestsWhenExplained, [0]);
      expect(notifier.permissionRequests, 1);
      expect(access, ReminderAccess.allowed);
      expect(await flow.asked(), isTrue);
      expect(File('${storage.path}/$_askedPath').existsSync(), isTrue);
    });

    test('Not now on the explanation: no prompt, no flag, reminders off; the '
        'next reminder explains and prompts again', () async {
      notifier.granted = false;
      final access = await build().askFor(explain: () async => false);
      expect(notifier.permissionRequests, 0);
      expect(access, ReminderAccess.notificationsDenied);
      expect(await flag().isSet(), isFalse);

      await build().askFor(explain: () async => true);
      expect(notifier.permissionRequests, 1);
    });

    test('a denial leaves reminders off; the next ask opens the settings, '
        'never a second prompt (VIATICUM\'s once per install)', () async {
      notifier
        ..granted = false
        ..grantOnRequest = false;
      final access = await build().askFor(explain: () async => true);
      expect(notifier.permissionRequests, 1);
      expect(access, ReminderAccess.notificationsDenied);

      final again = await build().askFor(explain: () async => true);
      expect(again, ReminderAccess.notificationsDenied);
      expect(notifier.permissionRequests, 1);
      expect(notifier.settingsOpened, 1);
    });

    test('once asked, Not now opens nothing', () async {
      notifier.granted = false;
      await flag().set();
      await build().askFor(explain: () async => false);
      expect(notifier.permissionRequests, 0);
      expect(notifier.settingsOpened, 0);
    });

    test('granted but exact alarms not allowed', () async {
      notifier.granted = false;
      exactAllowed = false;
      final access = await build().askFor(explain: () async => true);
      expect(access, ReminderAccess.exactAlarmsDenied);
    });

    test('Fix opens the notification settings', () async {
      await build().openNotificationSettings();
      expect(notifier.settingsOpened, 1);
    });
  });

  group('the flag is per install (C1)', () {
    test('it lives at the app\'s path in app storage, not in a database; a '
        'fresh storage (a reinstall, a new phone) asks again', () async {
      notifier.granted = false;
      await build().askFor(explain: () async => true);
      expect(File('${storage.path}/$_askedPath').existsSync(), isTrue);

      final fresh = Directory.systemTemp.createTempSync('apsira-notify-new-');
      addTearDown(() => fresh.deleteSync(recursive: true));
      final newPhone = FakeNotifier()..granted = false;
      addTearDown(newPhone.dispose);
      await NotificationPermissionFlow(
        newPhone,
        asked: InstallFlag(directory: () async => fresh, path: _askedPath),
      ).askFor(explain: () async => true);
      expect(newPhone.permissionRequests, 1);
    });
  });
}
