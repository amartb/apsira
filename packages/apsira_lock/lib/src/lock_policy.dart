// The package's own (D-APK-026, D-018): no source app has a lock that cannot
// be turned off. The optional policy is D-APK-016's lock, unchanged; the
// mandatory one is APSIRA's.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_settings.dart';

/// Whether the user may turn the lock off, and what **Lock after** offers.
///
/// [optional] is the lock every app had before: off until the user turns it
/// on, and never a lock-out (D-APK-016). [mandatory] cannot be turned off,
/// offers 0, 1 and 5 minutes with 1 by default, and never opens unlocked: a
/// store that cannot be read reads as on, and a device that cannot prompt
/// keeps the cover with the Unlock button as the retry (D-018).
@immutable
final class LockPolicy {
  const LockPolicy({
    required this.isMandatory,
    required this.timeoutOptions,
    required this.defaults,
    this.cannotPromptMessage,
  });

  /// The lock the user turns on and off: today's.
  static const optional = LockPolicy(
    isMandatory: false,
    timeoutOptions: lockTimeoutOptions,
    defaults: LockSettings.defaults,
  );

  /// The lock that is always on (APSIRA, D-018).
  static const mandatory = LockPolicy(
    isMandatory: true,
    timeoutOptions: [0, 1, 5],
    defaults: LockSettings(enabled: true, timeoutMinutes: 1),
  );

  /// Whether the lock is always on.
  final bool isMandatory;

  /// The background times **Lock after** offers, in minutes; 0 is
  /// Immediately. A stored time outside them is offered too.
  final List<int> timeoutOptions;

  /// The settings when none are stored, or when they cannot be read under
  /// the mandatory policy.
  final LockSettings defaults;

  /// The cover's line, in the app's own words and language, while a
  /// mandatory lock cannot prompt (no screen lock on the device); null shows
  /// the cover's usual lines only. The package has no string of its own for
  /// it.
  final String Function(BuildContext context)? cannotPromptMessage;

  /// This policy with the app's [cannotPromptMessage].
  LockPolicy copyWith({
    String Function(BuildContext context)? cannotPromptMessage,
  }) => LockPolicy(
    isMandatory: isMandatory,
    timeoutOptions: timeoutOptions,
    defaults: defaults,
    cannotPromptMessage: cannotPromptMessage ?? this.cannotPromptMessage,
  );

  @override
  String toString() =>
      'LockPolicy(${isMandatory ? 'mandatory' : 'optional'}, '
      'timeoutOptions: $timeoutOptions)';
}

/// The app's [LockPolicy]; [LockPolicy.optional] unless the app overrides it
/// (APSIRA: `LockPolicy.mandatory.copyWith(cannotPromptMessage: …)`). The
/// settings, the controller, the shield and the Settings rows follow it.
final lockPolicyProvider = Provider<LockPolicy>((ref) => LockPolicy.optional);

/// How long a mandatory read waits for the app's store before it reads as
/// the policy's defaults: below `lockSettingsReadBound` (2 s), so the launch locks
/// with them instead of waiting out the controller's own bound.
const mandatoryReadBound = Duration(seconds: 1);

/// The app's store under the mandatory policy: whatever is stored, the lock
/// reads and is written as on.
///
/// A read is [inner]'s with `enabled: true`; with no [inner], a read that
/// throws or one slower than [mandatoryReadBound], it is [policy]'s defaults
/// and [onReadFailed] is told why (null: no store bound). A write stores
/// `enabled: true` through [inner], which keeps the fields it does not know;
/// with no [inner] it throws a [StateError].
final class MandatoryLockSettingsStore implements LockSettingsStore {
  MandatoryLockSettingsStore(
    this.inner, {
    this.policy = LockPolicy.mandatory,
    this.onReadFailed,
  });

  /// The app's store; null when none is bound.
  final LockSettingsStore? inner;

  final LockPolicy policy;

  final void Function(Object? error)? onReadFailed;

  @override
  Future<LockSettings> read() async {
    final store = inner;
    if (store == null) {
      onReadFailed?.call(null);
      return policy.defaults;
    }
    try {
      final stored = await store.read().timeout(mandatoryReadBound);
      return stored.copyWith(enabled: true);
    } catch (e) {
      onReadFailed?.call(e);
      return policy.defaults;
    }
  }

  @override
  Future<void> write(LockSettings settings) async {
    final store = inner;
    if (store == null) throw StateError('no LockSettingsStore bound');
    await store.write(settings.copyWith(enabled: true));
  }
}
