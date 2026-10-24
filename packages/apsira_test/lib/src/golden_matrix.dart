// From lyceum test/support/golden/lyceum_golden.dart @ 9f4ff27 (GoldenVariant,
// goldenApp with Android 14 scaling, pumpGolden, withShadows) and relay
// test/support/golden/relay_golden.dart @ 09b28810 (goldenMatrix), with
// viaticum test/support/golden/viaticum_golden.dart @ 78d38e0's room variant
// as a theme name.

/// The golden setup: the EN/ES × dark/light × 100 %/200 % matrix, the app a
/// golden body renders in, and [goldenMatrix], which registers one golden
/// test per variant. See the package README, "Goldens".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_font_scale.dart';
import 'bundled_fonts.dart';
import 'layout_check.dart';

/// One cell of the golden matrix: a language, a theme and a text scale.
@immutable
class GoldenVariant {
  const GoldenVariant(
    this.locale,
    this.brightness,
    this.textScale, {
    this.themeName,
  });

  final Locale locale;
  final Brightness brightness;

  /// The system font scale: 1.0 (100 %) or 2.0 (200 %).
  final double textScale;

  /// The theme's name in [name] when it is not the brightness's
  /// (VIATICUM's `room`, a dark theme).
  final String? themeName;

  /// `en.dark.100`: language, theme, text scale in per cent.
  String get name =>
      '${locale.languageCode}.${themeName ?? brightness.name}.'
      '${(textScale * 100).round()}';

  /// The golden file of [screen] in this variant, relative to the test file.
  String goldenFile(String screen) => 'goldens/$screen.$name.png';

  @override
  bool operator ==(Object other) =>
      other is GoldenVariant &&
      other.locale == locale &&
      other.brightness == brightness &&
      other.textScale == textScale &&
      other.themeName == themeName;

  @override
  int get hashCode => Object.hash(locale, brightness, textScale, themeName);

  @override
  String toString() => name;
}

/// The languages, themes and text scales of the matrix.
const List<Locale> goldenLocales = [Locale('en'), Locale('es')];
const List<Brightness> goldenBrightnesses = [Brightness.dark, Brightness.light];
const List<double> goldenScales = [1.0, 2.0];

/// The variants of a matrix: every language × theme × scale, in that order.
/// [themeName] names a theme apart from its brightness.
List<GoldenVariant> goldenVariantsOf({
  List<Locale> locales = goldenLocales,
  List<Brightness> brightnesses = goldenBrightnesses,
  List<double> scales = goldenScales,
  String Function(Brightness brightness)? themeName,
}) => List.unmodifiable([
  for (final locale in locales)
    for (final brightness in brightnesses)
      for (final scale in scales)
        GoldenVariant(
          locale,
          brightness,
          scale,
          themeName: themeName?.call(brightness),
        ),
]);

/// The 8 variants every key screen is golden-tested in.
final List<GoldenVariant> goldenVariants = goldenVariantsOf();

/// The logical screen of a golden: a 412 × 915 dp phone, rendered at 1.0
/// device pixel ratio to keep the files small.
const Size goldenScreen = Size(412, 915);

/// [body] as the home of the app's `MaterialApp` configuration for
/// [variant]: [host]'s theme for its brightness, its locale with [host]'s
/// delegates, and its text scale through [scaler] (Android 14's non-linear
/// tables by default; RELAY's goldens pass `TextScaler.linear`).
Widget goldenApp(
  GoldenVariant variant,
  Widget body, {
  LayoutHost host = const LayoutHost(),
  TextScaler Function(double scale) scaler = androidFontScale,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: host.theme(variant.brightness),
  locale: variant.locale,
  localizationsDelegates: host.localizationsDelegates,
  supportedLocales: host.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: scaler(variant.textScale)),
    child: child!,
  ),
  home: body,
);

/// Pumps [body] in [variant] on a [size] phone and lets it settle.
Future<void> pumpGolden(
  WidgetTester tester,
  GoldenVariant variant,
  Widget body, {
  LayoutHost host = const LayoutHost(),
  TextScaler Function(double scale) scaler = androidFontScale,
  Size size = goldenScreen,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(goldenApp(variant, body, host: host, scaler: scaler));
  await tester.pumpAndSettle();
}

/// Registers one golden test of [screen] per variant of the matrix, each
/// comparing [build]'s widget for that variant against its own file in
/// `goldens/` beside the test, and loads the bundled fonts first.
void goldenMatrix(
  String screen,
  Widget Function(GoldenVariant variant) build, {
  required LayoutHost host,
  List<Locale> locales = goldenLocales,
  List<Brightness> brightnesses = goldenBrightnesses,
  List<double> scales = goldenScales,
  String Function(Brightness brightness)? themeName,
  TextScaler Function(double scale) scaler = androidFontScale,
  Size size = goldenScreen,
}) {
  setUpAll(loadAppFonts);
  final variants = goldenVariantsOf(
    locales: locales,
    brightnesses: brightnesses,
    scales: scales,
    themeName: themeName,
  );
  for (final variant in variants) {
    testWidgets('$screen golden · $variant', (tester) async {
      await pumpGolden(
        tester,
        variant,
        build(variant),
        host: host,
        scaler: scaler,
        size: size,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(variant.goldenFile(screen)),
      );
    });
  }
}

/// Runs [body] with real elevation shadows, restoring the test default
/// after it, even when it throws.
///
/// The test binding replaces shadows with a solid black outline
/// (`debugDisableShadows`) so goldens agree across platforms; goldens
/// rendered on one host only, with the pinned Flutter, may show the shadows
/// the phone draws. Pump and compare inside [body]: the binding checks the
/// default is back when the test ends.
Future<T> withShadows<T>(Future<T> Function() body) async {
  final previous = debugDisableShadows;
  debugDisableShadows = false;
  try {
    return await body();
  } finally {
    debugDisableShadows = previous;
  }
}
