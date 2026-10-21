// From relay lib/app/theme/relay_colors.dart @ 5f606e9
/// The raw colour values of UX §2.2, light and dark (D-059, D-064–D-066).
///
/// UX § and D-nnn references are RELAY's documents at 5f606e9. This file is
/// the only place in any Apsira package with colour literals. Widgets never
/// read these classes: they read token names from `ApsiraTheme`, which picks
/// the light or dark set. The values are checked against UX §2.2 by
/// `test/theme_test.dart` and for contrast by `test/tokens_contrast_test.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The semantic colour families (UX §2.2 "Semantic tonal pairs").
///
/// Users never pick raw hex values: a status, select option or type picks a
/// family, which supplies contrast-checked light and dark values.
enum ApsiraFamily { redOrange, amber, blue, pink, green, neutral }

/// One family's tonal pair in one theme: a [solid] for rings, dots and
/// icons, and a [container] with its [onContainer] for pills and tiles.
@immutable
class ApsiraFamilyColors {
  const ApsiraFamilyColors({
    required this.solid,
    required this.container,
    required this.onContainer,
  });

  final Color solid;
  final Color container;
  final Color onContainer;

  static ApsiraFamilyColors lerp(
    ApsiraFamilyColors a,
    ApsiraFamilyColors b,
    double t,
  ) => ApsiraFamilyColors(
    solid: Color.lerp(a.solid, b.solid, t)!,
    container: Color.lerp(a.container, b.container, t)!,
    onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
  );
}

/// UX §2.2, light column.
abstract final class ApsiraLightColors {
  static const ground = Color(0xFFE3E9E5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFD2DBD6);
  static const tint = Color(0xFFEDF1EE);
  static const panel = Color(0xFFE3E9E5);
  static const ink = Color(0xFF101513);
  static const ink2 = Color(0xFF3F4A45);
  static const ink3 = Color(0xFF5E6964);
  static const line = Color(0xFFE3E9E5);
  static const lineOnTint = Color(0xFFDCE3DF);
  // D-097: darkened from #8C9690 to meet 3:1 on `tint` and `ground`.
  static const ring = Color(0xFF7A847E);
  static const scrim = Color.fromRGBO(16, 21, 19, 0.40);
  static const shadow = [
    BoxShadow(
      color: Color.fromRGBO(16, 21, 19, 0.06),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(16, 21, 19, 0.22),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -12,
    ),
  ];

  static const accentFill = Color(0xFF007A4C);
  static const onAccent = Color(0xFFFFFFFF);
  static const accentText = Color(0xFF006B43);
  static const accC = Color(0xFFD2F0E1);
  static const onAccC = Color(0xFF00452B);

  static const families = {
    ApsiraFamily.redOrange: ApsiraFamilyColors(
      solid: Color(0xFFD4380D),
      container: Color(0xFFFFE4DA),
      onContainer: Color(0xFF8A2205),
    ),
    // D-097: solid darkened from #C77700 to meet 3:1 on `ground`.
    ApsiraFamily.amber: ApsiraFamilyColors(
      solid: Color(0xFFBA7000),
      container: Color(0xFFFFEFC7),
      onContainer: Color(0xFF6B4200),
    ),
    ApsiraFamily.blue: ApsiraFamilyColors(
      solid: Color(0xFF2F6BDB),
      container: Color(0xFFDDE8FF),
      onContainer: Color(0xFF183F8F),
    ),
    ApsiraFamily.pink: ApsiraFamilyColors(
      solid: Color(0xFFC2417A),
      container: Color(0xFFFFE0EC),
      onContainer: Color(0xFF7A1846),
    ),
    ApsiraFamily.green: ApsiraFamilyColors(
      solid: accentFill,
      container: accC,
      onContainer: onAccC,
    ),
    ApsiraFamily.neutral: ApsiraFamilyColors(
      solid: Color(0xFF6B7671),
      container: Color(0xFFECEFED),
      onContainer: Color(0xFF4A5550),
    ),
  };
}

/// UX §2.2, dark column. Dark is the default theme (D-064).
abstract final class ApsiraDarkColors {
  static const ground = Color(0xFF0A0E0C);
  static const surface = Color(0xFF18201C);
  static const border = Color(0xFF2C3833);
  static const tint = Color(0xFF232D28);
  static const panel = Color(0xFF101613);
  static const ink = Color(0xFFF1F4F2);
  static const ink2 = Color(0xFFC3CCC7);
  static const ink3 = Color(0xFF97A39D);
  static const line = Color(0xFF2A3430);
  static const lineOnTint = Color(0xFF303B36);
  static const ring = Color(0xFF6E7A74);
  static const scrim = Color.fromRGBO(0, 0, 0, 0.65);

  /// None: depth comes from the `ground` → `surface` → `tint` steps and
  /// `border` (UX §2.4).
  static const shadow = <BoxShadow>[];

  static const accentFill = Color(0xFF1FB377);
  static const onAccent = Color(0xFF06140E);
  static const accentText = Color(0xFF4CD39A);
  static const accC = Color(0xFF10352A);
  static const onAccC = Color(0xFF9DEBC6);

  static const families = {
    ApsiraFamily.redOrange: ApsiraFamilyColors(
      solid: Color(0xFFFF7A4D),
      container: Color(0xFF3B1A10),
      onContainer: Color(0xFFFFB59C),
    ),
    ApsiraFamily.amber: ApsiraFamilyColors(
      solid: Color(0xFFF5B83D),
      container: Color(0xFF3A2A0B),
      onContainer: Color(0xFFFFD98A),
    ),
    ApsiraFamily.blue: ApsiraFamilyColors(
      solid: Color(0xFF7AA2FF),
      container: Color(0xFF16264A),
      onContainer: Color(0xFFB9CDFF),
    ),
    ApsiraFamily.pink: ApsiraFamilyColors(
      solid: Color(0xFFFF7EB0),
      container: Color(0xFF3D1426),
      onContainer: Color(0xFFFFB8D2),
    ),
    ApsiraFamily.green: ApsiraFamilyColors(
      solid: accentFill,
      container: accC,
      onContainer: onAccC,
    ),
    ApsiraFamily.neutral: ApsiraFamilyColors(
      solid: Color(0xFFA9B4AE),
      container: Color(0xFF232C28),
      onContainer: Color(0xFFC3CCC7),
    ),
  };
}

/// The two fixed values of the Material mapping (`ApsiraThemeData.colorScheme`)
/// that are not tokens: RELAY wrote them inline in its theme folder; here
/// they live with the other literals.
abstract final class ApsiraSchemeColors {
  /// The dark theme's `ColorScheme.shadow`.
  static const shadowDark = Color(0xFF000000);

  /// `ColorScheme.surfaceTint`: none, depth comes from `border` (D-066).
  static const surfaceTint = Color(0x00000000);
}
