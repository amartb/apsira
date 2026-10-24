// From lyceum lib/app/theme/kit/form/pill_buttons.dart @ 9f4ff27, itself
// relay lib/features/home/ui/home_widgets.dart `WelcomeCard` (D-APK-014).
import 'package:flutter/material.dart';

import '../shape.dart';
import '../theme.dart';
import '../typography.dart';

/// The kit's pill buttons, as RELAY draws them: a 44 px pill with the
/// card's side padding. The tonal pill is `tint` with its 1 px `border`
/// (D-066) and a `pill` label in `ink`; the filled pill keeps the theme's
/// accent fill.
abstract final class PillButtons {
  /// RELAY's pill height (`pillMaxHeight` + 4); Material pads the tap target
  /// to 48 dp.
  static const double height = ApsiraSizes.pillMaxHeight + ApsiraSpacing.grid;

  static const _padding = EdgeInsets.symmetric(
    horizontal: ApsiraSpacing.cardSide,
  );

  /// The tonal pill: `tint`, `border`, `ink` label.
  static ButtonStyle tonal(ApsiraTheme t) => OutlinedButton.styleFrom(
    backgroundColor: t.tint,
    foregroundColor: t.ink,
    side: BorderSide(color: t.border),
    shape: ApsiraShapes.pill,
    minimumSize: const Size(0, height),
    padding: _padding,
    textStyle: ApsiraTypography.pill,
  );

  /// The filled pill: the theme's accent fill at the pill's size.
  static ButtonStyle filled() => FilledButton.styleFrom(
    shape: ApsiraShapes.pill,
    minimumSize: const Size(0, height),
    padding: _padding,
  );

  /// Draws every Material button under [child] (filled, tonal, outlined or
  /// text) as the tonal pill, so a caller's own button keeps its widget and
  /// callbacks and takes the kit's look.
  static Widget tonalTheme(BuildContext context, {required Widget child}) {
    final style = tonal(ApsiraTheme.of(context));
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(style: style),
        outlinedButtonTheme: OutlinedButtonThemeData(style: style),
        textButtonTheme: TextButtonThemeData(style: style),
        elevatedButtonTheme: ElevatedButtonThemeData(style: style),
      ),
      child: child,
    );
  }
}
