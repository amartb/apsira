// From relay lib/app/theme/tour/tour_player.dart @ 09b28810, with viaticum
// lib/app/theme/tour/tour_player.dart @ 78d38e0's taps, step keys and
// wrapping dots (D-APK-017).

/// The tour player: one step of a tour at a time — its scene, its title, its
/// body and the taps it teaches — with page dots, **Skip**, **Back** and
/// **Next** (**Done** on the last step) and, on the last step, an optional
/// secondary action (first open's **Show me more**).
///
/// It takes plain values ([TourStepData]) and callbacks only, so first open
/// and Help both play it, and it reads no service: a scene is a picture
/// that moves, never a control, and a tour writes nothing.
///
/// - **Motion.** Each scene plays once over [TourPlayer.sceneDuration] and
///   holds its end state; steps cross-fade. Under reduce motion
///   (`MediaQuery.disableAnimations`) every scene is built at its end state
///   and nothing animates.
/// - **Taps.** Under the body, each path of [TourStepData.taps] is one row
///   of the app's own labels with a chevron between them; the row wraps,
///   never scrolls sideways, and TalkBack reads it as one sentence
///   ([TourPlayer.tapPathLabel]).
/// - **TalkBack** reads the step's title (a header), its body, the scene's
///   [TourStepData.summary] in place of the scene's own widgets, the taps,
///   and the dots as "Step n of m" (`tourProgress`).
/// - **Tokens only.** The primary action is the one accent fill; Skip, Back
///   and the secondary action are text buttons; the scene sits on a
///   bordered surface. Every control is at least 48 × 48 dp.
library;

import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

import 'styles.dart';
import 'tour_step.dart';

class TourPlayer extends StatefulWidget {
  const TourPlayer({
    super.key,
    required this.steps,
    required this.onDone,
    this.onSkip,
    this.secondaryLabel,
    this.onSecondary,
    this.onBackFromFirst,
    this.initialStep = 0,
    this.onStep,
    this.keyPrefix = 'tour',
    this.sceneDuration = defaultSceneDuration,
    this.tapPathLabel,
  }) : assert(steps.length > 0, 'a tour has steps'),
       assert(
         (secondaryLabel == null) == (onSecondary == null),
         'a secondary action has a label and a callback',
       );

  /// How long a scene plays with full motion.
  static const defaultSceneDuration = Duration(milliseconds: 2400);

  /// How long two steps cross-fade with full motion.
  static const stepFade = Duration(milliseconds: 200);

  final List<TourStepData> steps;

  /// Done on the last step.
  final VoidCallback onDone;

  /// Skip, from any step; without it there is no Skip.
  final VoidCallback? onSkip;

  /// The last step's secondary action (first open's "Show me more"); none
  /// when null.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Back on the first step (first open's language step); without it the
  /// first step has no Back.
  final VoidCallback? onBackFromFirst;

  /// The step shown first (first open's Back from a later step returns to
  /// the last).
  final int initialStep;

  /// Called with the new step after Next or Back moves.
  final ValueChanged<int>? onStep;

  /// The prefix of the keys: `<prefix>/skip`, `<prefix>/back`,
  /// `<prefix>/next` (Next and Done), `<prefix>/secondary`,
  /// `<prefix>/step/<n>` (step n) and `<prefix>/taps/<i>` (its path i).
  final String keyPrefix;

  final Duration sceneDuration;

  /// The sentence TalkBack reads for a path of taps, in the app's words
  /// ("Tap Trips, then Import package"); the labels joined by commas when
  /// null.
  final String Function(List<String> path)? tapPathLabel;

  @override
  State<TourPlayer> createState() => _TourPlayerState();
}

class _TourPlayerState extends State<TourPlayer> {
  late int _step = widget.initialStep.clamp(0, widget.steps.length - 1);

  bool get _last => _step == widget.steps.length - 1;

  void _go(int step) {
    setState(() => _step = step);
    widget.onStep?.call(step);
  }

  void _next() => _last ? widget.onDone() : _go(_step + 1);

  void _back() {
    if (_step > 0) {
      _go(_step - 1);
    } else {
      widget.onBackFromFirst?.call();
    }
  }

  Key _key(String name) => Key('${widget.keyPrefix}/$name');

