// From relay test/features/lock/recents_privacy_test.dart @ 09b28810,
// unchanged but for names (D-APK-016): a change of the setting is an update
// through lockSettingsProvider, and the gate is LockShield.
//
// Hide in recents: `hideInRecents` sets ScreenPrivacy.setHidden(true) at
// launch and on every change of the setting, and off sets false, whether the
// lock itself is on or not. The window flag is re-applied on every return
// from the background, since Android does not keep it when it recreates the
// activity. A port that throws or is unbound is logged with the error's type
// only and never stops the app or the lock.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const hide = LockSettings(hideInRecents: true);

void main() {
  late FakeClock clock;
  late MemorySink sink;
  late FakeScreenPrivacy privacy;

  setUp(() {
    clock = FakeClock(t0);
    sink = MemorySink();
    privacy = FakeScreenPrivacy();
  });

  ProviderContainer start(LockSettingsStore store) {
    final container = ProviderContainer(
      overrides: lockOverrides(
        store: store,
        authenticator: FakeAuthenticator(),
        clock: clock,
        sink: sink,
        screenPrivacy: privacy,
      ),
    );
    addTearDown(container.dispose);
    container.listen(lockControllerProvider, (_, _) {});
    return container;
  }

  group('hide in recents', () {
    test('recents: on hides at launch, lock off or on', () async {
      start(settingsOf(hide));
      await pumpEventQueue();
      expect(privacy.calls, [true]);

      privacy.calls.clear();
      start(settingsOf(const LockSettings(enabled: true, hideInRecents: true)));
      await pumpEventQueue();
      expect(privacy.calls, [true]);
    });

    test('recents: off shows at launch', () async {
      start(settingsOf(const LockSettings()));
      await pumpEventQueue();
      expect(privacy.calls, [false]);
      expect(privacy.hidden, isFalse);
    });

    test('recents: every change of the setting is applied; other lock '
        'changes are not', () async {
      final c = start(settingsOf(const LockSettings()));
      await pumpEventQueue();
      for (final next in const [
        hide,
        LockSettings(hideInRecents: true, timeoutMinutes: 1),
        LockSettings(enabled: true, hideInRecents: true),
        LockSettings(enabled: true),
      ]) {
        await c.read(lockSettingsProvider.notifier).change((_) => next);
        await pumpEventQueue();
      }
      expect(privacy.calls, [false, true, false]);
      expect(privacy.hidden, isFalse);
    });

    test('recents: re-applied on every return from the background', () async {
      final c = start(settingsOf(hide));
      await pumpEventQueue();
      final controller = c.read(lockControllerProvider.notifier);
      for (var i = 0; i < 2; i++) {
        controller.backgrounded();
        controller.foregrounded();
        await pumpEventQueue();
      }
      expect(privacy.calls, [true, true, true]);
    });

    test('recents: nothing is applied before the setting is read', () async {
      final c = start(FakeLockSettingsStore()..holdReads());
      c.read(lockControllerProvider.notifier).foregrounded();
      await pumpEventQueue();
      expect(privacy.calls, isEmpty);
    });

    test('recents: a port that throws is logged by type and the lock still '
        'engages', () async {
      privacy.error = StateError('no activity');
      final c = start(
        settingsOf(const LockSettings(enabled: true, hideInRecents: true)),
      );
      await pumpEventQueue();
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
      expect(sink.lines, [
        'WARNING lock.recentsNotApplied errorType=StateError',
      ]);
    });

    test('recents: an unbound port is logged and never throws', () async {
      final container = ProviderContainer(
        overrides: [
          lockSettingsStoreProvider.overrideWithValue(settingsOf(hide)),
          authenticatorProvider.overrideWithValue(FakeAuthenticator()),
          lockClockProvider.overrideWithValue(clock),
          lockLogProvider.overrideWithValue(Log([sink], debugEnabled: false)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(lockControllerProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(lockControllerProvider).phase, LockPhase.unlocked);
      // Riverpod reports the unbound port's StateError wrapped.
      expect(sink.lines, [
        'WARNING lock.recentsNotApplied errorType=ProviderException',
      ]);
    });
  });

  group('hide in recents through the gate', () {
    Future<void> launch(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        overrides: lockOverrides(
          store: settingsOf(hide),
          authenticator: FakeAuthenticator(),
          clock: clock,
          sink: sink,
          screenPrivacy: privacy,
        ),
        child: MaterialApp(
          theme: ApsiraThemeData.light,
          darkTheme: ApsiraThemeData.dark,
          themeMode: ThemeMode.dark,
          localizationsDelegates: const [ApsiraL10n.delegate],
          supportedLocales: ApsiraL10n.supportedLocales,
          builder: (context, child) => LockShield(
            appTitle: 'Relay',
            promptReason: (_) => 'Unlock Relay',
            child: child!,
          ),
          home: const Text('content'),
        ),
      ),
    );

    testWidgets('recents: the gate re-applies the flag on every return to '
        'the foreground', (tester) async {
      await launch(tester);
      await tester.pumpAndSettle();
      expect(privacy.calls, [true]);

      for (var i = 0; i < 2; i++) {
        for (final state in const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
      }
      expect(privacy.calls, [true, true, true]);
      expect(privacy.hidden, isTrue);
    });

    testWidgets('recents: a trip to inactive (the shade) does not re-apply', (
      tester,
    ) async {
      await launch(tester);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(privacy.calls, [true]);
    });
  });
}
