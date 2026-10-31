// From relay lib/features/lock/state/lock_controller.dart @ 09b28810,
// unchanged but for its seams (D-APK-016): the settings come from
// lockSettingsProvider (the app's LockSettingsStore) in place of RELAY's
// stream of its `lock` row; `unlock` takes the AuthPrompt the shield builds;
// the clock and the log are lockClockProvider and lockLogProvider, which the
// app binds to its own.
//
// The app lock: locked at launch and after the background timeout when
// `enabled`, unlocked by the `Authenticator` prompt.
//
// Never a lock-out: when the settings cannot be read (the read throws, or
// has not answered within [lockSettingsReadBound]), or the Authenticator is
// unavailable or throws, the lock does not engage and a content-free log line
// gives the code. The lock is casual-access protection, not encryption.
//
// The package's own (D-APK-026, D-018): under LockPolicy.mandatory the lock
// never opens unlocked, so the not-engaged paths above become "locked with
// the policy's defaults" and "locked, cannot prompt" (no counter, no
// back-off); and `reconfirm` asks for a fresh confirmation before a
// sensitive act.
import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'authenticator.dart';
import 'lock_policy.dart';
import 'lock_settings.dart';
import 'recents_privacy.dart';
import 'screen_privacy.dart';

/// The app's [Authenticator]: `LocalAuthAuthenticator()` in the app, a fake
/// in tests. Unbound, the lock never engages.
final authenticatorProvider = Provider<Authenticator>(
  (ref) => throw UnimplementedError('override authenticatorProvider'),
);

/// The app's [ScreenPrivacy]: `FlagSecureScreenPrivacy()` in the app.
/// Unbound, hide in recents logs `lock.recentsNotApplied` and the lock
/// carries on.
final screenPrivacyProvider = Provider<ScreenPrivacy>(
  (ref) => throw UnimplementedError('override screenPrivacyProvider'),
);

/// The clock the background timeout is measured on: the app's own [Clock]
/// (`lockClockProvider.overrideWith((ref) => ref.watch(clockProvider))`).
/// Unbound, the background never shields.
final lockClockProvider = Provider<Clock>(
  (ref) => throw UnimplementedError('override lockClockProvider'),
);

/// The log the lock writes its warnings to: the app's own [Log]. Unbound,
/// the lines are dropped.
final lockLogProvider = Provider<Log>(
  (ref) => throw UnimplementedError('override lockLogProvider'),
);

/// Where the lock is.
enum LockPhase {
  /// Launch, before the settings are read: covered, no prompt yet.
  starting,

  /// The app is shown.
  unlocked,

  /// In the background with the lock on: covered until the return decides
  /// whether the timeout has passed.
  shielded,

  /// Covered, waiting for the prompt or for a retry.
  locked,

  /// Covered while the system prompt is up.
  authenticating,
}

/// Why the lock did not engage; the log's `code` field.
enum LockSkip {
  /// No biometric and no screen lock on the device.
  unavailable,

  /// The Authenticator threw.
  authenticatorError,

  /// The settings could not be read: no store bound, a read that threw or
  /// did not answer within [lockSettingsReadBound].
  settingsUnreadable,
}

/// The lock as the gate shows it.
@immutable
final class LockState {
  const LockState(this.phase, {this.promptDue = false, this.lastOutcome});

  final LockPhase phase;

  /// The gate should start the prompt once the cover is drawn.
  final bool promptDue;

  /// The last prompt's outcome while still [LockPhase.locked]: `failed` or
  /// `cancelled` shows the retry message.
  final AuthOutcome? lastOutcome;

  /// Whether the cover is up and the content hidden.
  bool get covered => phase != LockPhase.unlocked;

  /// Whether the cover offers the Unlock button.
  bool get canUnlock => phase == LockPhase.locked;

  /// Whether a mandatory lock is up on a device that cannot prompt (no
  /// screen lock, or an Authenticator that throws): the Unlock button is the
  /// retry and the cover shows the policy's `cannotPromptMessage`.
  bool get cannotPrompt =>
      phase == LockPhase.locked && lastOutcome == AuthOutcome.unavailable;

  /// Whether the cover says the last attempt did not unlock.
  bool get showRetry =>
      phase == LockPhase.locked &&
      (lastOutcome == AuthOutcome.failed ||
          lastOutcome == AuthOutcome.cancelled);

