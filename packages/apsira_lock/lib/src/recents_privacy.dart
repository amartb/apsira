// From relay lib/features/lock/state/recents_privacy.dart @ 09b28810,
// unchanged but for names: `enterRelay` is [RecentsPrivacy.leaveExempt].
import 'dart:async';

import 'screen_privacy.dart';

/// "Hide in recent apps": `hideInRecents` applied to the [ScreenPrivacy]
/// port, whether the lock itself is on or not. With it on the recents
/// switcher shows no content and screenshots of the app are blocked, the
/// trade-off the setting explains.
///
/// Applies the setting to the port: at launch, on every change, and again
/// on every return from the background ([reapply]), since Android does not
/// keep the window flag when it recreates the activity.
///
/// Where an app has routes exempt from the lock (RELAY's KAIROS space),
/// [leaveExempt] and [exemptShown] say which kind of route is shown; without
/// them the window follows the setting alone.
///
/// The port is reached through [port] and failures through [onError]; a
/// port that is unbound or throws never stops the app or the lock.
final class RecentsPrivacy {
  RecentsPrivacy({required this.port, required this.onError});

  /// Reads the port; may throw when it is not bound.
  final ScreenPrivacy Function() port;

  /// Told of a port that could not be read or could not apply the flag.
  final void Function(Object error) onError;

  bool? _hidden;

  /// What was last asked for; null until the setting is read.
  bool? get hidden => _hidden;

  /// Whether the route shown is exempt: the flag is then off whatever the
  /// setting. Only [exemptShown] sets it and only [leaveExempt] clears it.
  bool _exempt = false;

  /// Renewed by every [leaveExempt]: an [exemptShown] that carries an older
  /// one comes from an exempt route the app is already leaving.
  Object _ticket = Object();

  /// The ticket an exempt route takes when it is built, for [exemptShown].
  Object get ticket => _ticket;

  /// Applies [hidden] when it differs from what was last asked for.
  void apply(bool hidden) {
    if (_hidden == hidden) return;
    _hidden = hidden;
    _set(hidden && !_exempt);
  }

  /// Applies again what was last asked for, if anything.
  void reapply() {
    if (_hidden case final hidden?) _set(hidden && !_exempt);
  }

  /// Before a guarded route draws: the flag goes back on while the setting
  /// is on. Completes once the port has answered, so the router can hold the
  /// navigation until then; a port that fails is reported to [onError] and
  /// the navigation goes on, as the setting's own failures never stop the
  /// app.
  Future<void> leaveExempt() async {
    _ticket = Object();
    if (!_exempt) return;
    _exempt = false;
    if (_hidden != true) return;
    try {
      await port().setHidden(true);
    } catch (e) {
      onError(e);
    }
  }

  /// An exempt route taken with [ticket] is shown: the flag comes off while
  /// the setting is on, unless a crossing into a guarded route has begun
  /// since.
  void exemptShown(Object ticket) {
    if (_exempt || !identical(ticket, _ticket)) return;
    _exempt = true;
    if (_hidden == true) _set(false);
  }

  void _set(bool hidden) {
    final Future<void> applied;
    try {
      applied = port().setHidden(hidden);
    } catch (e) {
      onError(e);
      return;
    }
    unawaited(applied.catchError(onError));
  }
}
