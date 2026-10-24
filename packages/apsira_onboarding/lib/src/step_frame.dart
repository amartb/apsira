// From viaticum lib/features/first_open/ui/first_open_steps.dart @ 78d38e0
// (_StepFrame) and lyceum lib/features/onboarding/ui/onboarding_frame.dart
// @ 9f4ff27 (OnboardingFrame's footer), with relay's Skip, Back and primary
// styles (lib/app/theme/tour/tour_player.dart @ 09b28810; D-APK-017).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

import 'styles.dart';

/// A first-open step's frame: the gutter, an optional row of **Back** (at
/// the start) and **Skip** (at the end), the step's [child], and the
/// primary action at the bottom. It fills the screen and scrolls when large
/// text makes the step taller, so a [Spacer] in [child] still pushes the
/// action down when there is room.
///
/// [child] is laid out with its intrinsic height first (a `LayoutBuilder`
/// cannot be one). The keys are `<keyPrefix>/back`, `<keyPrefix>/skip` and
/// `<keyPrefix>/continue`.
class StepFrame extends StatelessWidget {
  const StepFrame({
    super.key,
    required this.child,
    this.onBack,
    this.onSkip,
    this.primaryLabel,
    this.onPrimary,
    this.keyPrefix = 'firstOpen',
  });

  final Widget child;

  /// Back; none when null.
  final VoidCallback? onBack;

  /// Skip; none when null.
  final VoidCallback? onSkip;

  /// The primary action's words; `commonContinue` when null.
  final String? primaryLabel;

  /// The primary action; none when null.
  final VoidCallback? onPrimary;

  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l = ApsiraL10n.of(context);
    final tokens = ApsiraTheme.of(context);
    final secondary = OnboardingStyles.secondary(tokens);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // The gutter inside the filled sliver: around it, the bottom
          // gutter would sit past the viewport and the step always scroll.
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onBack != null || onSkip != null)
                    Row(
                      children: [
                        if (onBack case final onBack?)
                          TextButton(
                            key: Key('$keyPrefix/back'),
                            onPressed: onBack,
                            style: secondary,
                            child: Text(l.commonBack),
                          ),
                        const Spacer(),
                        if (onSkip case final onSkip?)
                          TextButton(
                            key: Key('$keyPrefix/skip'),
                            onPressed: onSkip,
                            style: secondary,
                            child: Text(l.commonSkip),
                          ),
                      ],
                    ),
                  Expanded(child: child),
                  if (onPrimary case final onPrimary?) ...[
                    const SizedBox(height: ApsiraSpacing.betweenSections),
                    FilledButton(
                      key: Key('$keyPrefix/continue'),
                      onPressed: onPrimary,
                      style: OnboardingStyles.primary(tokens),
                      child: Text(
                        primaryLabel ?? l.commonContinue,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
