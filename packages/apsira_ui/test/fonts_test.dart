// From relay test/app/theme/relay_fonts_test.dart @ 5f606e9
// The fonts are bundled: each family is declared under the name the
// typography uses, every file loads from the asset bundle as a font, and each
// OFL licence travels with its font. Seen from the package's own tests the
// families and assets are unqualified; a consumer sees them under
// packages/apsira_ui/ (example/test/consumer_assets_test.dart).
import 'dart:convert';
import 'dart:math';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundle's font manifest: family name → its (asset path, weight)
/// entries, paths decoded (the manifest stores `[` as `%5B`). One file may be
/// declared at several weights.
Future<Map<String, Set<(String, int)>>> fontManifest() async {
  final raw = await rootBundle.loadString('FontManifest.json');
  final families = (jsonDecode(raw) as List<Object?>)
      .cast<Map<String, Object?>>();
  return {
    for (final f in families)
      f['family']! as String: {
        for (final font
            in (f['fonts']! as List<Object?>).cast<Map<String, Object?>>())
          (
            Uri.decodeFull(font['asset']! as String),
            (font['weight'] as int?) ?? 400,
          ),
      },
  };
}

/// The variation axes of the TrueType font in [data]: tag → (min, default,
/// max), read from its `fvar` table; empty for a static font.
Map<String, (double, double, double)> axes(ByteData data) {
  final tables = data.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes([
      for (var b = 0; b < 4; b++) data.getUint8(rec + b),
    ]);
    if (tag != 'fvar') continue;
    final fvar = data.getUint32(rec + 8);
    final first = fvar + data.getUint16(fvar + 4);
    final size = data.getUint16(fvar + 10);
    double fixed(int at) => data.getInt32(at) / 65536;
    return {
      for (var a = 0; a < data.getUint16(fvar + 8); a++)
        String.fromCharCodes([
          for (var b = 0; b < 4; b++) data.getUint8(first + a * size + b),
        ]): (
          fixed(first + a * size + 4),
          fixed(first + a * size + 8),
          fixed(first + a * size + 12),
        ),
    };
  }
  return {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Archivo Expanded 400 and 600 are declared under the style name', () {
    return fontManifest().then((manifest) {
      expect(manifest[ApsiraFonts.archivoExpanded], {
        ('lib/fonts/ArchivoExpanded-400.ttf', 400),
        ('lib/fonts/ArchivoExpanded-600.ttf', 600),
      });
    });
  });

  test('both cuts load from the bundle and register as fonts', () async {
    final loader = FontLoader(ApsiraFonts.archivoExpanded);
    for (final cut in ['400', '600']) {
      final data = await rootBundle.load('lib/fonts/ArchivoExpanded-$cut.ttf');
      // TrueType outlines (sfnt version 1.0).
      expect(data.getUint32(0), 0x00010000, reason: cut);
      loader.addFont(Future.value(data));
    }
    await loader.load();
  });

  test('the OFL licence is bundled beside the fonts', () async {
    final licence = await rootBundle.loadString(
      'lib/fonts/LICENSE-Archivo.txt',
    );
    expect(licence, contains('SIL OPEN FONT LICENSE'));
  });

  group('normal-width Archivo (D-055)', () {
    const file = 'lib/fonts/Archivo[wdth,wght].ttf';

    test('one variable file, declared at every weight of the scale', () async {
      // The same file under each weight the scale uses, so the font matcher
      // always finds an exact weight and never synthesises bold over the
      // `wght` axis the styles set.
      final manifest = await fontManifest();
      final weights = {
        for (final s in ApsiraTypeStyle.values)
          if (s.family == ApsiraFonts.archivo)
            for (var w = s.weight.$1; w <= s.weight.$2; w += 100) w,
      };
      expect(manifest[ApsiraFonts.archivo], {
        for (final w in weights) (file, w),
      });
    });

    test('it loads and its axes cover the scale at normal width', () async {
      final data = await rootBundle.load(file);
      expect(data.getUint32(0), 0x00010000);
      final a = axes(data);
      final weights = [
        for (final s in ApsiraTypeStyle.values)
          if (s.family == ApsiraFonts.archivo) ...[s.weight.$1, s.weight.$2],
      ];
      expect(a['wght']!.$1, lessThanOrEqualTo(weights.reduce(min)));
      expect(a['wght']!.$3, greaterThanOrEqualTo(weights.reduce(max)));
      expect(a['wdth']!.$1, lessThanOrEqualTo(ApsiraFonts.normalWidth));
      expect(a['wdth']!.$3, greaterThanOrEqualTo(ApsiraFonts.normalWidth));
      await (FontLoader(
        ApsiraFonts.archivo,
      )..addFont(Future.value(data))).load();
    });

    test('its OFL licence is bundled', () async {
      final licence = await rootBundle.loadString('lib/fonts/OFL-Archivo.txt');
      expect(licence, contains('SIL Open Font License, Version 1.1'));
      expect(licence, contains('Archivo Project Authors'));
    });
  });

  group('JetBrains Mono (UX §8.1 query field)', () {
    const file = 'lib/fonts/JetBrainsMono[wght].ttf';

    test('the variable file is declared under the mono name', () async {
      final manifest = await fontManifest();
      expect(manifest[ApsiraFonts.mono], {(file, 400)});
    });

    test('it loads and is variable in weight', () async {
      final data = await rootBundle.load(file);
      expect(data.getUint32(0), 0x00010000);
      final wght = axes(data)['wght']!;
      expect(wght.$1, lessThanOrEqualTo(400));
      expect(wght.$3, greaterThanOrEqualTo(700));
      await (FontLoader(ApsiraFonts.mono)..addFont(Future.value(data))).load();
    });

    test('its OFL licence is bundled', () async {
      final licence = await rootBundle.loadString(
        'lib/fonts/OFL-JetBrainsMono.txt',
      );
      expect(licence, contains('SIL Open Font License, Version 1.1'));
      expect(licence, contains('JetBrains Mono Project Authors'));
    });
  });
}
