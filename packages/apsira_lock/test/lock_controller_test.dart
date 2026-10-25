// From relay test/features/lock/lock_controller_test.dart @ 09b28810,
// unchanged but for names (D-APK-016): RELAY's stream of the `lock` row is
// the app's LockSettingsStore behind lockSettingsProvider, so a change the
// stream carried is an update through that provider, and the prompt is the
// AuthPrompt the shield builds.
//
// The app lock's controller: locked at launch and after
// `timeoutMinutes` in the background (timed by the Clock port from `paused`)
// when `enabled`; passed unlocks, failed or cancelled stays locked with a
// retry. Never a lock-out: an unavailable or throwing Authenticator, or
// settings that cannot be read, leave the lock off with a content-free log
// code. Off by default, timeout 5 minutes.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const on = LockSettings(enabled: true);

void main() {
  late FakeClock clock;
  late MemorySink sink;

  setUp(() {
    clock = FakeClock(t0);
    sink = MemorySink();
  });

  ProviderContainer start({
    LockSettings settings = on,
    LockSettingsStore? store,
    Authenticator? authenticator,
  }) {
    final container = ProviderContainer(
      overrides: lockOverrides(
        store: store ?? settingsOf(settings),
        authenticator: authenticator ?? FakeAuthenticator(),
        clock: clock,
        sink: sink,
      ),
    );
    addTearDown(container.dispose);
    // Keep the controller alive and record what it went through.
    container.listen(lockControllerProvider, (_, _) {});
    return container;
  }

  LockState stateOf(ProviderContainer c) => c.read(lockControllerProvider);
  LockController controllerOf(ProviderContainer c) =>
      c.read(lockControllerProvider.notifier);
  Future<void> change(ProviderContainer c, LockSettings settings) =>
      c.read(lockSettingsProvider.notifier).change((_) => settings);

  Future<void> settle() => pumpEventQueue();

  group('LockSettings', () {
    test('defaults: off, 5 minutes, recents shown', () {
      const settings = LockSettings();
      expect(settings.enabled, isFalse);
      expect(settings.timeoutMinutes, 5);
      expect(settings.timeout, const Duration(minutes: 5));
      expect(settings.hideInRecents, isFalse);
      expect(LockSettings.defaults, settings);
    });

    test('reads the row; anything unexpected is its default', () {
      expect(
        LockSettings.fromJson({
          'enabled': true,
          'timeoutMinutes': 0,
          'hideInRecents': true,
        }),
        const LockSettings(
          enabled: true,
          timeoutMinutes: 0,
          hideInRecents: true,
        ),
      );
      for (final odd in <Object?>[
        null,
        'on',
        [true],
        {'enabled': 'yes', 'timeoutMinutes': -1, 'hideInRecents': 1},
        {'timeoutMinutes': 2.5},
      ]) {
        expect(
          LockSettings.fromJson(odd),
          const LockSettings(),
          reason: '$odd',
        );
      }
    });
  });

  group('launch', () {
    test(
      'off by default: no lock row leaves the app open, no prompt',
      () async {
        final auth = FakeAuthenticator();
        final c = start(store: FakeLockSettingsStore(), authenticator: auth);
        expect(
          stateOf(c).phase,
          LockPhase.starting,
          reason: 'covered at first',
        );
        await settle();
        expect(stateOf(c), const LockState(LockPhase.unlocked));
        expect(auth.prompts, 0);
      },
    );

    test('enabled: locked with the prompt due; passed unlocks', () async {
      final auth = FakeAuthenticator();
      final c = start(authenticator: auth);
      expect(stateOf(c).covered, isTrue);
      await settle();
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));

      final unlocking = controllerOf(c).unlock(enPrompt);
      expect(stateOf(c).phase, LockPhase.authenticating);
      await unlocking;
      expect(stateOf(c), const LockState(LockPhase.unlocked));
      expect(auth.prompts, 1);
    });

    for (final outcome in [AuthOutcome.failed, AuthOutcome.cancelled]) {
      test('${outcome.name} keeps the cover with a retry', () async {
        final auth = FakeAuthenticator(script: [outcome, AuthOutcome.passed]);
        final c = start(authenticator: auth);
        await settle();

        await controllerOf(c).unlock(enPrompt);
        final s = stateOf(c);
        expect(s.phase, LockPhase.locked);
        expect(s.covered && s.canUnlock && s.showRetry, isTrue);
        expect(s.promptDue, isFalse, reason: 'no prompt loop');

        await controllerOf(c).unlock(enPrompt);
        expect(stateOf(c).phase, LockPhase.unlocked);
        expect(auth.prompts, 2);
      });
    }

    test(
      'the prompt carries all four strings in the user\'s language',
      () async {
        final auth = FakeAuthenticator();
        final c = start(authenticator: auth);
        await settle();
        final es = AuthPrompt.of(
          const ApsiraL10nEs(),
          appName: 'Relay',
          reason: 'Desbloquea Relay para ver tus notas y tareas.',
        );
        await controllerOf(c).unlock(es);
        expect(
          auth.lastPrompt,
          const AuthPrompt(
            reason: 'Desbloquea Relay para ver tus notas y tareas.',
            title: 'Desbloquear Relay',
            hint: 'Confirma que eres tú',
            cancel: 'Cancelar',
          ),
        );
        expect(enPrompt, isNot(es));
      },
    );

    test('unlock outside the locked phase does not prompt', () async {
      final auth = FakeAuthenticator();
      final c = start(settings: const LockSettings(), authenticator: auth);
      await settle();
      await controllerOf(c).unlock(enPrompt);
      expect(auth.prompts, 0);
    });
  });

  group('background timeout', () {
    Future<ProviderContainer> unlocked({
      LockSettings settings = on,
      Authenticator? authenticator,
    }) async {
      final c = start(settings: settings, authenticator: authenticator);
      await settle();
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c).phase, LockPhase.unlocked);
      return c;
    }

    test(
      'covered while in the background; back before the timeout opens',
      () async {
        final c = await unlocked();
        controllerOf(c).backgrounded();
        expect(stateOf(c).phase, LockPhase.shielded);
        expect(stateOf(c).covered, isTrue);

        clock.advance(const Duration(minutes: 4, seconds: 59));
        controllerOf(c).foregrounded();
        expect(stateOf(c), const LockState(LockPhase.unlocked));
      },
    );

    test('back after the timeout locks and prompts', () async {
      final c = await unlocked();
      controllerOf(c).backgrounded();
      clock.advance(const Duration(minutes: 5));
      controllerOf(c).foregrounded();
      await settle();
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
    });

    test('timeout 0 locks at once', () async {
      final c = await unlocked(
        settings: const LockSettings(enabled: true, timeoutMinutes: 0),
      );
      controllerOf(c).backgrounded();
      controllerOf(c).foregrounded();
      await settle();
      expect(stateOf(c).phase, LockPhase.locked);
    });

    test('a clock that went backwards locks', () async {
      final c = await unlocked();
      controllerOf(c).backgrounded();
      clock.advance(const Duration(hours: -1));
      controllerOf(c).foregrounded();
      await settle();
      expect(stateOf(c).phase, LockPhase.locked);
    });

    test('lock off: the background changes nothing', () async {
      final c = start(settings: const LockSettings());
      await settle();
      controllerOf(c).backgrounded();
      expect(stateOf(c).phase, LockPhase.unlocked);
      clock.advance(const Duration(hours: 1));
      controllerOf(c).foregrounded();
      expect(stateOf(c).phase, LockPhase.unlocked);
    });

    test('the credential screen pausing the app is not a background', () async {
      final auth = PendingAuthenticatorFake();
      final c = start(authenticator: auth);
      await settle();
      final unlocking = controllerOf(c).unlock(enPrompt);
      controllerOf(c).backgrounded();
      clock.advance(const Duration(hours: 1));
      controllerOf(c).foregrounded();
      expect(stateOf(c).phase, LockPhase.authenticating);

      auth.prompts.single.complete(AuthOutcome.passed);
      await unlocking;
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(auth.prompts, hasLength(1), reason: 'no second prompt');
    });

    test(
      'locked and back from the background: the prompt is due again',
      () async {
        final c = start(
          authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
        );
        await settle();
        await controllerOf(c).unlock(enPrompt);
        controllerOf(c).backgrounded();
        expect(stateOf(c).promptDue, isFalse);
        controllerOf(c).foregrounded();
        expect(stateOf(c).promptDue, isTrue);
        expect(stateOf(c).showRetry, isTrue);
      },
    );

    test('turned on while open: no lock until the next timeout', () async {
      final c = start(settings: const LockSettings());
      await settle();
      expect(stateOf(c).phase, LockPhase.unlocked);

      await change(c, on);
      await settle();
      expect(stateOf(c).phase, LockPhase.unlocked);

      controllerOf(c).backgrounded();
      clock.advance(const Duration(minutes: 5));
      controllerOf(c).foregrounded();
      await settle();
      expect(stateOf(c).phase, LockPhase.locked);
    });

    test('turned off while covered: the cover comes down', () async {
      final c = start();
      await settle();
      expect(stateOf(c).phase, LockPhase.locked);
      await change(c, const LockSettings());
      await settle();
      expect(stateOf(c).phase, LockPhase.unlocked);
    });
  });

  group('lock now', () {
    Future<ProviderContainer> unlocked({Authenticator? authenticator}) async {
      final c = start(authenticator: authenticator);
      await settle();
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c).phase, LockPhase.unlocked);
      return c;
    }

    test('locks at once with the prompt due; passed unlocks', () async {
      final auth = FakeAuthenticator();
      final c = await unlocked(authenticator: auth);
      await controllerOf(c).lockNow();
      expect(stateOf(c), const LockState(LockPhase.locked, promptDue: true));
      expect(stateOf(c).covered, isTrue);

      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(auth.prompts, 2);
    });

    test('lock off: nothing happens', () async {
      final c = start(settings: const LockSettings());
      await settle();
      await controllerOf(c).lockNow();
      expect(stateOf(c), const LockState(LockPhase.unlocked));
    });

    test(
      'never a lock-out: an unavailable Authenticator leaves it open',
      () async {
        final auth = FakeAuthenticator();
        final c = await unlocked(authenticator: auth);
        auth.available = false;
        await controllerOf(c).lockNow();
        expect(stateOf(c).phase, LockPhase.unlocked);
        expect(sink.lines.where((l) => l.contains('lock.notEngaged')), [
          'WARNING lock.notEngaged code=unavailable',
        ]);
      },
    );

    test(
      'already covered: the cover and its prompt stay as they are',
      () async {
        final c = start(
          authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
        );
        await settle();
        await controllerOf(c).unlock(enPrompt);
        final retry = stateOf(c);
        expect(retry.showRetry, isTrue);
        await controllerOf(c).lockNow();
        expect(stateOf(c), retry);
      },
    );
  });

  group('never a lock-out: unavailable', () {
    List<String> skips() => [
      for (final line in sink.lines)
        if (line.contains('lock.notEngaged')) line,
    ];

    test('unavailable Authenticator: the lock does not engage', () async {
      final auth = FakeAuthenticator(available: false);
      final c = start(authenticator: auth);
      await settle();
      expect(stateOf(c), const LockState(LockPhase.unlocked));
      expect(auth.prompts, 0);
      expect(skips(), ['WARNING lock.notEngaged code=unavailable']);
    });

    test('unavailable after the timeout: the lock does not engage', () async {
      final auth = FakeAuthenticator();
      final c = start(authenticator: auth);
      await settle();
      await controllerOf(c).unlock(enPrompt);
      auth.available = false;
      controllerOf(c).backgrounded();
      clock.advance(const Duration(minutes: 10));
      controllerOf(c).foregrounded();
      await settle();
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(skips(), ['WARNING lock.notEngaged code=unavailable']);
    });

    test('unavailable at the prompt (screen lock removed) unlocks', () async {
      final auth = _ScriptedAvailable(AuthOutcome.unavailable);
      final c = start(authenticator: auth);
      await settle();
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(skips(), ['WARNING lock.notEngaged code=unavailable']);
    });

    test('unavailable: isAvailable throws, the lock does not engage', () async {
      final c = start(authenticator: ThrowingAuthenticator());
      await settle();
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(skips(), [
        'WARNING lock.notEngaged errorType=StateError code=authenticatorError',
      ]);
    });

    test('unavailable: authenticate throws, the app opens', () async {
      final c = start(authenticator: ThrowingAuthenticator(onAvailable: false));
      await settle();
      expect(stateOf(c).phase, LockPhase.locked);
      await controllerOf(c).unlock(enPrompt);
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(skips(), [
        'WARNING lock.notEngaged errorType=StateError code=authenticatorError',
      ]);
    });

    test('unavailable settings (no store bound): the app opens', () {
      final container = ProviderContainer(
        overrides: [
          lockLogProvider.overrideWithValue(Log([sink], debugEnabled: false)),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(lockControllerProvider),
        const LockState(LockPhase.unlocked),
      );
      expect(skips().single, contains('code=settingsUnreadable'));
    });

    test('unavailable settings (the read fails): the app opens', () async {
      final c = start(
        store: FakeLockSettingsStore(readError: StateError('closed')),
      );
      await settle();
      expect(stateOf(c).phase, LockPhase.unlocked);
      expect(skips().single, contains('code=settingsUnreadable'));
    });

    test('unavailable ports and log: nothing throws, the app opens', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(lockControllerProvider).covered, isFalse);
    });

    test('the log lines carry codes and types only', () async {
      start(authenticator: ThrowingAuthenticator());
      await settle();
      for (final r in sink.records) {
        expect(r.fields.keys, everyElement(isIn(['errorType', 'code'])));
        expect(r.renderFields().join(' '), isNot(contains('biometric')));
      }
    });
  });
}

/// Available, but every prompt returns [outcome].
final class _ScriptedAvailable implements Authenticator {
  _ScriptedAvailable(this.outcome);

  final AuthOutcome outcome;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AuthOutcome> authenticate(AuthPrompt prompt) async => outcome;
}