  @override
  bool operator ==(Object other) =>
      other is LockState &&
      other.phase == phase &&
      other.promptDue == promptDue &&
      other.lastOutcome == lastOutcome;

  @override
  int get hashCode => Object.hash(phase, promptDue, lastOutcome);

  @override
  String toString() =>
      'LockState(${phase.name}, promptDue: $promptDue, '
      'lastOutcome: ${lastOutcome?.name})';
}

/// The lock controller. The shield ([LockShield]) reports the app going to
/// and coming back from the background and starts the prompt.
final lockControllerProvider = NotifierProvider<LockController, LockState>(
  LockController.new,
  retry: (_, _) => null,
);

/// How long launch waits for the settings before it opens the app without
/// the lock. An app's store is open before the first frame, so the read
/// takes milliseconds; 2 s is far above that on a slow phone and short
/// enough that a stalled read never shuts the user out. The cover stays up
/// meanwhile, so nothing flashes.
const lockSettingsReadBound = Duration(seconds: 2);

/// What [LockController.reconfirm] answered.
enum ReconfirmOutcome {
  /// The user confirmed: the act goes ahead.
  confirmed,

  /// Failed, cancelled, or not asked (covered, or another re-confirm
  /// pending): the act is refused.
  declined,

  /// Optional policy: the device cannot prompt, so the act goes ahead
  /// (never a lock-out, D-APK-016).
  skipped,

  /// Mandatory policy: the device cannot prompt, so the act is refused
  /// (D-018).
  unavailable;

  /// Whether the act goes ahead.
  bool get proceeds => this == confirmed || this == skipped;
}

final class LockController extends Notifier<LockState> {
  LockSettings _settings = const LockSettings();
  bool _settingsRead = false;
  bool _reconfirming = false;
  late final LockPolicy _policy = ref.read(lockPolicyProvider);
  DateTime? _backgroundedAt;
  Timer? _readBound;
  late final RecentsPrivacy _recents = RecentsPrivacy(
    port: () => ref.read(screenPrivacyProvider),
    onError: (e) =>
        _log((log) => log.warning('lock.recentsNotApplied', error: e)),
  );

  @override
  LockState build() {
    final AsyncValue<LockSettings> first;
    try {
      first = ref.read(lockSettingsProvider);
    } catch (e) {
      return _unreadableAtLaunch(e);
    }
    if (first case AsyncError(:final error)) {
      // No store bound, or a read that failed at once.
      return _unreadableAtLaunch(error);
    }
    final subscription = ref.listen(
      lockSettingsProvider,
      (_, next) => _onValue(next),
    );
    _readBound = Timer(lockSettingsReadBound, _onSettingsTimeout);
    ref.onDispose(() {
      _readBound?.cancel();
      subscription.close();
    });
    if (first case AsyncData(:final value)) {
      // Already read: applied once this build has set the first state.
      scheduleMicrotask(() {
        if (ref.mounted) _onSettings(value);
      });
    }
    return const LockState(LockPhase.starting);
  }

  /// The settings could not be read at launch: open without the lock, or,
  /// under the mandatory policy, lock with its defaults.
  LockState _unreadableAtLaunch(Object? error) {
    _settingsRead = true;
    if (!_policy.isMandatory) {
      _skip(LockSkip.settingsUnreadable, error);
      return const LockState(LockPhase.unlocked);
    }
    _log((log) => log.warning('lock.settingsReadFailed', error: error));
    _settings = _policy.defaults;
    scheduleMicrotask(() {
      if (ref.mounted) _applyFirst(_policy.defaults);
    });
    return const LockState(LockPhase.starting);
  }

  void _onValue(AsyncValue<LockSettings> next) {
    switch (next) {
      case AsyncData(:final value):
        _onSettings(value);
      case AsyncError(:final error):
        _onSettingsError(error);
      case AsyncLoading():
        break;
    }
  }

  /// The current settings (the defaults until the row is read).
  LockSettings get settings => _settings;

  /// Hide in recents, for an app with routes exempt from the lock: its
  /// router and its exempt routes tell it which kind of route is shown.
  RecentsPrivacy get recents => _recents;

  void _onSettings(LockSettings value) {
    _readBound?.cancel();
    final first = !_settingsRead;
    _settingsRead = true;
    _applySettings(value, first: first);
  }

  void _applyFirst(LockSettings value) => _applySettings(value, first: true);

