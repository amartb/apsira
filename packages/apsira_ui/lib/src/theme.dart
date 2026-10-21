// From relay lib/app/theme/relay_theme.dart @ 5f606e9
import 'package:flutter/material.dart';

import 'colors.dart';
import 'shape.dart';
import 'typography.dart';

/// Apsira's design tokens (UX §2.2), as a `ThemeExtension` on `ThemeData`.
///
/// Widgets reference token names only, never raw values:
/// `ApsiraTheme.of(context).surface`. There are two token sets, [light] and
/// [dark]; dark is the default theme (D-064). Colour is an accent, not a
/// fill (D-065), and every card, tile and sheet has its `border` (D-066).
@immutable
class ApsiraTheme extends ThemeExtension<ApsiraTheme> {
  const ApsiraTheme({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.border,
    required this.tint,
    required this.panel,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.lineOnTint,
    required this.ring,
    required this.scrim,
    required this.shadow,
    required this.accentFill,
    required this.onAccent,
    required this.accentText,
    required this.accC,
    required this.onAccC,
    required this.families,
  });

  /// The light token set.
  static const light = ApsiraTheme(
    brightness: Brightness.light,
    ground: ApsiraLightColors.ground,
    surface: ApsiraLightColors.surface,
    border: ApsiraLightColors.border,
    tint: ApsiraLightColors.tint,
    panel: ApsiraLightColors.panel,
    ink: ApsiraLightColors.ink,
    ink2: ApsiraLightColors.ink2,
    ink3: ApsiraLightColors.ink3,
    line: ApsiraLightColors.line,
    lineOnTint: ApsiraLightColors.lineOnTint,
    ring: ApsiraLightColors.ring,
    scrim: ApsiraLightColors.scrim,
    shadow: ApsiraLightColors.shadow,
    accentFill: ApsiraLightColors.accentFill,
    onAccent: ApsiraLightColors.onAccent,
    accentText: ApsiraLightColors.accentText,
    accC: ApsiraLightColors.accC,
    onAccC: ApsiraLightColors.onAccC,
    families: ApsiraLightColors.families,
  );

  /// The dark token set, the default theme (D-064).
  static const dark = ApsiraTheme(
    brightness: Brightness.dark,
    ground: ApsiraDarkColors.ground,
    surface: ApsiraDarkColors.surface,
    border: ApsiraDarkColors.border,
    tint: ApsiraDarkColors.tint,
    panel: ApsiraDarkColors.panel,
    ink: ApsiraDarkColors.ink,
    ink2: ApsiraDarkColors.ink2,
    ink3: ApsiraDarkColors.ink3,
    line: ApsiraDarkColors.line,
    lineOnTint: ApsiraDarkColors.lineOnTint,
    ring: ApsiraDarkColors.ring,
    scrim: ApsiraDarkColors.scrim,
    shadow: ApsiraDarkColors.shadow,
    accentFill: ApsiraDarkColors.accentFill,
    onAccent: ApsiraDarkColors.onAccent,
    accentText: ApsiraDarkColors.accentText,
    accC: ApsiraDarkColors.accC,
    onAccC: ApsiraDarkColors.onAccC,
    families: ApsiraDarkColors.families,
  );

  /// The tokens of the ambient [Theme], which must carry a [ApsiraTheme]
  /// (every `ThemeData` built by [ApsiraThemeData] does).
  static ApsiraTheme of(BuildContext context) =>
      Theme.of(context).extension<ApsiraTheme>()!;

  final Brightness brightness;

  /// Screen background, deliberately darker than cards in both themes.
  final Color ground;

  /// Cards, sheets, floating buttons.
  final Color surface;

  /// The 1 px outline on every card, tile, sheet and floating button
  /// (D-066).
  final Color border;

  /// Insets inside cards, neutral icon tiles, secondary buttons.
  final Color tint;

  /// The drawer panel.
  final Color panel;

  /// Primary text.
  final Color ink;

  /// Secondary text, snippets.
  final Color ink2;

  /// Tertiary text, meta, field labels.
  final Color ink3;

  /// Inset dividers inside cards.
  final Color line;

  /// Inset dividers on `tint`.
  final Color lineOnTint;

  /// The unprioritised checkbox ring, dashed outlines (3:1 for UI).
  final Color ring;

  /// Behind sheets, the drawer and the capture sheet.
  final Color scrim;

  /// Card elevation; empty in dark mode (UX §2.4).
  final List<BoxShadow> shadow;

  /// FAB, primary buttons, checked boxes, the play button, active dots.
  final Color accentFill;

  /// Content on `accentFill`.
  final Color onAccent;

  /// Accent-coloured text and links; tags.
  final Color accentText;

  /// Tag chips, the "Today" chip, Done status, the active drawer item.
  final Color accC;

  /// Content on `accC`.
  final Color onAccC;

  /// The semantic families; read them with [family].
  final Map<ApsiraFamily, ApsiraFamilyColors> families;

  /// The tonal pair of [f] in this theme.
  ApsiraFamilyColors family(ApsiraFamily f) => families[f]!;

  /// Every single-colour token by its UX §2.2 name, in the spec's order
  /// (families excepted: see [families]).
  Map<String, Color> get colors => {
    'ground': ground,
    'surface': surface,
    'border': border,
    'tint': tint,
    'panel': panel,
    'ink': ink,
    'ink2': ink2,
    'ink3': ink3,
    'line': line,
    'lineOnTint': lineOnTint,
    'ring': ring,
    'scrim': scrim,
    'accentFill': accentFill,
    'onAccent': onAccent,
    'accentText': accentText,
    'accC': accC,
    'onAccC': onAccC,
  };

