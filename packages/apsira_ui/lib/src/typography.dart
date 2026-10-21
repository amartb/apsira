// From relay lib/app/theme/relay_typography.dart @ 5f606e9
import 'package:flutter/material.dart';

/// The font family names declared in `pubspec.yaml`.
///
/// The bare names are what the package declares; a consumer's bundle holds
/// them under `packages/apsira_ui/`, the qualified names. Every
/// [ApsiraTypeStyle] passes [package] to its `TextStyle`, which qualifies
/// the family, and `ApsiraThemeData` defaults to [archivoQualified].
abstract final class ApsiraFonts {
  /// The package that bundles the fonts.
  static const package = 'apsira_ui';

  /// Archivo Expanded (`wdth 125`), 400 and 600, from `apsira-brand/06-fonts`:
  /// large titles, numerals and the wordmark only (D-055).
  static const archivoExpanded = 'ArchivoExpanded';

  /// Normal-width Archivo, for everything else (D-055): one variable file
  /// (`wdth`, `wght`) from google/fonts. Its default instance is `wght` 600,
  /// so every style sets its weight and width through `fontVariations`.
  static const archivo = 'Archivo';

  /// The `wdth` axis value of normal-width Archivo.
  static const normalWidth = 100.0;

  /// JetBrains Mono, variable (`wght`), from google/fonts: the monospace
  /// query field of the saved-view builder (UX §8.1).
  static const mono = 'JetBrainsMono';

  /// [archivoExpanded] as a consumer's bundle names it.
  static const archivoExpandedQualified = 'packages/$package/$archivoExpanded';

  /// [archivo] as a consumer's bundle names it.
  static const archivoQualified = 'packages/$package/$archivo';

  /// [mono] as a consumer's bundle names it.
  static const monoQualified = 'packages/$package/$mono';
}

/// The UX §2.3 type scale. Each style carries its documented ranges; [style]
/// is the base (the lower bound of every range, except [display], whose base
/// is the 34 px screen title) and [at] builds any value inside the ranges.
///
/// Archivo Expanded is never used below 20 px except for [numeral] and
/// [wordmark] (D-055); [at] refuses any value outside a style's range, so no
/// widget can build a smaller one. Styles carry no colour: widgets take it
/// from the `ApsiraTheme` tokens (`ink`, `ink2`, `ink3`, …).
enum ApsiraTypeStyle {
  /// Screen large titles (Friday, Tasks) at 34; list titles (Meeting) at 32,
  /// in the same 40 px line box.
  display(ApsiraFonts.archivoExpanded, (32, 34), (40, 40), (600, 600)),

  /// Stat tiles, the recorder timer, date pills. Tabular figures.
  numeral(
    ApsiraFonts.archivoExpanded,
    (28, 68),
    null,
    (500, 600),
    tabular: true,
  ),

  /// The wordmark (RELAY's in its drawer and intro), tracked +0.10–0.14 em.
  wordmark(
    ApsiraFonts.archivoExpanded,
    (20, 40),
    null,
    (600, 600),
    trackingEm: (0.10, 0.14),
  ),

  /// Tutorial titles.
  slideTitle(ApsiraFonts.archivoExpanded, (28, 28), (34, 34), (600, 600)),

  /// The title in the editor.
  noteTitle(
    ApsiraFonts.archivo,
    (30, 30),
    (36, 36),
    (700, 700),
    trackingEm: (-0.01, -0.01),
  ),

  /// Card headers (Today, Recent, Overdue).
  cardTitle(ApsiraFonts.archivo, (18, 18), (24, 24), (700, 700)),

  /// Body headings.
  h2(ApsiraFonts.archivo, (21, 21), (28, 28), (700, 700)),

  /// Body sub-headings (UX §2.3, in the `h2` row).
  h3(ApsiraFonts.archivo, (18, 18), (24, 24), (700, 700)),

  /// Note and task titles in rows.
  rowTitle(ApsiraFonts.archivo, (16, 17), (22, 23), (600, 700)),

  /// Editor body, slide copy (`ink2`).
  body(ApsiraFonts.archivo, (16, 16), (25, 25), (400, 400)),

  /// Previews: up to 2 lines in lists, 1 on Home.
  snippet(ApsiraFonts.archivo, (14, 14), (20, 21), (400, 400)),

  /// Every chip and pill.
  pill(ApsiraFonts.archivo, (12.5, 13), (16, 16), (600, 700)),

  /// Times, sources, counts (`ink3`).
  meta(ApsiraFonts.archivo, (13, 13), (18, 18), (500, 600));

  const ApsiraTypeStyle(
    this.family,
    this.size,
    this.line,
    this.weight, {
    this.trackingEm = (0, 0),
    this.tabular = false,
  });

