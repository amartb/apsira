// From relay lib/features/first_open/state/first_open_flow.dart @ 09b28810
// (the flow as a value; every move returns a new one), generic over the
// app's own step enum (D-APK-017).
import 'package:flutter/foundation.dart';

/// Where first open is: the [current] step of the app's [steps], in order.
///
/// A value: every move returns a new flow. [next] and [back] stop at the
/// ends; [goTo] jumps to a named step (a skip). What each step means, and
/// any state beside the step (a tour's own step, a chosen folder), is the
/// app's.
@immutable
final class FirstOpenFlow<S> {
  /// The flow at [current], or at the first of [steps]. Throws an
  /// [ArgumentError] when [steps] is empty or repeats a step, or when
  /// [current] is not one of them.
  factory FirstOpenFlow(List<S> steps, {S? current}) {
    if (steps.isEmpty) {
      throw ArgumentError.value(steps, 'steps', 'a flow has steps');
    }
    if (steps.toSet().length != steps.length) {
      throw ArgumentError.value(steps, 'steps', 'each step once');
    }
    final fixed = List<S>.unmodifiable(steps);
    return FirstOpenFlow._(
      fixed,
      current == null ? 0 : _indexIn(fixed, current),
    );
  }

  const FirstOpenFlow._(this.steps, this.index);

  /// The steps, in order; unmodifiable.
  final List<S> steps;

  /// [current]'s place in [steps], from 0.
  final int index;

  S get current => steps[index];

  bool get isFirst => index == 0;

  bool get isLast => index == steps.length - 1;

  /// The next step; the last stays where it is.
  FirstOpenFlow<S> next() => isLast ? this : FirstOpenFlow._(steps, index + 1);

  /// The previous step; the first stays where it is.
  FirstOpenFlow<S> back() => isFirst ? this : FirstOpenFlow._(steps, index - 1);

  /// The flow at [step]. Throws an [ArgumentError] when it is not one of
  /// [steps].
  FirstOpenFlow<S> goTo(S step) =>
      FirstOpenFlow._(steps, _indexIn(steps, step));

  static int _indexIn<S>(List<S> steps, S step) {
    final i = steps.indexOf(step);
    if (i < 0) throw ArgumentError.value(step, 'step', 'not one of $steps');
    return i;
  }

  @override
  bool operator ==(Object other) =>
      other is FirstOpenFlow<S> &&
      other.index == index &&
      listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(index, Object.hashAll(steps));

  @override
  String toString() =>
      'FirstOpenFlow($current, ${index + 1} of ${steps.length})';
}