  @override
  ApsiraTheme copyWith({
    Brightness? brightness,
    Color? ground,
    Color? surface,
    Color? border,
    Color? tint,
    Color? panel,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? lineOnTint,
    Color? ring,
    Color? scrim,
    List<BoxShadow>? shadow,
    Color? accentFill,
    Color? onAccent,
    Color? accentText,
    Color? accC,
    Color? onAccC,
    Map<ApsiraFamily, ApsiraFamilyColors>? families,
  }) => ApsiraTheme(
    brightness: brightness ?? this.brightness,
    ground: ground ?? this.ground,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    tint: tint ?? this.tint,
    panel: panel ?? this.panel,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    line: line ?? this.line,
    lineOnTint: lineOnTint ?? this.lineOnTint,
    ring: ring ?? this.ring,
    scrim: scrim ?? this.scrim,
    shadow: shadow ?? this.shadow,
    accentFill: accentFill ?? this.accentFill,
    onAccent: onAccent ?? this.onAccent,
    accentText: accentText ?? this.accentText,
    accC: accC ?? this.accC,
    onAccC: onAccC ?? this.onAccC,
    families: families ?? this.families,
  );

  @override
  ApsiraTheme lerp(covariant ThemeExtension<ApsiraTheme>? other, double t) {
    if (other is! ApsiraTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ApsiraTheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      ground: c(ground, other.ground),
      surface: c(surface, other.surface),
      border: c(border, other.border),
      tint: c(tint, other.tint),
      panel: c(panel, other.panel),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      line: c(line, other.line),
      lineOnTint: c(lineOnTint, other.lineOnTint),
      ring: c(ring, other.ring),
      scrim: c(scrim, other.scrim),
      // Exact at the ends: lerpList would leave zero-sized shadows behind
      // when one side has none (dark).
      shadow: switch (t) {
        0.0 => shadow,
        1.0 => other.shadow,
        _ => BoxShadow.lerpList(shadow, other.shadow, t) ?? const [],
      },
      accentFill: c(accentFill, other.accentFill),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      accC: c(accC, other.accC),
      onAccC: c(onAccC, other.onAccC),
      families: {
        for (final f in ApsiraFamily.values)
          f: ApsiraFamilyColors.lerp(family(f), other.family(f), t),
      },
    );
  }
}

/// The light and dark `ThemeData`, built from the [ApsiraTheme] tokens.
abstract final class ApsiraThemeData {
  static final ThemeData light = build(ApsiraTheme.light);
  static final ThemeData dark = build(ApsiraTheme.dark);

  /// `ThemeData` for one token set, with the tokens attached as an
  /// extension and the UX §2.3 scale as the text theme (normal-width
  /// Archivo by default, D-055).
  ///
  /// [extensions] are an app's own `ThemeExtension`s, attached after the
  /// tokens. The default family is the package-qualified name
  /// ([ApsiraFonts.archivoQualified]), which is how a consumer's bundle
  /// declares it.
  static ThemeData build(
    ApsiraTheme tokens, {
    List<ThemeExtension<dynamic>> extensions = const [],
  }) => ThemeData(
    colorScheme: colorScheme(tokens),
    fontFamily: ApsiraFonts.archivoQualified,
    textTheme: ApsiraTypography.textTheme,
    scaffoldBackgroundColor: tokens.ground,
    dividerColor: tokens.line,
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tokens.surface,
      shape: dialogShape(tokens),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: tokens.surface,
      shape: dialogShape(tokens),
    ),
    extensions: [tokens, ...extensions],
  );

  /// A dialog's surface edge: the group-card radius with its 1 px
  /// `border` (D-066). The Material date and time pickers take it from
  /// the theme, since their callers draw no surface of their own.
  static RoundedRectangleBorder dialogShape(ApsiraTheme t) =>
      ApsiraShapes.rounded(ApsiraRadii.groupCard)
          .copyWith(side: BorderSide(color: t.border));

  /// The explicit Material 3 mapping of the tokens (UX §2.2 "In code").
  ///
  /// Every role is set, so no Material default or seed-generated colour
  /// reaches the screen. Cards and sheets are `surface` at every container
  /// level; `surfaceTint` is transparent because depth comes from `border`
  /// and the tonal steps, not from an elevation tint (D-066).
  static ColorScheme colorScheme(ApsiraTheme t) {
    final isLight = t.brightness == Brightness.light;
    final red = t.family(ApsiraFamily.redOrange);
    final blue = t.family(ApsiraFamily.blue);
    // Content on a family solid: white in light, the ground in dark.
    final onSolid = isLight ? t.surface : t.ground;
    final opposite = isLight ? ApsiraTheme.dark : ApsiraTheme.light;
    return ColorScheme(
      brightness: t.brightness,
      primary: t.accentFill,
      onPrimary: t.onAccent,
      primaryContainer: t.accC,
      onPrimaryContainer: t.onAccC,
      secondary: t.accentText,
      onSecondary: t.onAccent,
      secondaryContainer: t.accC,
      onSecondaryContainer: t.onAccC,
      tertiary: blue.solid,
      onTertiary: onSolid,
      tertiaryContainer: blue.container,
      onTertiaryContainer: blue.onContainer,
      error: red.solid,
      onError: onSolid,
      errorContainer: red.container,
      onErrorContainer: red.onContainer,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      surfaceDim: t.ground,
      surfaceBright: t.surface,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surface,
      surfaceContainerHighest: t.tint,
      outline: t.ring,
      outlineVariant: t.border,
      shadow: isLight ? t.ink : ApsiraSchemeColors.shadowDark,
      scrim: t.scrim,
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
      inversePrimary: opposite.accentText,
      surfaceTint: ApsiraSchemeColors.surfaceTint,
    );
  }
}
