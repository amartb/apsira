// From lyceum test/screens/settings/about_page_test.dart @ 9f4ff27: the
// name, the version, the licences, and the Apsira Labs credit with the
// reversed lockup on the dark ground in both themes, never recoloured.
// Every string is the app's (a parameter), so the page renders in English
// and Spanish.
import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Strings = ({
  String title,
  String versionLabel,
  String licencesLabel,
  String developedByLabel,
  String apsiraLabsLabel,
  String tagline,
  String privacy,
});

const Map<String, _Strings> _strings = {
  'en': (
    title: 'About',
    versionLabel: 'Version',
    licencesLabel: 'Open-source licences',
    developedByLabel: 'Developed by',
    apsiraLabsLabel: 'Apsira Labs',
    tagline: 'Your writing, on your phone.',
    privacy: 'Privacy',
  ),
  'es': (
    title: 'Acerca de',
    versionLabel: 'Versión',
    licencesLabel: 'Licencias de código abierto',
    developedByLabel: 'Desarrollado por',
    apsiraLabsLabel: 'Apsira Labs',
    tagline: 'Tu escritura, en tu teléfono.',
    privacy: 'Privacidad',
  ),
};

Future<void> _pump(
  WidgetTester tester,
  String lang, {
  Brightness brightness = Brightness.dark,
}) async {
  final s = _strings[lang]!;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('es')],
      theme: ApsiraThemeData.build(
        brightness == Brightness.dark ? ApsiraTheme.dark : ApsiraTheme.light,
      ),
      home: AboutPage(
        title: s.title,
        appName: 'LYCEUM',
        version: '1.0.1',
        versionLabel: s.versionLabel,
        licencesLabel: s.licencesLabel,
        developedByLabel: s.developedByLabel,
        apsiraLabsLabel: s.apsiraLabsLabel,
        tagline: s.tagline,
        mark: const SizedBox(key: Key('mark'), width: 48, height: 48),
        rows: [ListTile(title: Text(s.privacy))],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final lang in ['en', 'es']) {
    testWidgets('About shows the app\'s strings in $lang', (tester) async {
      final s = _strings[lang]!;
      await _pump(tester, lang);

      expect(find.text(s.title), findsWidgets);
      final brand = find.byKey(const Key('about/brand'));
      for (final text in ['LYCEUM', s.tagline]) {
        expect(
          find.descendant(of: brand, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(of: brand, matching: find.byKey(const Key('mark'))),
        findsOneWidget,
      );
      expect(find.text(s.versionLabel), findsOneWidget);
      expect(find.text('1.0.1'), findsOneWidget);
      expect(find.text(s.privacy), findsOneWidget);
      expect(find.text(s.licencesLabel), findsOneWidget);
      expect(find.text(s.developedByLabel), findsOneWidget);
      expect(find.bySemanticsLabel(s.apsiraLabsLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('the Apsira Labs lockup sits on the dark ground, never '
        'recoloured ($brightness)', (tester) async {
      await _pump(tester, 'en', brightness: brightness);
      final lockup = find.byWidgetPredicate(
        (w) => w is Image && w.image == ApsiraBrand.lockupReversed,
      );
      expect(lockup, findsOneWidget);
      final image = tester.widget<Image>(lockup);
      expect(image.width, greaterThanOrEqualTo(160));
      expect(image.color, isNull, reason: 'never recoloured');
      expect(image.colorBlendMode, isNull);
      final tile = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: lockup,
              matching: find.byKey(const Key('about/credit')),
            )
            .first,
      );
      expect((tile.decoration as BoxDecoration).color, ApsiraTheme.dark.ground);
    });
  }

  testWidgets('Licences opens the licence page with the app\'s name and '
      'version', (tester) async {
    final s = _strings['es']!;
    await _pump(tester, 'es');
    await tester.scrollUntilVisible(
      find.text(s.licencesLabel),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(s.licencesLabel));
    await tester.pumpAndSettle();
    final page = tester.widget<LicensePage>(find.byType(LicensePage));
    expect(page.applicationName, 'LYCEUM');
    expect(page.applicationVersion, '1.0.1');
  });
}
