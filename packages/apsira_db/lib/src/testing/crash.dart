// The kill-point seam's test side (D-APK-018): lyceum
// test/data/db/restore_swap_test.dart @ 9f4ff27's `_Crash` thrown from
// `afterStep`, for every step hook of the package. Plain Dart.
import '../step_hook.dart';

/// A step hook that throws [SimulatedCrash] after [step] and does nothing
/// after any other: the "process" dies there.
StepHook crashAfter(Object step) => (done) {
  if (done == step) throw SimulatedCrash(step);
};
