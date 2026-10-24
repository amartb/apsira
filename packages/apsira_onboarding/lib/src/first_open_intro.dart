// From viaticum lib/features/first_open/ui/first_open_intro.dart @ 78d38e0
// (itself RELAY's, with the reduce-motion cross-fade, the Material ground
// and the TalkBack button), on relay
// lib/features/first_open/ui/first_open_intro.dart @ 09b28810's type and
// tokens; the app's mark and title are parameters (D-APK-017).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

/// The intro animation, on the dark ground in both themes.
///
/// Full motion, about 4.5 s: the app's [mark] draws itself (0.1–1.5 s), the
/// [appTitle] fades up with its tracking tightening (1.5–2.3 s), both lift
/// and fade out (3.0–3.5 s), then "Developed by" and the Apsira Labs lockup
/// (3.5–4.0 s). Under reduce motion nothing draws or moves: the whole mark
/// and name, then a 1 s cross-fade to the lockup. It calls [onDone] once,
/// at the end or on the first tap; TalkBack hears a button that skips it.
class FirstOpenIntro extends StatefulWidget {
  const FirstOpenIntro({
    super.key,
    required this.appTitle,
    required this.mark,
    required this.onDone,
    this.lockup,
  });

  /// The app's name, set upper case as its wordmark.
  final String appTitle;

  /// The app's mark at [progress], from 0 (nothing drawn) to 1 (whole), in
  /// a [markSize] square, with its own semantics label.
  final Widget Function(double progress) mark;

  final VoidCallback onDone;

  /// The Apsira Labs horizontal lockup in its reversed colourway; by
  /// default [ApsiraBrand.lockupReversed] at [lockupWidth], used as
  /// supplied and never recoloured.
  final Widget? lockup;

  /// The full-motion intro, after which the flow continues by itself.
  static const fullDuration = Duration(milliseconds: 4500);

  /// The reduce-motion intro.
  static const reducedDuration = Duration(milliseconds: 2500);

  /// The mark's side, in logical pixels.
  static const double markSize = 120;

  /// The lockup's width, in logical pixels: above the brand's 160 px
  /// minimum for a horizontal lockup.
  static const double lockupWidth = 200;

  /// The intro's keys: the whole (its tap target), the mark and name group,
  /// the name, and the credit.
  static const introKey = Key('firstOpen/intro');
  static const brandKey = Key('firstOpen/intro/brand');
  static const nameKey = Key('firstOpen/intro/name');
  static const creditKey = Key('firstOpen/intro/credit');

  @override
  State<FirstOpenIntro> createState() => _FirstOpenIntroState();
}

class _FirstOpenIntroState extends State<FirstOpenIntro>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late bool _reduced;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _controller =
        AnimationController(
            vsync: this,
            duration: _reduced
                ? FirstOpenIntro.reducedDuration
                : FirstOpenIntro.fullDuration,
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finish();
          })
          ..forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _controller?.stop();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// [ms] mapped onto 0–1 between [from] and [to] milliseconds.
  static double _span(double ms, double from, double to) =>
      ((ms - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = ApsiraL10n.of(context);
    // The intro is on the dark ground in both themes.
    const tokens = ApsiraTheme.dark;
    final controller = _controller!;
    final lockup =
        widget.lockup ??
        const Image(
          image: ApsiraBrand.lockupReversed,
          width: FirstOpenIntro.lockupWidth,
          excludeFromSemantics: true,
        );
    return Semantics(
      key: FirstOpenIntro.introKey,
      container: true,
      explicitChildNodes: true,
      button: true,
      hint: l10n.firstOpenIntroSkipHint,
      onTap: _finish,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _finish,
        // A Material, not a bare ColoredBox: its text needs the theme's
        // DefaultTextStyle, or Flutter's fallback underlines it in yellow.
        child: Material(
          color: tokens.ground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final ms =
                      controller.value *
                      controller.duration!.inMilliseconds.toDouble();
                  final f = _reduced ? _reducedFrame(ms) : _fullFrame(ms);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        key: FirstOpenIntro.brandKey,
                        opacity: f.brand,
                        child: Transform.translate(
                          offset: Offset(0, -f.lift),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: FirstOpenIntro.markSize,
                                child: widget.mark(f.mark),
                              ),
                              const SizedBox(
                                height: ApsiraSpacing.betweenSections,
                              ),
                              Opacity(
                                key: FirstOpenIntro.nameKey,
                                opacity: f.name,
                                child: Transform.translate(
                                  offset: Offset(0, f.nameRise),
                                  // The wordmark shrinks to fit, never cut.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.appTitle.toUpperCase(),
                                      maxLines: 1,
                                      style: ApsiraTypeStyle.wordmark
                                          .at(size: 40, trackingEm: f.tracking)
                                          .copyWith(color: tokens.ink),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Opacity(
                        key: FirstOpenIntro.creditKey,
                        opacity: f.credit,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.firstOpenDevelopedBy,
                              textAlign: TextAlign.center,
                              style: ApsiraTypography.meta.copyWith(
                                color: tokens.ink3,
                              ),
                            ),
                            const SizedBox(
                              height: ApsiraSpacing.titleToMetaPills,
                            ),
                            Semantics(
                              container: true,
                              label: l10n.firstOpenApsiraLabs,
                              image: true,
                              child: ExcludeSemantics(child: lockup),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static _Frame _fullFrame(double ms) {
    final name = Curves.easeOut.transform(_span(ms, 1500, 2300));
    final lift = Curves.easeIn.transform(_span(ms, 3000, 3500));
    return (
      mark: _span(ms, 100, 1500),
      name: name,
      nameRise: (1 - name) * ApsiraSpacing.betweenSections,
      tracking: 0.14 - 0.04 * name,
      brand: 1 - lift,
      lift: lift * ApsiraSpacing.largeTitleGutter,
      credit: Curves.easeOut.transform(_span(ms, 3500, 4000)),
    );
  }

  static _Frame _reducedFrame(double ms) {
    final fade = _span(ms, 1000, 2000);
    return (
      mark: 1,
      name: 1,
      nameRise: 0,
      tracking: 0.10,
      brand: 1 - fade,
      lift: 0,
      credit: fade,
    );
  }
}

/// One frame of the intro: the mark's drawn [mark] fraction, the name's
/// opacity, rise and tracking, the brand group's opacity and lift, and the
/// credit's opacity.
typedef _Frame = ({
  double mark,
  double name,
  double nameRise,
  double tracking,
  double brand,
  double lift,
  double credit,
});