  void _applySettings(LockSettings value, {required bool first}) {
    final settings = _policy.isMandatory
        ? value.copyWith(enabled: true)
        : value;
    _settings = settings;
    _recents.apply(settings.hideInRecents);
    if (!settings.enabled) {
      // Turned off, or off from the start: nothing stays covered.
      _backgroundedAt = null;
      if (state.covered && state.phase != LockPhase.authenticating) {
        state = const LockState(LockPhase.unlocked);
      }
      return;
    }
    // Turned on while the app is open: it locks next launch or after the
    // next background timeout, not under the user's hands.
    if (first) unawaited(_engage());
  }

  /// No row within [lockSettingsReadBound]: open without the lock. A row
  /// that arrives later only updates the settings, as a change would.
  /// Under the mandatory policy it locks with the policy's defaults.
  void _onSettingsTimeout() {
    if (_settingsRead) return;
    _unreadable(TimeoutException('lock settings', lockSettingsReadBound));
  }

  void _unreadable(Object? error) {
    _settingsRead = true;
    if (_policy.isMandatory) {
      _log((log) => log.warning('lock.settingsReadFailed', error: error));
      _applySettings(_policy.defaults, first: true);
      return;
    }
    _skip(
      LockSkip.settingsUnreadable,
      error is TimeoutException ? null : error,
    );
    state = const LockState(LockPhase.unlocked);
  }

  void _onSettingsError(Object error) {
    _readBound?.cancel();
    if (_settingsRead) {
      // The last settings read stay in force.
      _log((log) => log.warning('lock.settingsReadFailed', error: error));
      return;
    }
    _unreadable(error);
  }

  /// The app went to the background (`paused`). While the prompt is up the
  /// app is paused by the system credential screen itself, so that is not a
  /// background, nor is it while a [reconfirm] prompt is up.
  void backgrounded() {
    if (!_settings.enabled || _reconfirming) return;
    switch (state.phase) {
      case LockPhase.unlocked:
        final now = _now();
        if (now == null) return;
        _backgroundedAt = now;
        state = const LockState(LockPhase.shielded);
      case LockPhase.locked:
        state = LockState(LockPhase.locked, lastOutcome: state.lastOutcome);
      case LockPhase.starting:
      case LockPhase.shielded:
      case LockPhase.authenticating:
        break;
    }
  }

  /// The app is coming back from the background: hide in recents is
  /// applied again (a recreated activity has lost the window flag); the
  /// lock locks when the timeout has passed (0 locks at once), and prompts
  /// again when it was locked.
  void foregrounded() {
    _recents.reapply();
    switch (state.phase) {
      case LockPhase.shielded:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        final now = _now();
        final elapsed = since == null || now == null
            ? null
            : now.difference(since);
        // A clock that went backwards locks: the prompt is always there.
        if (elapsed == null ||
            elapsed.isNegative ||
            elapsed >= _settings.timeout) {
          unawaited(_engage());
        } else {
          state = const LockState(LockPhase.unlocked);
        }
      case LockPhase.locked:
        state = LockState(
          LockPhase.locked,
          promptDue: true,
          lastOutcome: state.lastOutcome,
        );
      case LockPhase.starting:
      case LockPhase.unlocked:
      case LockPhase.authenticating:
        break;
    }
  }

  /// Locks now, from the app's own "Lock now" (LYCEUM's Settings row,
  /// D-APK-016): covered with the prompt due, as after the background
  /// timeout. Only while the lock is on and the app is shown; already
  /// covered, or with the lock off, nothing changes. Never a lock-out: a
  /// device that cannot prompt leaves the app open with the log's code
  /// (under the mandatory policy it stays covered, [LockState.cannotPrompt]).
  Future<void> lockNow() async {
    if (!_settings.enabled || state.phase != LockPhase.unlocked) return;
    await _engage();
  }

  /// Shows the system prompt with [prompt]'s text ([AuthPrompt.of]).
  /// Passed unlocks; failed or cancelled stays locked with the retry; an
  /// unavailable or throwing Authenticator unlocks (under the mandatory
  /// policy it stays locked, [LockState.cannotPrompt]).
  Future<void> unlock(AuthPrompt prompt) async {
    if (state.phase != LockPhase.locked) return;
    state = const LockState(LockPhase.authenticating);
    AuthOutcome outcome;
    try {
      outcome = await ref.read(authenticatorProvider).authenticate(prompt);
    } catch (e) {
      if (!ref.mounted) return;
      _cannotPrompt(LockSkip.authenticatorError, e);
      return;
    }
    if (!ref.mounted || state.phase != LockPhase.authenticating) return;
    switch (outcome) {
      case AuthOutcome.passed:
        state = const LockState(LockPhase.unlocked);
      case AuthOutcome.failed:
      case AuthOutcome.cancelled:
        state = LockState(LockPhase.locked, lastOutcome: outcome);
      case AuthOutcome.unavailable:
        _cannotPrompt(LockSkip.unavailable);
    }
  }

