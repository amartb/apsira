// The shared component set of `ApsiraThemeData.build` (D-APK-013), light and
// dark: a TextButton and an OutlinedButton (R-10, `accentText`), an open popup
// menu and a snack with its action, so a change to the set shows in review as
// a changed golden. Regenerate with `flutter test --update-goldens
// test/goldens` and review the PNG.
import 'dart:io';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads [file] from lib/fonts as the consumer-qualified [family], so the
/// labels render in the scale's own font.
Future<void> loadFont(String family, String file) async {
  final bytes = File('lib/fonts/$file').readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

/// One theme's panel: the two buttons and a menu button, its snack shown.
class ComponentPanel extends StatelessWidget {
  const ComponentPanel(this.tokens, {super.key});

  final ApsiraTheme tokens;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ApsiraThemeData.build(tokens),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tokens.brightness.name,
              style: ApsiraTypography.cardTitle.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () {}, child: const Text('Text button')),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined button'),
            ),
            PopupMenuButton<int>(
              key: Key('menu-${tokens.brightness.name}'),
              initialValue: 1,
              itemBuilder: (_) => [
                ApsiraMenuItem(value: 0, label: 'Rename'),
                ApsiraMenuItem(value: 1, label: 'Archive', chosen: true),
                const PopupMenuDivider(),
                ApsiraMenuItem(value: 2, label: 'Delete', danger: true),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the shared component set', (tester) async {
    await tester.runAsync(
      () => loadFont(ApsiraFonts.archivoQualified, 'Archivo[wdth,wght].ttf'),
    );
    tester.view.physicalSize = const Size(760, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ComponentPanel(ApsiraTheme.light)),
            Expanded(child: ComponentPanel(ApsiraTheme.dark)),
          ],
        ),
      ),
    );
    for (final b in Brightness.values) {
      final menu = find.byKey(Key('menu-${b.name}'));
      ScaffoldMessenger.of(tester.element(menu)).showSnackBar(
        SnackBar(
          content: const Text('Note archived'),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('components.png'),
    );
  });
}
