// From relay lib/app/theme/tour/tour_player.dart @ 09b28810
// (TourPlayer.primaryStyle and secondaryStyle), shared by every first-open
// step and the tour player.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

/// The buttons of first open and the tours.
abstract final class OnboardingStyles {
  /// The primary action's style: the one accent fill on the screen, a pill
  /// at least 48 dp tall. A label that wraps (Spanish at 200 %) keeps clear
  /// of the pill's rounded ends.
  static ButtonStyle primary(ApsiraTheme tokens) => FilledButton.styleFrom(
    backgroundColor: tokens.accentFill,
    foregroundColor: tokens.onAccent,
    shape: ApsiraShapes.pill,
    textStyle: ApsiraTypography.pill,
    minimumSize: const Size.fromHeight(ApsiraSizes.floatingTopBarButton),
    padding: const EdgeInsets.symmetric(
      horizontal: ApsiraSpacing.grid * 8,
      vertical: ApsiraSpacing.grid * 3,
    ),
  );

  /// The text buttons' style: `ink2` words, no fill, 48 dp at least.
  static ButtonStyle secondary(ApsiraTheme tokens) => TextButton.styleFrom(
    foregroundColor: tokens.ink2,
    textStyle: ApsiraTypography.pill,
    minimumSize: const Size(
      ApsiraSizes.floatingTopBarButton,
      ApsiraSizes.floatingTopBarButton,
    ),
  );
}
