// The app the package's widgets are tested in: apsira_ui's themes, the
// shared strings and Flutter's Material strings in English and Spanish.
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const delegates = <LocalizationsDelegate<Object?>>[
  ApsiraL10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The layout check's and the goldens' host.
const host = LayoutHost(
  localizationsDelegates: delegates,
  supportedLocales: ApsiraL10n.supportedLocales,
);

final en = ApsiraL10nEn();
final es = ApsiraL10nEs();

/// Pumps [home] in the dark theme, in [locale], with reduce motion when
/// [reduceMotion]; [home] is the whole screen (no Scaffold is added).
Future<void> pumpHome(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ApsiraThemeData.dark,
    locale: locale,
    localizationsDelegates: delegates,
    supportedLocales: ApsiraL10n.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: home,
  ),
);

Finder byKey(String key) => find.byKey(Key(key));
