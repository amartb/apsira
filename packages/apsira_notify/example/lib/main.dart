// A minimal consumer of apsira_notify, bound as an Apsira app binds it: its
// own channel spec, a reminder with RELAY's three actions and a lock-screen
// public version, and the three settings screens through the package's
// channel. Its debug build is the proof that the package's Android half and
// the vendored plugin compile (AC-16.5).
import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter/material.dart';

/// The example's one channel: an app passes the id its installs already have.
const remindersChannel = NotificationChannelSpec(
  'example_reminders',
  'Reminders',
  importance: NotificationImportance.high,
  category: NotificationCategory.reminder,
  privateOnLockScreen: true,
);

/// The reminder the button shows.
AppNotification exampleReminder() => AppNotification(
  notificationId: notificationIdFor('example:reminder'),
  title: 'Call the bank',
  body: 'Today 09:00',
  channel: remindersChannel,
  payload: 'example:reminder',
  publicTitle: 'Reminder · 09:00',
  actions: const [
    NotificationAction(actionId: 'done', label: 'Done'),
    NotificationAction(actionId: 'snooze10', label: '+10 min'),
    NotificationAction(actionId: 'snooze', label: 'Snooze…', opensApp: true),
  ],
);

/// The background actions' entry point (Done, +10 min).
@pragma('vm:entry-point')
void onBackgroundResponse(Object response) {}

void main() {
  runApp(
    ExampleApp(
      notifier: LocalNotifier(
        statusIcon: 'ic_stat_example',
        onBackground: onBackgroundResponse,
      ),
      settings: const ChannelSystemSettings(),
    ),
  );
}

/// The example app: one button per call.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.notifier, required this.settings});

  final Notifier notifier;
  final SystemSettings settings;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_notify example',
    home: Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Show a reminder'),
              onTap: () async {
                await notifier.ensureChannels(const [remindersChannel]);
                if (!await notifier.permissionGranted()) {
                  await notifier.requestPermission();
                }
                await notifier.show(exampleReminder());
              },
            ),
            ListTile(
              title: const Text('Notification settings'),
              onTap: settings.openNotificationSettings,
            ),
            ListTile(
              title: const Text('Battery optimisation'),
              onTap: settings.openBatteryOptimisationSettings,
            ),
            ListTile(
              title: const Text('App details'),
              onTap: settings.openAppDetails,
            ),
          ],
        ),
      ),
    ),
  );
}
