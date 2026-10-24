// From lyceum test/support/pump_lyceum.dart @ 9f4ff27 (pumpLyceum without its
// ProviderScope and module theme, which stay in LYCEUM, and testBothModes).

/// Pumping a widget in an app's theme, language and text scale. See the
/// package README, "Pumping".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_font_scale.dart';
import 'layout_check.dart';

/// Pumps [child] inside [host]'s app for [brightness] (or [theme] when
/// given), in [locale] with [host]'s delegates, at the system font scale
/// [textScale] as Android 14 applies it (`AndroidFontScaler`), and inside a
/// [Scaffold] unless [wrapInScaffold] is false. [surfaceSize] sets the
/// test surface for this test.
///
/// A widget that needs more around it (a `ProviderScope`, an app's own
/// inherited theme) passes it as [child]'s ancestors.
Future<void> pumpApsira(
  WidgetTester tester,
  Widget child, {
  LayoutHost host = const LayoutHost(),
  Brightness brightness = Brightness.dark,
  ThemeData? theme,
  Locale? locale,
  double textScale = 1.0,
  bool wrapInScaffold = true,
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: host.localizationsDelegates,
      supportedLocales: host.supportedLocales,
      locale: locale,
      theme: theme ?? host.theme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: AndroidFontScaler(textScale)),
        child: child!,
      ),
      home: wrapInScaffold ? Scaffold(body: child) : child,
    ),
  );
}

/// Registers [body] once per brightness, named `'<description> [dark]'` and
/// `'<description> [light]'`.
void testBothModes(
  String description,
  Future<void> Function(WidgetTester tester, Brightness brightness) body,
) {
  for (final b in Brightness.values) {
    testWidgets('$description [${b.name}]', (tester) => body(tester, b));
  }
}
