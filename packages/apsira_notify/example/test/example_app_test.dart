// The example's smoke test: the reminder button creates the channel, asks
// for the permission and shows a reminder with three actions and a public
// title; each settings row opens its screen.
import 'package:apsira_notify/testing.dart';
import 'package:apsira_notify_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the reminder button shows a reminder on the app\'s channel', (
    tester,
  ) async {
    final notifier = FakeNotifier()..granted = false;
    addTearDown(notifier.dispose);
    final settings = FakeSystemSettings();
    await tester.pumpWidget(ExampleApp(notifier: notifier, settings: settings));

    await tester.tap(find.text('Show a reminder'));
    await tester.pumpAndSettle();
    expect(notifier.channels.keys, ['example_reminders']);
    expect(notifier.permissionRequests, 1);
    final shown = notifier.showing.values.single;
    expect(shown.actions, hasLength(3));
    expect(shown.publicTitle, 'Reminder · 09:00');

    for (final row in [
      'Notification settings',
      'Battery optimisation',
      'App details',
    ]) {
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
    }
    expect(
      (
        settings.notificationSettingsOpened,
        settings.batterySettingsOpened,
        settings.appDetailsOpened,
      ),
      (1, 1, 1),
    );
  });
}
