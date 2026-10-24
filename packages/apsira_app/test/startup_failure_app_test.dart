// From lyceum test/startup/startup_failure_test.dart @ 9f4ff27 (the fatal
// screen's cases): dark whatever the platform brightness, and in the
// phone's language through the app's own delegates. Every string is the
// app's (a parameter), so the cases run with English and Spanish ones.
import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _strings = {
  'en': (title: 'Lyceum', message: 'LYCEUM could not start.'),
  'es': (title: 'Liceo', message: 'LYCEUM no ha podido arrancar.'),
};

String _lang(BuildContext context) =>
    _strings.containsKey(Localizations.localeOf(context).languageCode)
    ? Localizations.localeOf(context).languageCode
    : 'en';

Widget _app() => StartupFailureApp(
  title: (context) => _strings[_lang(context)]!.title,
  message: (context) => _strings[_lang(context)]!.message,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('es')],
);

void main() {
  for (final lang in ['en', 'es']) {
    testWidgets('the fatal screen shows the app\'s message and title in '
        '$lang', (tester) async {
      tester.platformDispatcher.localesTestValue = [Locale(lang)];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.text(_strings[lang]!.message), findsOneWidget);
      expect(find.byIcon(ApsiraIcons.failed), findsOneWidget);
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        _strings[lang]!.title,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the fatal screen is dark whatever the platform brightness', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    for (final platform in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      await tester.pumpWidget(_app());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark, reason: '$platform');
      final context = tester.element(find.text(_strings['en']!.message));
      expect(
        Theme.of(context).brightness,
        Brightness.dark,
        reason: '$platform',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the app\'s own theme is used', (tester) async {
    final theme = ApsiraThemeData.build(ApsiraTheme.dark);
    await tester.pumpWidget(
      StartupFailureApp(
        title: (_) => 'Relay',
        message: (_) => 'RELAY could not start.',
        theme: theme,
      ),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, same(theme));
  });
}
