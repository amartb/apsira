// From relay test/features/lock/lock_gate_test.dart @ 09b28810, unchanged
// but for names (D-APK-016): the gate is LockShield, the strings ApsiraL10n's
// with the app's own reason, and RELAY's stream of the `lock` row the app's
// store. The exemption tests at the end are the package's: RELAY's own
// (lock_gate_exempt_test.dart) drive go_router, which stays in RELAY.
//
// The branded cover is up from the first frame on launch and on the first
// frame back from the background, before any content; the prompt starts once
// the cover is drawn; passed reveals the app with its state kept, failed or
// cancelled keeps the cover with a retry. Covered content is not painted, not
// in the semantics tree and not reached by back. An unavailable Authenticator
// never covers the app.
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const en = ApsiraL10nEn();
const es = ApsiraL10nEs();
const appTitle = 'Relay';
String reasonOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'es'
    ? 'Desbloquea Relay para ver tus notas y tareas.'
    : 'Unlock Relay to see your notes and tasks.';

const secret = 'Private note text';
const on = LockSettings(enabled: true);
const cover = Key('lock/cover');
const unlockButton = Key('lock/unlock');

/// Content with state of its own, to prove the cover keeps it.
class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text(secret),
        Text('taps $taps'),
        TextButton(
          onPressed: () => setState(() => taps++),
          child: const Text('tap'),
        ),
      ],
    ),
  );
}

