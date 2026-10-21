// The consumer proof (plan P-6, R-5): in an app that depends on apsira_ui,
// the package's fonts, licences and lockup are in the bundle under
// packages/apsira_ui/, the qualified font families load, and
// ApsiraBrand.registerLicences lists the four licences. The package's own
// tests cannot see these keys: its bundle holds them unqualified.
import 'dart:convert';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundle's font manifest: family → its asset paths, decoded (the
/// manifest stores `[` as `%5B`).
Future<Map<String, Set<String>>> fontManifest() async {
  final raw = await rootBundle.loadString('FontManifest.json');
  final families = (jsonDecode(raw) as List<Object?>)
      .cast<Map<String, Object?>>();
  return {
    for (final f in families)
      f['family']! as String: {
        for (final font
            in (f['fonts']! as List<Object?>).cast<Map<String, Object?>>())
          Uri.decodeFull(font['asset']! as String),
      },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(LicenseRegistry.reset);

  test('(a) the three families are declared package-qualified', () async {
    final manifest = await fontManifest();
    const fonts = 'packages/apsira_ui/lib/fonts';
    expect(manifest[ApsiraFonts.archivoExpandedQualified], {
      '$fonts/ArchivoExpanded-400.ttf',
      '$fonts/ArchivoExpanded-600.ttf',
    });
    expect(manifest[ApsiraFonts.archivoQualified], {
      '$fonts/Archivo[wdth,wght].ttf',
    });
    expect(manifest[ApsiraFonts.monoQualified], {
      '$fonts/JetBrainsMono[wght].ttf',
    });
    expect(manifest['packages/apsira_ui/ArchivoExpanded'], isNotNull);
    expect(manifest['packages/apsira_ui/Archivo'], isNotNull);
    expect(manifest['packages/apsira_ui/JetBrainsMono'], isNotNull);
  });

  test('(b) every licence and the lockup load from the bundle', () async {
    for (final key in ApsiraBrand.licenceAssets.keys) {
      final data = await rootBundle.load(key);
      expect(data.lengthInBytes, greaterThan(0), reason: key);
    }
    const lockup =
        'packages/apsira_ui/lib/brand/apsira-labs-horizontal-reversed-1600w.png';
    expect(ApsiraBrand.lockupReversed.keyName, lockup);
    final png = await rootBundle.load(lockup);
    expect(png.getUint32(0), 0x89504E47); // \x89PNG
  });

  test('(c) registerLicences lists the four licences', () async {
    ApsiraBrand.registerLicences();
    final names = <String>{
      await for (final entry in LicenseRegistry.licenses) ...entry.packages,
    };
    expect(names, {'Archivo Expanded', 'Archivo', 'JetBrains Mono', 'Lucide'});
  });

  test(
    '(d) both Archivo Expanded cuts load under the qualified family',
    () async {
      final loader = FontLoader('packages/apsira_ui/ArchivoExpanded');
      for (final cut in ['400', '600']) {
        final data = await rootBundle.load(
          'packages/apsira_ui/lib/fonts/ArchivoExpanded-$cut.ttf',
        );
        // TrueType outlines (sfnt version 1.0).
        expect(data.getUint32(0), 0x00010000, reason: cut);
        loader.addFont(Future.value(data));
      }
      await loader.load();
    },
  );
}
