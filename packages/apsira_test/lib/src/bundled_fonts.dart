// From lyceum test/support/layout/bundled_fonts.dart @ 9f4ff27 (itself
// viaticum test/support/layout/bundled_fonts.dart @ 78d38e0's, which loads each
// file once per family), with relay test/support/golden/relay_golden.dart
// @ 09b28810's once-per-isolate future (loadRelayFonts, as loadAppFonts).

/// Loads the bundled fonts into the test engine, so tests lay text out in the
/// app's own families, as the phone does, not in the test font (whose every
/// glyph is one em wide). The bundle's font manifest names apsira_ui's
/// families (`packages/apsira_ui/Archivo`, …) and every family the app adds.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>>? _fonts;
bool _loaded = false;

/// Loads every family of the bundle once per test isolate, inside a
/// `testWidgets` body: every test file runs in its own isolate, so only the
/// files that call it change font.
Future<void> loadBundledFontsOnce(WidgetTester tester) async {
  if (_loaded) return;
  await tester.runAsync(loadAppFonts);
  _loaded = true;
}

/// Loads every family of the bundle once per test isolate and returns the
/// families loaded; later calls return the same future. Call it outside the
/// fake-async zone of `testWidgets`: in `setUpAll`, or in
/// `flutter_test_config.dart`.
Future<Set<String>> loadAppFonts() => _fonts ??= loadBundledFonts();

/// Loads every family of the asset bundle's `FontManifest.json` (the
/// `pubspec.yaml` fonts, packages' fonts and Material's icon font) and
/// returns the family names, as the bundle names them
/// (`packages/apsira_ui/Archivo`).
Future<Set<String>> loadBundledFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  final families = (jsonDecode(manifest) as List<Object?>)
      .cast<Map<String, Object?>>();
  final loaded = <String>{};
  for (final family in families) {
    final name = family['family']! as String;
    final loader = FontLoader(name);
    // One file may be declared at several weights (a variable font); load
    // it once.
    final assets = {
      for (final font
          in (family['fonts']! as List<Object?>).cast<Map<String, Object?>>())
        font['asset']! as String,
    };
    for (final asset in assets) {
      // The manifest URL-encodes asset paths ("Archivo%5Bwdth,wght%5D.ttf").
      loader.addFont(rootBundle.load(Uri.decodeFull(asset)));
    }
    await loader.load();
    loaded.add(name);
  }
  return loaded;
}
