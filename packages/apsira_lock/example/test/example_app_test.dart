// The example's smoke test: with the lock turned on in its store, the app
// starts behind the cover and the prompt (a fake here; local_auth on a
// device) opens it; hide in recents reaches the screen-privacy port.
import 'package:apsira_core/testing.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_lock_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locked at start; the prompt opens the Settings rows', (
    tester,
  ) async {
    final auth = FakeAuthenticator();
    final privacy = FakeScreenPrivacy();
    await tester.pumpWidget(
      ProviderScope(
        overrides: ExampleApp.overridesFor(
          authenticator: auth,
          screenPrivacy: privacy,
          clock: FakeClock(DateTime.utc(2026, 10, 24)),
          store: FakeLockSettingsStore(
            row: const LockSettings(
              enabled: true,
              hideInRecents: true,
            ).toJson(),
          ),
        ),
        child: const ExampleApp(),
      ),
    );
    expect(find.byKey(const Key('lock/cover')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(auth.prompts, 1);
    expect(find.byKey(const Key('lock/cover')), findsNothing);
    expect(find.byType(LockSettingsSection), findsOneWidget);
    expect(privacy.calls, [true]);
  });
}
