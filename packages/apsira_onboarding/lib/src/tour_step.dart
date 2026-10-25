// From viaticum lib/app/theme/tour/tour_step.dart @ 78d38e0 (RELAY's
// TourStepData with the taps, D-APK-017).

/// A tour's step as plain values: what the tour player plays and an app's
/// tours build. A step reads and writes nothing.
library;

import 'package:flutter/widgets.dart';

/// Builds a scene at [progress], from 0 (its start) to 1 (its end state).
/// A still slide may ignore it: it is its own end state.
typedef TourSceneBuilder = Widget Function(
  BuildContext context,
  Animation<double> progress,
);

/// One step of a tour: its [title], its [body], the [scene] that shows it,
/// the scene's [summary] for TalkBack and the [taps] it teaches, all in the
/// UI language.
@immutable
class TourStepData {
  const TourStepData({
    required this.title,
    required this.body,
    required this.summary,
    required this.scene,
    this.taps = const [],
  });

  final String title;

  /// The step's message; every label of [taps] appears in it verbatim.
  final String body;

  /// What the scene shows, in one sentence: TalkBack reads it in place of
  /// the scene.
  final String summary;
  final TourSceneBuilder scene;

  /// The taps the step teaches, each path the app's own labels in order
  /// (Trips › Import package); empty when it teaches none.
  final List<List<String>> taps;
}
