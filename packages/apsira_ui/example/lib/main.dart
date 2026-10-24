// A minimal consumer of apsira_ui: the per-app theme, the lockup, the
// licences and the ThemePreview, as an Apsira app wires them.
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:apsira_ui/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  ApsiraBrand.registerLicences();
  runApp(const ExampleApp());
}

/// The example app: the dark theme (the default) or the light one.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, this.themeMode = ThemeMode.dark});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_ui example',
    theme: ApsiraThemeData.light,
    darkTheme: ApsiraThemeData.dark,
    themeMode: themeMode,
    localizationsDelegates: const [
      ApsiraL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: ApsiraL10n.supportedLocales,
    home: const ExampleHome(),
  );
}

/// The lockup above a display title, a row of chrome glyphs, and the
/// buttons to the licences and the ThemePreview.
class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(ApsiraSpacing.largeTitleGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Image(image: ApsiraBrand.lockupReversed, width: 200),
            const SizedBox(height: ApsiraSpacing.betweenSections),
            Text('Apsira', style: Theme.of(context).textTheme.displaySmall),
            Text('Body text in Archivo.', style: TextStyle(color: t.ink2)),
            const Row(
              children: [
                Icon(ApsiraIcons.back),
                Icon(ApsiraIcons.plus),
                Icon(ApsiraIcons.verified),
              ],
            ),
            TextButton(
              onPressed: () => showLicensePage(context: context),
              child: const Text('Licences'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ThemePreviewScreen(),
                ),
              ),
              child: const Text('ThemePreview'),
            ),
          ],
        ),
      ),
    );
  }
}
