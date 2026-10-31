// From relay test/features/lock/lock_test_support.dart @ 09b28810: the ports
// bound to fakes, an Authenticator that throws or waits, and a log kept in
// memory. RELAY's stream of the `lock` row is the app's LockSettingsStore
// here (FakeLockSettingsStore, D-APK-016).
import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:flutter_riverpod/misc.dart';

final class MemorySink implements LogSink {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  /// Every record as `LEVEL event key=value …`.
  List<String> get lines => [
    for (final r in records)
      [r.level.name.toUpperCase(), r.event, ...r.renderFields()].join(' '),
  ];
}

/// Throws from [isAvailable] and/or [authenticate].
final class ThrowingAuthenticator implements Authenticator {
  ThrowingAuthenticator({this.onAvailable = true, this.onAuthenticate = true});

  final bool onAvailable;
  final bool onAuthenticate;

  @override
  Future<bool> isAvailable() async {
    if (onAvailable) throw StateError('no biometric manager');
    return true;
  }

  @override
  Future<AuthOutcome> authenticate(AuthPrompt prompt) async {
    if (onAuthenticate) throw StateError('prompt failed');
    return AuthOutcome.passed;
  }
}

/// Holds each prompt open until the test completes it.
final class PendingAuthenticatorFake implements Authenticator {
  final List<Completer<AuthOutcome>> prompts = [];
  final List<String> reasons = [];

  /// The text of every prompt shown, in order.
  final List<AuthPrompt> asked = [];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AuthOutcome> authenticate(AuthPrompt prompt) {
    reasons.add(prompt.reason);
    asked.add(prompt);
    final pending = Completer<AuthOutcome>();
    prompts.add(pending);
    return pending.future;
  }
}

final DateTime t0 = DateTime.utc(2026, 10, 18, 9);

/// A prompt as an app builds it, in English.
final AuthPrompt enPrompt = AuthPrompt.of(
  const ApsiraL10nEn(),
  appName: 'Relay',
  reason: 'Unlock Relay to see your notes and tasks.',
);

/// The overrides of a lock test: the [store] (null: none bound), the
/// [authenticator], the [clock], a log into [sink], the [screenPrivacy] (a
/// [FakeScreenPrivacy] unless given) and the [policy] (the package's
/// default, [LockPolicy.optional], unless given).
List<Override> lockOverrides({
  required LockSettingsStore? store,
  required Authenticator authenticator,
  required FakeClock clock,
  required MemorySink sink,
  ScreenPrivacy? screenPrivacy,
  LockPolicy? policy,
}) => [
  if (policy != null) lockPolicyProvider.overrideWithValue(policy),
  if (store != null) lockSettingsStoreProvider.overrideWithValue(store),
  authenticatorProvider.overrideWithValue(authenticator),
  screenPrivacyProvider.overrideWithValue(screenPrivacy ?? FakeScreenPrivacy()),
  lockClockProvider.overrideWithValue(clock),
  lockLogProvider.overrideWithValue(Log([sink], debugEnabled: false)),
];

/// A store that holds [settings].
FakeLockSettingsStore settingsOf(LockSettings settings) =>
    FakeLockSettingsStore(row: settings.toJson());
