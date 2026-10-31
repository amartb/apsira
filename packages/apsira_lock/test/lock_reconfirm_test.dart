// LockController.reconfirm (D-018, D-APK-026): a fresh confirmation before a
// sensitive act, whatever the settings say, only while the app is shown.
// Passed confirms, failed or cancelled declines (no counter, no back-off); a
// device that cannot prompt is `skipped` under the optional policy (the act
// goes ahead, D-APK-016) and `unavailable` under the mandatory one (the act
// is refused, rulings R-1 and R-4). The prompt pausing the activity is not a
// background.
import 'package:apsira_core/testing.dart';
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

  Future<ProviderContainer> start({
    LockSettings settings = const LockSettings(),
    required Authenticator authenticator,
    LockPolicy policy = LockPolicy.optional,
  }) async {
    final c = ProviderContainer(
      overrides: lockOverrides(
        store: settingsOf(settings),
        authenticator: authenticator,
        clock: clock,
        sink: sink,
        policy: policy,
      ),
    );
    addTearDown(c.dispose);
    c.listen(lockControllerProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  LockState stateOf(ProviderContainer c) => c.read(lockControllerProvider);
  LockController controllerOf(ProviderContainer c) =>
      c.read(lockControllerProvider.notifier);

  /// Opens a locked app with a passed prompt.
  Future<void> unlockFirst(ProviderContainer c) async {
    if (stateOf(c).phase == LockPhase.locked) {
      await controllerOf(c).unlock(enPrompt);
    }
    expect(stateOf(c).phase, LockPhase.unlocked);
  }

  test('outcomes: only confirmed and skipped proceed', () {
    expect(ReconfirmOutcome.confirmed.proceeds, isTrue);
    expect(ReconfirmOutcome.skipped.proceeds, isTrue);
    expect(ReconfirmOutcome.declined.proceeds, isFalse);
    expect(ReconfirmOutcome.unavailable.proceeds, isFalse);
  });

  test('passed: confirmed, with the prompt\'s text', () async {
    final auth = FakeAuthenticator();
    final c = await start(settings: on, authenticator: auth);
    await unlockFirst(c);
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.confirmed,
    );
    expect(auth.prompts, 2);
    expect(auth.lastPrompt, enPrompt);
    expect(stateOf(c).phase, LockPhase.unlocked);
  });

  test('failed then passed: declined then confirmed, two prompts', () async {
    final auth = FakeAuthenticator(
      script: [AuthOutcome.failed, AuthOutcome.passed],
    );
    final c = await start(authenticator: auth);
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.declined,
    );
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.confirmed,
    );
    expect(auth.prompts, 2);
    expect(stateOf(c).phase, LockPhase.unlocked);
  });

  test('cancelled: declined', () async {
    final c = await start(
      authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
    );
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.declined,
    );
  });

  test('the lock off still prompts', () async {
    final auth = FakeAuthenticator();
    final c = await start(authenticator: auth);
    expect(controllerOf(c).settings.enabled, isFalse);
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.confirmed,
    );
    expect(auth.prompts, 1);
  });

  test('covered: declined, no prompt', () async {
    final auth = FakeAuthenticator();
    final c = await start(settings: on, authenticator: auth);
    expect(stateOf(c).phase, LockPhase.locked);
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.declined,
    );
    expect(auth.prompts, 0);

    await controllerOf(c).unlock(enPrompt);
    controllerOf(c).backgrounded();
    expect(stateOf(c).phase, LockPhase.shielded);
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.declined,
    );
    expect(auth.prompts, 1);
  });

  test('a second call while one is pending: declined, one prompt', () async {
    final auth = PendingAuthenticatorFake();
    final c = await start(authenticator: auth);
    final first = controllerOf(c).reconfirm(enPrompt);
    expect(
      await controllerOf(c).reconfirm(enPrompt),
      ReconfirmOutcome.declined,
    );
    expect(auth.prompts, hasLength(1));
    auth.prompts.single.complete(AuthOutcome.passed);
    expect(await first, ReconfirmOutcome.confirmed);
  });

  test(
    'at timeout 0, the prompt pausing the app is not a background',
    () async {
      final auth = PendingAuthenticatorFake();
      final c = await start(
        settings: const LockSettings(enabled: true, timeoutMinutes: 0),
        authenticator: auth,
      );
      expect(stateOf(c).phase, LockPhase.locked);
      final unlocking = controllerOf(c).unlock(enPrompt);
      auth.prompts.single.complete(AuthOutcome.passed);
      await unlocking;
      expect(stateOf(c).phase, LockPhase.unlocked);

      final pending = controllerOf(c).reconfirm(enPrompt);
      controllerOf(c)
        ..backgrounded()
        ..foregrounded();
      expect(stateOf(c), const LockState(LockPhase.unlocked));
      auth.prompts.last.complete(AuthOutcome.passed);
      expect(await pending, ReconfirmOutcome.confirmed);
      expect(stateOf(c), const LockState(LockPhase.unlocked));
      expect(auth.prompts, hasLength(2), reason: 'one unlock, one re-confirm');

      // Once the prompt is down, a background is one again.
      controllerOf(c).backgrounded();
      expect(stateOf(c).phase, LockPhase.shielded);
    },
  );

  group('optional policy: a device that cannot prompt is skipped', () {
    test('unavailable', () async {
      final c = await start(authenticator: FakeAuthenticator(available: false));
      final outcome = await controllerOf(c).reconfirm(enPrompt);
      expect(outcome, ReconfirmOutcome.skipped);
      expect(outcome.proceeds, isTrue);
      expect(sink.lines, ['WARNING lock.reconfirmSkipped code=unavailable']);
    });

    test('throwing', () async {
      final c = await start(
        authenticator: ThrowingAuthenticator(onAvailable: false),
      );
      expect(
        await controllerOf(c).reconfirm(enPrompt),
        ReconfirmOutcome.skipped,
      );
      expect(sink.lines, [
        'WARNING lock.reconfirmSkipped errorType=StateError '
            'code=authenticatorError',
      ]);
    });
  });

  group('mandatory policy: a device that cannot prompt refuses the act', () {
    test('unavailable', () async {
      final auth = FakeAuthenticator();
      final c = await start(authenticator: auth, policy: LockPolicy.mandatory);
      await unlockFirst(c);
      auth.available = false;
      final outcome = await controllerOf(c).reconfirm(enPrompt);
      expect(outcome, ReconfirmOutcome.unavailable);
      expect(outcome.proceeds, isFalse);
      expect(sink.lines, [
        'WARNING lock.reconfirmUnavailable code=unavailable',
      ]);
      expect(stateOf(c).phase, LockPhase.unlocked);
    });

    test('throwing', () async {
      final auth = _ThrowsAfterFirst();
      final c = await start(authenticator: auth, policy: LockPolicy.mandatory);
      await unlockFirst(c);
      final outcome = await controllerOf(c).reconfirm(enPrompt);
      expect(outcome, ReconfirmOutcome.unavailable);
      expect(outcome.proceeds, isFalse);
      expect(sink.lines, [
        'WARNING lock.reconfirmUnavailable errorType=StateError '
            'code=authenticatorError',
      ]);
    });
  });
}

/// Passes the first prompt (the launch unlock), then throws.
final class _ThrowsAfterFirst implements Authenticator {
  int _prompts = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AuthOutcome> authenticate(AuthPrompt prompt) async {
    if (_prompts++ == 0) return AuthOutcome.passed;
    throw StateError('prompt failed');
  }
}