void main() {
  late FakeClock clock;
  late MemorySink sink;
  late List<MethodCall> platformCalls;

  setUp(() {
    clock = FakeClock(t0);
    sink = MemorySink();
    platformCalls = [];
  });

  Future<void> launch(
    WidgetTester tester, {
    LockSettings settings = on,
    LockSettingsStore? store,
    required Authenticator authenticator,
    Locale? locale,
    bool Function()? isExempt,
    Listenable? exemptChanges,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
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
          store: store ?? settingsOf(settings),
          authenticator: authenticator,
          clock: clock,
          sink: sink,
        ),
        child: MaterialApp(
          theme: ApsiraThemeData.light,
          darkTheme: ApsiraThemeData.dark,
          themeMode: ThemeMode.dark,
          locale: locale,
          localizationsDelegates: const [
            ApsiraL10n.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: ApsiraL10n.supportedLocales,
          builder: (context, child) => LockShield(
            appTitle: appTitle,
            promptReason: reasonOf,
            isExempt: isExempt,
            exemptChanges: exemptChanges,
            child: child!,
          ),
          home: const _Content(),
        ),
      ),
    );
  }

  /// Walks the app's lifecycle one legal step at a time, as Android does.
  Future<void> lifecycle(
    WidgetTester tester,
    List<AppLifecycleState> states,
  ) async {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  const toBackground = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  const toForeground = [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  void expectCovered() {
    expect(find.byKey(cover), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(
      find.text(secret, skipOffstage: false),
      findsOneWidget,
      reason: 'the content stays built under the cover',
    );
  }

  void expectOpen() {
    expect(find.byKey(cover), findsNothing);
    expect(find.text(secret), findsOneWidget);
  }

  group('prompt language', () {
    testWidgets('in Spanish, the prompt the gate starts is in Spanish', (
      tester,
    ) async {
      final auth = PendingAuthenticatorFake();
      await launch(tester, authenticator: auth, locale: const Locale('es'));
      await tester.pumpAndSettle();
      expect(auth.asked, [
        AuthPrompt(
          reason: 'Desbloquea Relay para ver tus notas y tareas.',
          title: es.lockPromptTitle(appTitle),
          hint: es.lockPromptHint,
          cancel: es.commonCancel,
        ),
      ]);
      expect(auth.asked.single.title, isNot(en.lockPromptTitle(appTitle)));

      // Unlock after a cancelled prompt asks in Spanish too.
      auth.prompts.single.complete(AuthOutcome.cancelled);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(unlockButton));
      await tester.pumpAndSettle();
      expect(auth.asked, hasLength(2));
      expect(auth.asked.last, auth.asked.first);
    });
  });

  group('cover', () {
    testWidgets('the cover is up on the first frame, before any content', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final auth = PendingAuthenticatorFake();
      await launch(tester, authenticator: auth);
      // Before the settings are read: the opaque cover over the whole
      // screen, the content out of the semantics tree.
      expect(find.byKey(cover), findsOneWidget);
      expect(
        tester.getRect(find.byKey(cover)),
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      expect(find.bySemanticsLabel(secret), findsNothing);
      expect(auth.prompts, isEmpty, reason: 'the prompt waits for the cover');
      semantics.dispose();

      await tester.pumpAndSettle();
      expectCovered();
      expect(auth.reasons, ['Unlock Relay to see your notes and tasks.']);

      auth.prompts.single.complete(AuthOutcome.passed);
      await tester.pumpAndSettle();
      expectOpen();
    });

    testWidgets('the cover shows no content: not painted, not in semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, authenticator: PendingAuthenticatorFake());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(secret), findsNothing);
      expect(find.bySemanticsLabel(appTitle), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('lock off: the cover comes down without a prompt', (
      tester,
    ) async {
      final auth = FakeAuthenticator();
      await launch(tester, settings: const LockSettings(), authenticator: auth);
      expect(find.byKey(cover), findsOneWidget, reason: 'until the read');
      expect(find.text(secret), findsOneWidget, reason: 'laid out under it');
      await tester.pumpAndSettle();
      expectOpen();
      expect(auth.prompts, 0);
    });

    testWidgets('failed keeps the cover with a retry; Unlock prompts again', (
      tester,
    ) async {
      final auth = PendingAuthenticatorFake();
      await launch(tester, authenticator: auth);
      await tester.pumpAndSettle();
      expect(find.byKey(unlockButton), findsNothing, reason: 'prompt is up');

      auth.prompts.single.complete(AuthOutcome.failed);
      await tester.pumpAndSettle();
      expectCovered();
      expect(find.text(en.lockRetryMessage), findsOneWidget);
      expect(auth.prompts, hasLength(1), reason: 'no prompt loop');

      await tester.tap(find.byKey(unlockButton));
      await tester.pumpAndSettle();
      expect(auth.prompts, hasLength(2));
      auth.prompts.last.complete(AuthOutcome.passed);
      await tester.pumpAndSettle();
      expectOpen();
    });

    testWidgets('cancelled keeps the cover with a retry', (tester) async {
      await launch(
        tester,
        authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
      );
      await tester.pumpAndSettle();
      expectCovered();
      expect(find.text(en.lockRetryMessage), findsOneWidget);
      expect(find.byKey(unlockButton), findsOneWidget);
    });

    testWidgets('the cover is up on return from the background; after the '
        'timeout it prompts, and the content kept its state', (tester) async {
      final auth = FakeAuthenticator();
      await launch(tester, authenticator: auth);
      await tester.pumpAndSettle();
      expectOpen();
      await tester.tap(find.text('tap'));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);

      await lifecycle(tester, toBackground);
      expectCovered();

      clock.advance(const Duration(minutes: 5));
      await lifecycle(tester, toForeground);
      expectCovered();
      await tester.pumpAndSettle();
      expect(auth.prompts, 2);
      expectOpen();
      expect(find.text('taps 1'), findsOneWidget);
    });

    testWidgets('back before the timeout: the cover comes down, no prompt', (
      tester,
    ) async {
      final auth = FakeAuthenticator();
      await launch(tester, authenticator: auth);
      await tester.pumpAndSettle();

      await lifecycle(tester, toBackground);
      clock.advance(const Duration(minutes: 1));
      await lifecycle(tester, toForeground);
      await tester.pumpAndSettle();
      expectOpen();
      expect(auth.prompts, 1);
    });

    testWidgets('back while covered leaves the app, never pops the content', (
      tester,
    ) async {
      await launch(
        tester,
        authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
      );
      await tester.pumpAndSettle();
      expectCovered();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expectCovered();
      expect(
        platformCalls.map((c) => c.method),
        contains('SystemNavigator.pop'),
      );
    });

    testWidgets('a tap on the cover never reaches the content', (tester) async {
      await launch(
        tester,
        authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(LockCover)));
      await tester.pump();
      expect(find.text('taps 0', skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('unavailable Authenticator: no cover, the content shows', (
    tester,
  ) async {
    final auth = FakeAuthenticator(available: false);
    await launch(tester, authenticator: auth);
    await tester.pumpAndSettle();
    expectOpen();
    expect(auth.prompts, 0);

    await lifecycle(tester, toBackground);
    clock.advance(const Duration(hours: 1));
    await lifecycle(tester, toForeground);
    await tester.pumpAndSettle();
    expectOpen();
  });

  group('never a lock-out: unavailable settings', () {
    List<String> skips() => [
      for (final line in sink.lines)
        if (line.contains('lock.notEngaged')) line,
    ];

    testWidgets('a read that hangs: within the bound the cover stays, at '
        '2 s the content shows without the lock', (tester) async {
      expect(lockSettingsReadBound, const Duration(seconds: 2));
      final hang = FakeLockSettingsStore(row: on.toJson())..holdReads();
      final auth = FakeAuthenticator();
      await launch(tester, store: hang, authenticator: auth);
      await tester.pump(
        lockSettingsReadBound - const Duration(milliseconds: 1),
      );
      expect(find.byKey(cover), findsOneWidget);
      expect(skips(), isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expectOpen();
      expect(auth.prompts, 0);
      expect(skips(), ['WARNING lock.notEngaged code=settingsUnreadable']);

      // The row arriving late changes nothing under the user's hands.
      hang.releaseReads();
      await tester.pumpAndSettle();
      expectOpen();
      expect(auth.prompts, 0);
    });

    testWidgets('a read that throws: the content shows without the lock', (
      tester,
    ) async {
      final auth = FakeAuthenticator();
      await launch(
        tester,
        store: FakeLockSettingsStore(readError: StateError('database closed')),
        authenticator: auth,
      );
      await tester.pumpAndSettle();
      expectOpen();
      expect(auth.prompts, 0);
      expect(skips(), [
        'WARNING lock.notEngaged errorType=StateError code=settingsUnreadable',
      ]);

      // No bound timer is left to fire later.
      await tester.pump(lockSettingsReadBound * 2);
      expect(skips(), hasLength(1));
    });

    testWidgets('a row in time: the bound never fires', (tester) async {
      await launch(tester, authenticator: FakeAuthenticator());
      await tester.pumpAndSettle();
      await tester.pump(lockSettingsReadBound * 2);
      expectOpen();
      expect(skips(), isEmpty);
    });
  });

  group('exemption (isExempt)', () {
    testWidgets('an exempt screen: no cover and no prompt while locked', (
      tester,
    ) async {
      final exempt = ValueNotifier(true);
      addTearDown(exempt.dispose);
      final auth = PendingAuthenticatorFake();
      await launch(
        tester,
        authenticator: auth,
        isExempt: () => exempt.value,
        exemptChanges: exempt,
      );
      await tester.pumpAndSettle();
      expectOpen();
      expect(auth.prompts, isEmpty);

      // Leaving it while locked: the cover is back and the prompt starts.
      exempt.value = false;
      await tester.pumpAndSettle();
      expectCovered();
      expect(auth.prompts, hasLength(1));

      auth.prompts.single.complete(AuthOutcome.passed);
      await tester.pumpAndSettle();
      expectOpen();
    });

    testWidgets('without isExempt every screen is guarded', (tester) async {
      final auth = PendingAuthenticatorFake();
      await launch(tester, authenticator: auth);
      await tester.pumpAndSettle();
      expectCovered();
      expect(auth.prompts, hasLength(1));
    });
  });
}
