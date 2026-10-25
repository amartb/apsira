// From lyceum lib/data/db/restore_swap.dart @ 9f4ff27 (the `afterStep` seam),
// generalised to every step of the opener, the swap and the snapshot
// (D-APK-018).
/// The kill-point seam: each step of a migration, a restore swap, a roll
/// back or a snapshot calls the hook with its step once the step is done
/// (and durable, where the step syncs). Null in the app; a test passes
/// `crashAfter(step)` (`package:apsira_db/testing.dart`) to stop there.
library;

import 'package:drift/isolate.dart' show DriftRemoteException;

/// Called after each named step; the step is an enum value of the
/// operation ([Object] so one hook can watch several operations).
typedef StepHook = void Function(Object step);

/// The crash a test's step hook throws. The code that runs the steps lets it
/// through untouched (no clean-up, no log, no fallback), as a process that
/// died there would; anything else a hook throws is handled like the step's
/// own failure.
final class SimulatedCrash extends Error {
  SimulatedCrash(this.step);

  /// The step after which the "process" died.
  final Object step;

  @override
  String toString() => 'SimulatedCrash after $step';
}

/// Throws [error] on, with [stack], when it is a [SimulatedCrash] or carries
/// one: a crash inside a migration reaches the opener wrapped in drift's
/// [DriftRemoteException] (once per isolate it crossed). Anything else
/// returns, for the caller's own handling.
void passSimulatedCrash(Object error, StackTrace stack) {
  Object? cause = error;
  while (cause is DriftRemoteException) {
    cause = cause.remoteCause;
  }
  if (cause is SimulatedCrash) Error.throwWithStackTrace(cause, stack);
}