  /// The font family name ([ApsiraFonts]), bare; the built `TextStyle`
  /// carries it package-qualified.
  final String family;

  /// Font size range in logical pixels, (min, max).
  final (double, double) size;

  /// Line height range in logical pixels, or null where UX §2.3 leaves it
  /// to the font (numerals, the wordmark).
  final (double, double)? line;

  /// Weight range, (min, max), in CSS units (400, 500, …).
  final (int, int) weight;

  /// Letter-spacing range in em of the font size.
  final (double, double) trackingEm;

  /// Whether figures are tabular (numerals line up).
  final bool tabular;

  /// The base style.
  TextStyle get style => at();

  /// This style at [size], [weight], [lineHeight] (logical pixels) and
  /// [trackingEm], each defaulting to the base and checked against the
  /// documented range. Inside a ranged row the line height follows the size
  /// (rowTitle 16 / 22 → 17 / 23) unless given.
  ///
  /// Throws [ArgumentError] for any value outside its range.
  TextStyle at({
    double? size,
    FontWeight? weight,
    double? lineHeight,
    double? trackingEm,
  }) {
    final px = size ?? (this == display ? this.size.$2 : this.size.$1);
    _check('size', px, this.size);
    final w = weight?.value ?? this.weight.$1;
    _check('weight', w.toDouble(), (
      this.weight.$1.toDouble(),
      this.weight.$2.toDouble(),
    ));
    final em = trackingEm ?? this.trackingEm.$1;
    _check('trackingEm', em, this.trackingEm);
    final range = line;
    double? lh;
    if (range == null) {
      if (lineHeight != null) {
        throw ArgumentError.value(lineHeight, 'lineHeight', '$name has none');
      }
    } else {
      lh =
          lineHeight ??
          (range.$1 + (px - this.size.$1)).clamp(range.$1, range.$2);
      _check('lineHeight', lh, range);
    }
    return TextStyle(
      fontFamily: family,
      package: ApsiraFonts.package,
      fontSize: px,
      height: lh == null ? null : lh / px,
      fontWeight: FontWeight.values[w ~/ 100 - 1],
      letterSpacing: em * px,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      // The Expanded cuts are static; normal-width Archivo is variable and
      // takes its weight from the axis, not from a separate file.
      fontVariations: family == ApsiraFonts.archivo
          ? [
              FontVariation.weight(w.toDouble()),
              const FontVariation.width(ApsiraFonts.normalWidth),
            ]
          : null,
    );
  }

  void _check(String what, double v, (double, double) r) {
    if (v < r.$1 || v > r.$2) {
      throw ArgumentError.value(v, what, '$name allows ${r.$1}–${r.$2}');
    }
  }
}

/// The base styles by name, and their Material [TextTheme] mapping.
abstract final class ApsiraTypography {
  static TextStyle get display => ApsiraTypeStyle.display.style;

  /// `display` at 32 px: list titles (Meeting).
  static TextStyle get listTitle => ApsiraTypeStyle.display.at(size: 32);
  static TextStyle get numeral => ApsiraTypeStyle.numeral.style;
  static TextStyle get wordmark => ApsiraTypeStyle.wordmark.style;
  static TextStyle get slideTitle => ApsiraTypeStyle.slideTitle.style;
  static TextStyle get noteTitle => ApsiraTypeStyle.noteTitle.style;
  static TextStyle get cardTitle => ApsiraTypeStyle.cardTitle.style;
  static TextStyle get h2 => ApsiraTypeStyle.h2.style;
  static TextStyle get h3 => ApsiraTypeStyle.h3.style;
  static TextStyle get rowTitle => ApsiraTypeStyle.rowTitle.style;
  static TextStyle get body => ApsiraTypeStyle.body.style;
  static TextStyle get snippet => ApsiraTypeStyle.snippet.style;
  static TextStyle get pill => ApsiraTypeStyle.pill.style;
  static TextStyle get meta => ApsiraTypeStyle.meta.style;

  /// The scale on Material's roles, so stock widgets (buttons, chips, list
  /// tiles, text fields) speak it too. Colours are left to `ThemeData`,
  /// which takes them from the `ColorScheme` (`onSurface` = `ink`).
  static TextTheme get textTheme => TextTheme(
    displaySmall: display,
    headlineMedium: slideTitle,
    headlineSmall: h2,
    titleLarge: cardTitle,
    titleMedium: rowTitle,
    titleSmall: h3,
    bodyLarge: body,
    bodyMedium: snippet,
    bodySmall: meta,
    labelLarge: pill,
    labelMedium: meta,
  );
}
