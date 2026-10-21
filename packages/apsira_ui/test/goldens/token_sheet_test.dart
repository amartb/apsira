// The token sheet: every light and dark colour token as a labelled swatch, so
// a value change shows in review as a changed golden (a token change is
// breaking, D-APK-003). Regenerate with
// `flutter test --update-goldens test/goldens` and review the PNG.
import 'dart:io';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `#AARRGGBB` of [c].
String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Every colour of [t] by name: the single tokens, then each family's pair.
Map<String, Color> swatches(ApsiraTheme t) => {
  ...t.colors,
  for (final f in ApsiraFamily.values) ...{
    '${f.name}.solid': t.family(f).solid,
    '${f.name}.container': t.family(f).container,
    '${f.name}.onContainer': t.family(f).onContainer,
  },
};

/// One theme's column of swatches, on its own ground.
class TokenColumn extends StatelessWidget {
  const TokenColumn(this.tokens, {super.key});

  final ApsiraTheme tokens;

  @override
  Widget build(BuildContext context) {
    final label = ApsiraTypography.meta.copyWith(color: tokens.ink);
    return ColoredBox(
      color: tokens.ground,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tokens.brightness.name,
              style: ApsiraTypography.cardTitle.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 8),
            for (final MapEntry(key: name, value: color) in swatches(
              tokens,
            ).entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: tokens.border),
                      ),
                      child: const SizedBox(width: 40, height: 20),
                    ),
                    const SizedBox(width: 8),
                    Text('$name  ${hex(color)}', style: label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Loads [file] from lib/fonts as the consumer-qualified [family], so the
/// labels render in the scale's own font.
Future<void> loadFont(String family, String file) async {
  final bytes = File('lib/fonts/$file').readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

void main() {
  testWidgets('the token sheet', (tester) async {
    await tester.runAsync(
      () => loadFont(ApsiraFonts.archivoQualified, 'Archivo[wdth,wght].ttf'),
    );
    tester.view.physicalSize = const Size(760, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: TokenColumn(ApsiraTheme.light)),
            Expanded(child: TokenColumn(ApsiraTheme.dark)),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('token_sheet.png'),
    );
  });
}
