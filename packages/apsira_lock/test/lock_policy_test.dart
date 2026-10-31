// The lock's policy (D-APK-026, D-018): the optional policy is today's lock,
// the mandatory one (APSIRA's) pins the lock on, offers 0, 1 and 5 minutes
// with 1 by default, and reads as on when the app's store cannot be read.
import 'dart:async';

import 'package:apsira_core/testing.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const mandatoryDefaults = LockSettings(enabled: true, timeoutMinutes: 1);

void main() {
  group('LockPolicy', () {
    test('optional is today\'s lock: off by default, 0 to 30 minutes', () {
      const policy = LockPolicy.optional;
      expect(policy.isMandatory, isFalse);
      expect(policy.timeoutOptions, lockTimeoutOptions);
      expect(policy.timeoutOptions, [0, 1, 5, 15, 30]);
      expect(policy.defaults, LockSettings.defaults);
      expect(policy.cannotPromptMessage, isNull);
    });

    test('mandatory: on, 1 minute by default, 0, 1 and 5 minutes', () {
      const policy = LockPolicy.mandatory;
      expect(policy.isMandatory, isTrue);
      expect(policy.timeoutOptions, [0, 1, 5]);
      expect(policy.defaults, mandatoryDefaults);
      expect(policy.cannotPromptMessage, isNull);
    });

    test('copyWith sets the app\'s line for a device that cannot prompt', () {
      String line(_) => 'Set a screen lock to open the app.';
      final policy = LockPolicy.mandatory.copyWith(cannotPromptMessage: line);
      expect(policy.isMandatory, isTrue);
      expect(policy.timeoutOptions, [0, 1, 5]);
      expect(policy.defaults, mandatoryDefaults);
      expect(policy.cannotPromptMessage, same(line));
    });

    test('the package default is the optional policy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(lockPolicyProvider), same(LockPolicy.optional));
    });
  });

  group('LockSettings.fromJson fallback', () {
    test('no row reads as the fallback', () {
      expect(
        LockSettings.fromJson(null, fallback: LockPolicy.mandatory.defaults),
        mandatoryDefaults,
      );
      expect(LockSettings.fromJson(null), LockSettings.defaults);
    });

    test('a missing or mistyped field reads as the fallback\'s', () {
      expect(
        LockSettings.fromJson({
          'enabled': 'yes',
          'hideInRecents': true,
        }, fallback: mandatoryDefaults),
        const LockSettings(
          enabled: true,
          timeoutMinutes: 1,
          hideInRecents: true,
        ),
      );
      expect(
        LockSettings.fromJson({
          'enabled': false,
          'timeoutMinutes': -1,
        }, fallback: mandatoryDefaults),
        const LockSettings(timeoutMinutes: 1),
      );
    });
  });

  group('MandatoryLockSettingsStore', () {
    test('the read bound is 1 s, below the launch bound', () {
      expect(mandatoryReadBound, const Duration(seconds: 1));
      expect(mandatoryReadBound < lockSettingsReadBound, isTrue);
    });

    test('a stored "off" reads as on, with the stored timeout', () async {
      final inner = FakeLockSettingsStore(
        row: {'enabled': false, 'timeoutMinutes': 5},
      );
      final store = MandatoryLockSettingsStore(inner);
      expect(
        await store.read(),
        const LockSettings(enabled: true, timeoutMinutes: 5),
      );
    });

    test('no store bound reads as the policy\'s defaults', () async {
      final failures = <Object?>[];
      final store = MandatoryLockSettingsStore(
        null,
        onReadFailed: failures.add,
      );
      expect(await store.read(), mandatoryDefaults);
      expect(failures, hasLength(1));
    });

    test('a read that throws reads as the policy\'s defaults', () async {
      final failures = <Object?>[];
      final inner = FakeLockSettingsStore(
        row: {'enabled': false, 'timeoutMinutes': 15},
        readError: StateError('database closed'),
      );
      final store = MandatoryLockSettingsStore(
        inner,
        onReadFailed: failures.add,
      );
      expect(await store.read(), mandatoryDefaults);
      expect(failures.single, isA<StateError>());
    });

    testWidgets('a read held past 1 s reads as the policy\'s defaults', (
      tester,
    ) async {
      final inner = FakeLockSettingsStore(
        row: {'enabled': false, 'timeoutMinutes': 15},
      )..holdReads();
      final failures = <Object?>[];
      final store = MandatoryLockSettingsStore(
        inner,
        onReadFailed: failures.add,
      );
      LockSettings? read;
      unawaited(store.read().then((s) => read = s));
      await tester.pump(mandatoryReadBound - const Duration(milliseconds: 1));
      expect(read, isNull);
      await tester.pump(const Duration(milliseconds: 2));
      expect(read, mandatoryDefaults);
      expect(failures.single, isA<TimeoutException>());
      inner.releaseReads();
      await tester.pump();
      expect(read, mandatoryDefaults);
    });

    test('a write of "off" stores on and keeps an unknown field', () async {
      final inner = FakeLockSettingsStore(
        row: {'enabled': true, 'timeoutMinutes': 1, 'pin': 'later'},
      );
      final store = MandatoryLockSettingsStore(inner);
      await store.write(const LockSettings(timeoutMinutes: 5));
      expect(inner.writes.single.enabled, isTrue);
      expect(inner.row, {
        'enabled': true,
        'timeoutMinutes': 5,
        'hideInRecents': false,
        'pin': 'later',
      });
    });

    test('a write with no store bound throws', () async {
      final store = MandatoryLockSettingsStore(null);
      await expectLater(
        store.write(mandatoryDefaults),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('lockSettingsProvider under the mandatory policy', () {
    ProviderContainer containerOf(List<Override> overrides) {
      final c = ProviderContainer(
        overrides: [
          lockPolicyProvider.overrideWithValue(LockPolicy.mandatory),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('wraps the app\'s store: a stored "off" reads as on', () async {
      final store = FakeLockSettingsStore(
        row: {'enabled': false, 'timeoutMinutes': 5},
      );
      final c = containerOf([
        lockSettingsStoreProvider.overrideWithValue(store),
      ]);
      expect(
        await c.read(lockSettingsProvider.future),
        const LockSettings(enabled: true, timeoutMinutes: 5),
      );
    });

    test('unbound reads as on with 1 minute', () async {
      final c = containerOf([]);
      expect(await c.read(lockSettingsProvider.future), mandatoryDefaults);
    });

    test('a change to "off" stores on', () async {
      final store = FakeLockSettingsStore(row: mandatoryDefaults.toJson());
      final c = containerOf([
        lockSettingsStoreProvider.overrideWithValue(store),
      ]);
      await c.read(lockSettingsProvider.future);
      await c
          .read(lockSettingsProvider.notifier)
          .change((s) => s.copyWith(enabled: false, timeoutMinutes: 0));
      expect(store.row?['enabled'], isTrue);
      expect(store.row?['timeoutMinutes'], 0);
      expect(
        c.read(lockSettingsProvider).value,
        const LockSettings(enabled: true, timeoutMinutes: 0),
      );
    });
  });

  group('controller', () {
    late MemorySink sink;

    setUp(() => sink = MemorySink());

    ProviderContainer start(LockSettingsStore? store) {
      final c = ProviderContainer(
        overrides: lockOverrides(
          store: store,
          authenticator: FakeAuthenticator(),
          clock: FakeClock(t0),
          sink: sink,
          policy: LockPolicy.mandatory,
        ),
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      return c;
    }

    test('mandatory: a read that throws locks at launch', () async {
      final c = start(FakeLockSettingsStore(readError: StateError('closed')));
      await pumpEventQueue();
      expect(
        c.read(lockControllerProvider),
        const LockState(LockPhase.locked, promptDue: true),
      );
      expect(
        c.read(lockControllerProvider.notifier).settings,
        mandatoryDefaults,
      );
      expect(sink.lines, [
        'WARNING lock.settingsReadFailed errorType=StateError',
      ]);
    });
  });
}