  /// Asks for a fresh confirmation before a sensitive act (D-018: install,
  /// restore, pair, revoke), whatever the settings say, with [prompt]'s
  /// text. Only while the app is shown: covered, or with another re-confirm
  /// pending, it answers [ReconfirmOutcome.declined] without a prompt.
  /// Passed confirms; failed or cancelled declines (no counter, no
  /// back-off). A device that cannot prompt, or an Authenticator that
  /// throws, answers [ReconfirmOutcome.skipped] (logged
  /// `lock.reconfirmSkipped`), or under the mandatory policy
  /// [ReconfirmOutcome.unavailable] (logged `lock.reconfirmUnavailable`),
  /// each with its `code`. While the prompt is up, a background is not one.
  Future<ReconfirmOutcome> reconfirm(AuthPrompt prompt) async {
    if (state.phase != LockPhase.unlocked || _reconfirming) {
      return ReconfirmOutcome.declined;
    }
    _reconfirming = true;
    AuthOutcome outcome;
    try {
      outcome = await ref.read(authenticatorProvider).authenticate(prompt);
    } catch (e) {
      _reconfirming = false;
      if (!ref.mounted) return ReconfirmOutcome.declined;
      return _reconfirmCannot(LockSkip.authenticatorError, e);
    }
    _reconfirming = false;
    if (!ref.mounted || state.covered) return ReconfirmOutcome.declined;
    return switch (outcome) {
      AuthOutcome.passed => ReconfirmOutcome.confirmed,
      AuthOutcome.failed || AuthOutcome.cancelled => ReconfirmOutcome.declined,
      AuthOutcome.unavailable => _reconfirmCannot(LockSkip.unavailable),
    };
  }

  ReconfirmOutcome _reconfirmCannot(LockSkip code, [Object? error]) {
    final mandatory = _policy.isMandatory;
    _log(
      (log) => log.warning(
        mandatory ? 'lock.reconfirmUnavailable' : 'lock.reconfirmSkipped',
        error: error,
        fields: {'code': LogValue.code(code.name)},
      ),
    );
    return mandatory ? ReconfirmOutcome.unavailable : ReconfirmOutcome.skipped;
  }

  /// The device cannot prompt: open without the lock, or, under the
  /// mandatory policy, stay locked with the Unlock button as the retry and
  /// no prompt due.
  void _cannotPrompt(LockSkip code, [Object? error]) {
    _skip(code, error);
    state = _policy.isMandatory
        ? const LockState(
            LockPhase.locked,
            lastOutcome: AuthOutcome.unavailable,
          )
        : const LockState(LockPhase.unlocked);
  }

  /// Locks with a prompt due, when the device can prompt; otherwise leaves
  /// the app open (under the mandatory policy, locked without a prompt due).
  Future<void> _engage() async {
    bool available;
    try {
      available = await ref.read(authenticatorProvider).isAvailable();
    } catch (e) {
      if (!ref.mounted) return;
      _cannotPrompt(LockSkip.authenticatorError, e);
      return;
    }
    if (!ref.mounted) return;
    if (!_settings.enabled) {
      state = const LockState(LockPhase.unlocked);
      return;
    }
    if (!available) {
      _cannotPrompt(LockSkip.unavailable);
      return;
    }
    state = const LockState(LockPhase.locked, promptDue: true);
  }

  DateTime? _now() {
    try {
      return ref.read(lockClockProvider).nowUtc();
    } catch (e) {
      _log((log) => log.warning('lock.clockUnreadable', error: e));
      return null;
    }
  }

  void _skip(LockSkip code, [Object? error]) => _log(
    (log) => log.warning(
      'lock.notEngaged',
      error: error,
      fields: {'code': LogValue.code(code.name)},
    ),
  );

  /// Logs through the bound log; without one (a test that binds none) the
  /// line is dropped, never thrown.
  void _log(void Function(Log log) write) {
    try {
      write(ref.read(lockLogProvider));
    } catch (_) {
      // Logging never stops the app.
    }
  }
}