  @override
  Widget build(BuildContext context) {
    final l = ApsiraL10n.of(context);
    final tokens = ApsiraTheme.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final step = widget.steps[_step];
    final canGoBack = _step > 0 || widget.onBackFromFirst != null;
    final secondary = OnboardingStyles.secondary(tokens);
    final onSkip = widget.onSkip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSkip != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: _key('skip'),
              onPressed: onSkip,
              style: secondary,
              child: Text(l.commonSkip),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : TourPlayer.stepFade,
            child: _StepView(
              key: _key('step/$_step'),
              step: step,
              still: still,
              duration: widget.sceneDuration,
              tapKey: (i) => _key('taps/$i'),
              tapPathLabel: widget.tapPathLabel ?? (path) => path.join(', '),
            ),
          ),
        ),
        const SizedBox(height: ApsiraSpacing.betweenCards),
        _Dots(
          current: _step,
          count: widget.steps.length,
          label: l.tourProgress(_step + 1, widget.steps.length),
        ),
        const SizedBox(height: ApsiraSpacing.betweenSections),
        if (_last && widget.secondaryLabel != null) ...[
          TextButton(
            key: _key('secondary'),
            onPressed: widget.onSecondary,
            style: secondary,
            child: Text(widget.secondaryLabel!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: ApsiraSpacing.grid * 2),
        ],
        Row(
          children: [
            if (canGoBack) ...[
              TextButton(
                key: _key('back'),
                onPressed: _back,
                style: secondary,
                child: Text(l.commonBack),
              ),
              const SizedBox(width: ApsiraSpacing.betweenCards),
            ],
            Expanded(
              child: FilledButton(
                key: _key('next'),
                onPressed: _next,
                style: OnboardingStyles.primary(tokens),
                child: Text(
                  _last ? l.commonDone : l.commonNext,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One step: its scene on a bordered surface, its title, its body and its
/// taps, in a column that scrolls when the text is large (Spanish at 200 %).
class _StepView extends StatefulWidget {
  const _StepView({
    super.key,
    required this.step,
    required this.still,
    required this.duration,
    required this.tapKey,
    required this.tapPathLabel,
  });

  final TourStepData step;
  final bool still;
  final Duration duration;
  final Key Function(int path) tapKey;
  final String Function(List<String> path) tapPathLabel;

  @override
  State<_StepView> createState() => _StepViewState();
}

class _StepViewState extends State<_StepView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.still) {
      _scene.value = 1;
    } else {
      _scene.forward();
    }
  }

  @override
  void didUpdateWidget(_StepView old) {
    super.didUpdateWidget(old);
    // Reduce motion turned on mid-scene: jump to its end.
    if (widget.still && _scene.isAnimating) {
      _scene
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    final step = widget.step;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                label: step.summary,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        border: Border.all(color: tokens.border),
                        borderRadius: BorderRadius.circular(
                          ApsiraRadii.groupCard,
                        ),
                        boxShadow: tokens.shadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          ApsiraSpacing.screenGutter,
                        ),
                        child: Center(child: step.scene(context, _scene)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ApsiraSpacing.largeTitleGutter),
              Semantics(
                header: true,
                child: Text(
                  step.title,
                  style: ApsiraTypography.slideTitle.copyWith(
                    color: tokens.ink,
                  ),
                ),
              ),
              const SizedBox(height: ApsiraSpacing.titleToMetaPills),
              Text(
                step.body,
                style: ApsiraTypography.body.copyWith(color: tokens.ink2),
              ),
              for (final (i, path) in step.taps.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: ApsiraSpacing.grid * 3),
                  child: _TapPath(
                    key: widget.tapKey(i),
                    labels: path,
                    semanticsLabel: widget.tapPathLabel(path),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One path of taps: a touch icon, then the app's own labels in order with
/// a chevron between them, wrapping onto new runs instead of scrolling
/// sideways. TalkBack reads it as one sentence, [semanticsLabel].
class _TapPath extends StatelessWidget {
  const _TapPath({
    super.key,
    required this.labels,
    required this.semanticsLabel,
  });

  final List<String> labels;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    final style = ApsiraTypography.body.copyWith(
      color: tokens.accentText,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.touch_app_outlined, color: tokens.accentText),
            const SizedBox(width: ApsiraSpacing.grid * 2),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: ApsiraSpacing.grid,
                children: [
                  for (final (i, label) in labels.indexed) ...[
                    if (i > 0) Icon(ApsiraIcons.chevron, color: tokens.ink3),
                    Text(label, style: style),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page dots, read as one "Step n of m" label; the current one is a
/// longer `accentText` bar, the others `ring` dots. They wrap when a tour
/// is long.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.current,
    required this.count,
    required this.label,
  });

  final int current;
  final int count;
  final String label;

  static const double _dot = ApsiraSpacing.titleToMetaPills;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          runSpacing: _dot,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ApsiraSpacing.grid,
                ),
                child: Container(
                  width: i == current ? ApsiraSpacing.largeTitleGutter : _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: i == current ? tokens.accentText : tokens.ring,
                    borderRadius: BorderRadius.circular(_dot),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
