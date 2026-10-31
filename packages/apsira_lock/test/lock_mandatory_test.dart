// The mandatory lock never opens unlocked (D-018, D-APK-026, rulings R-1 and
// R-4): settings that cannot be read lock with the policy's defaults; a
// device that cannot prompt, or an Authenticator that throws, keeps the cover
// with the Unlock button as the retry and the app's own line, and logs
// `lock.notEngaged` with its code. No counter, no back-off. The same fakes
// under the optional policy open the app as they always have.
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const on = LockSettings(enabled: true);
const secret = 'Private vault entry';
const cover = Key('lock/cover');
const notice = Key('lock/notice');
const unlockButton = Key('lock/unlock');
const cannotPromptLine =
    'Set a screen lock in the phone\'s settings to open '
    'APSIRA.';

const cannotPrompt = LockState(
  LockPhase.locked,
  lastOutcome: AuthOutcome.unavailable,
);

final withMessage = LockPolicy.mandatory.copyWith(
  cannotPromptMessage: (_) => cannotPromptLine,
);

void main() {
  late FakeClock clock;
  late MemorySink sink;

  setUp(() {
    clock = FakeClock(t0);
    sink = MemorySink();
  });

  List<String> notEngaged() => [
    for (final line in sink.lines)
      if (line.contains('lock.notEngaged')) line,
  ];

  group('controller', () {
    ProviderContainer start({
      LockSettingsStore? store,
      bool unbound = false,
      required Authenticator authenticator,
      LockPolicy policy = LockPolicy.mandatory,
    }) {
      final c = ProviderContainer(
        overrides: lockOverrides(
          store: unbound ? null : store ?? settingsOf(on),
          authenticator: authenticator,
          clock: clock,
          sink: sink,
          policy: policy,
        ),
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      return c;
    }

    LockState stateOf(ProviderContainer c) => c.read(lockControllerProvider);
    LockController controllerOf(ProviderContainer c) =>
        c.read(lockControllerProvider.notifier);

    test(
      'a read that throws locks at launch with the policy\'s defaults',
      () async {
        final c = start(
          store: FakeLockSettingsStore(readError: StateError('closed')),
          authenticator: FakeAuthenticator(),
        );
        await pumpEventQueue();
        expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
        expect(controllerOf(c).settings.timeoutMinutes, 1);
      },
    );

    test('no store bound locks at launch', () async {
      final c = start(unbound: true, authenticator: FakeAuthenticator());
      await pumpEventQueue();
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
      expect(notEngaged(), isEmpty);
    });

    test('a stored "off" locks at launch', () async {
      final c = start(
        store: settingsOf(const LockSettings()),
        authenticator: FakeAuthenticator(),
      );
      await pumpEventQueue();
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
    });

    testWidgets('a read that hangs locks at launch after 1 s', (tester) async {
      final hang = FakeLockSettingsStore(row: on.toJson())..holdReads();
      final c = start(store: hang, authenticator: FakeAuthenticator());
      await tester.pump(mandatoryReadBound - const Duration(milliseconds: 1));
      expect(stateOf(c).phase, LockPhase.starting);
      await tester.pump(const Duration(milliseconds: 2));
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
      expect(controllerOf(c).settings.timeoutMinutes, 1);
      await tester.pump(lockSettingsReadBound * 2);
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
      hang.releaseReads();
      await tester.pump();
    });

    test('no screen lock: locked, cannot prompt, no prompt due', () async {
      final auth = FakeAuthenticator(available: false);
      final c = start(authenticator: auth);
      await pumpEventQueue();
      expect(stateOf(c), cannotPrompt);
      expect(stateOf(c).cannotPrompt, isTrue);
      expect(stateOf(c).promptDue, isFalse);
      expect(stateOf(c).canUnlock, isTrue);
      expect(stateOf(c).showRetry, isFalse);
      expect(auth.prompts, 0);
      expect(notEngaged(), ['WARNING lock.notEngaged code=unavailable']);
    });

    test('isAvailable throws: locked, cannot prompt', () async {
      final c = start(
        authenticator: ThrowingAuthenticator(onAuthenticate: false),
      );
      await pumpEventQueue();
      expect(stateOf(c), cannotPrompt);
      expect(notEngaged(), [
        'WARNING lock.notEngaged errorType=StateError code=authenticatorError',
      ]);
    });

    test('Unlock answered unavailable stays locked, cannot prompt', () async {
      final auth = FakeAuthenticator();
      final c = start(authenticator: auth);
      await pumpEventQueue();
      expect(stateOf(c).promptDue, isTrue);
      auth.available = false;
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c), cannotPrompt);
      expect(auth.prompts, 1);
      expect(notEngaged(), ['WARNING lock.notEngaged code=unavailable']);
    });

    test('Unlock that throws stays locked, cannot prompt', () async {
      final c = start(authenticator: ThrowingAuthenticator(onAvailable: false));
      await pumpEventQueue();
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c), cannotPrompt);
      expect(notEngaged(), [
        'WARNING lock.notEngaged errorType=StateError code=authenticatorError',
      ]);
    });

    test('once the device can prompt, passed unlocks', () async {
      final auth = FakeAuthenticator(available: false);
      final c = start(authenticator: auth);
      await pumpEventQueue();
      expect(stateOf(c), cannotPrompt);
      auth.available = true;
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c), const LockState(LockPhase.unlocked));
    });

    test('a return from the background makes the prompt due once', () async {
      final auth = FakeAuthenticator(available: false);
      final c = start(authenticator: auth);
      await pumpEventQueue();
      controllerOf(c)
        ..backgrounded()
        ..foregrounded();
      expect(
        stateOf(c),
        const LockState(
          LockPhase.locked,
          promptDue: true,
          lastOutcome: AuthOutcome.unavailable,
        ),
      );
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c), cannotPrompt);
      expect(auth.prompts, 1);
    });

    testWidgets('the shield calls authenticate exactly once per return', (
      tester,
    ) async {
      final auth = FakeAuthenticator(available: false);
      await _launch(tester, auth: auth, clock: clock, sink: sink);
      await tester.pumpAndSettle();
      expect(auth.prompts, 0);
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      await tester.pumpAndSettle();
      expect(auth.prompts, 1);
      await tester.pumpAndSettle();
      expect(auth.prompts, 1);
      expect(find.byKey(cover), findsOneWidget);
      expect(find.text(secret), findsNothing);
    });

    group('the same fakes under the optional policy open the app', () {
      test('no screen lock', () async {
        final c = start(
          authenticator: FakeAuthenticator(available: false),
          policy: LockPolicy.optional,
        );
        await pumpEventQueue();
        expect(stateOf(c), const LockState(LockPhase.unlocked));
        expect(notEngaged(), ['WARNING lock.notEngaged code=unavailable']);
      });

      test('isAvailable throws', () async {
        final c = start(
          authenticator: ThrowingAuthenticator(onAuthenticate: false),
          policy: LockPolicy.optional,
        );
        await pumpEventQueue();
        expect(stateOf(c), const LockState(LockPhase.unlocked));
      });

      test('a read that throws', () async {
        final c = start(
          store: FakeLockSettingsStore(readError: StateError('closed')),
          authenticator: FakeAuthenticator(),
          policy: LockPolicy.optional,
        );
        await pumpEventQueue();
        expect(stateOf(c), const LockState(LockPhase.unlocked));
      });

      test('no store bound', () async {
        final c = start(
          unbound: true,
          authenticator: FakeAuthenticator(),
          policy: LockPolicy.optional,
        );
        await pumpEventQueue();
        expect(stateOf(c), const LockState(LockPhase.unlocked));
      });

      test('Unlock answered unavailable', () async {
        final auth = FakeAuthenticator();
        final c = start(authenticator: auth, policy: LockPolicy.optional);
        await pumpEventQueue();
        auth.available = false;
        await controllerOf(c).unlock(enPrompt);
        expect(stateOf(c), const LockState(LockPhase.unlocked));
      });
    });
  });

  group('cover', () {
    Iterable<Widget> buttons() => find
        .descendant(
          of: find.byKey(cover),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        )
        .evaluate()
        .map((e) => e.widget);

    testWidgets('cannot prompt: the app\'s line and Unlock as the retry, no '
        'other button', (tester) async {
      final auth = FakeAuthenticator(available: false);
      await _launch(
        tester,
        auth: auth,
        clock: clock,
        sink: sink,
        policy: withMessage,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(cover), findsOneWidget);
      expect(find.text(secret), findsNothing);
      expect(find.byKey(notice), findsOneWidget);
      expect(find.text(cannotPromptLine), findsOneWidget);
      expect(find.byKey(unlockButton), findsOneWidget);
      expect(buttons(), hasLength(1));
      expect(find.byKey(const Key('lock/retry')), findsNothing);

      // The retry, once a screen lock is set.
      auth.available = true;
      await tester.tap(find.byKey(unlockButton));
      await tester.pumpAndSettle();
      expect(find.byKey(cover), findsNothing);
      expect(find.text(secret), findsOneWidget);
    });

    testWidgets('a mandatory policy without a line shows no notice', (
      tester,
    ) async {
      await _launch(
        tester,
        auth: FakeAuthenticator(available: false),
        clock: clock,
        sink: sink,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(cover), findsOneWidget);
      expect(find.byKey(notice), findsNothing);
      expect(find.byKey(unlockButton), findsOneWidget);
    });

    testWidgets('the notice only while it cannot prompt', (tester) async {
      await _launch(
        tester,
        auth: FakeAuthenticator(script: [AuthOutcome.cancelled]),
        clock: clock,
        sink: sink,
        policy: withMessage,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(cover), findsOneWidget);
      expect(find.byKey(const Key('lock/retry')), findsOneWidget);
      expect(find.byKey(notice), findsNothing);
    });

    testWidgets('under the optional policy the notice never appears', (
      tester,
    ) async {
      await _launch(
        tester,
        auth: FakeAuthenticator(available: false),
        clock: clock,
        sink: sink,
        policy: LockPolicy.optional.copyWith(
          cannotPromptMessage: (_) => cannotPromptLine,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(cover), findsNothing);
      expect(find.byKey(notice), findsNothing);
      expect(find.text(secret), findsOneWidget);
    });

    testWidgets('LockCover shows its notice under the cover line', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ApsiraThemeData.dark,
          localizationsDelegates: const [ApsiraL10n.delegate],
          supportedLocales: ApsiraL10n.supportedLocales,
          home: LockCover(
            appTitle: 'APSIRA',
            onUnlock: () {},
            notice: cannotPromptLine,
          ),
        ),
      );
      expect(find.text(cannotPromptLine), findsOneWidget);
      final text = tester.widget<Text>(find.byKey(notice));
      expect(text.style?.color, ApsiraTheme.dark.ink2);
      expect(
        tester.getTopLeft(find.byKey(notice)).dy,
        greaterThan(
          tester
              .getTopLeft(find.text(const ApsiraL10nEn().lockCoverMessage))
              .dy,
        ),
      );
    });
  });
}

Future<void> _launch(
  WidgetTester tester, {
  required Authenticator auth,
  required FakeClock clock,
  required MemorySink sink,
  LockPolicy policy = LockPolicy.mandatory,
}) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: lockOverrides(
        store: settingsOf(on),
        authenticator: auth,
        clock: clock,
        sink: sink,
        policy: policy,
      ),
      child: MaterialApp(
        theme: ApsiraThemeData.dark,
        localizationsDelegates: const [ApsiraL10n.delegate],
        supportedLocales: ApsiraL10n.supportedLocales,
        builder: (context, child) => LockShield(
          appTitle: 'APSIRA',
          promptReason: (_) => 'Unlock APSIRA to see your vault.',
          child: child!,
        ),
        home: const Scaffold(body: Text(secret)),
      ),
    ),
  );
}

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];
