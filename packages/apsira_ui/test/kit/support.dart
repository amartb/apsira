// The kit's test support: the app around a kit widget, in English and
// Spanish (ApsiraL10n and Flutter's Material strings), on apsira_ui's own
// theme (`ApsiraThemeData.build`, the shared set only), and the large-text
// check of apsira_test (D-APK-014).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:apsira_test/apsira_test.dart'
    show expectLayoutSound, pumpApsira, testBothModes;

/// English and Spanish, with every delegate a kit widget reads.
const kitHost = LayoutHost(
  localizationsDelegates: [
    ApsiraL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: ApsiraL10n.supportedLocales,
);

/// The `buildFull` theme for [b]: LYCEUM's sub-themes on top of `build`.
ThemeData fullTheme(Brightness b) => ApsiraThemeData.buildFull(
  b == Brightness.dark ? ApsiraTheme.dark : ApsiraTheme.light,
);

/// Pumps [child] in a scaffold under [kitHost], in [locale] (English by
/// default), on `build`'s theme for [brightness] or on [theme].
Future<void> pumpKit(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  ThemeData? theme,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => pumpApsira(
  tester,
  child,
  host: kitHost,
  brightness: brightness,
  theme: theme,
  locale: locale,
  textScale: textScale,
);

/// The large-text check over [screen] in a scaffold under [kitHost]:
/// EN/ES, 100 % to 200 % text, two phone sizes, both themes.
Future<void> expectKitLayoutSound(
  WidgetTester tester,
  Widget Function() screen,
) => expectLayoutSound(
  tester,
  () => Scaffold(body: SafeArea(child: screen())),
  host: kitHost,
);

/// The tokens the tree at [finder] reads.
ApsiraTheme tokensAt(WidgetTester tester, Finder finder) =>
    ApsiraTheme.of(tester.element(finder.first));

/// A text's colour: its own style's, else the ambient default's.
Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color ??
    DefaultTextStyle.of(tester.element(find.text(text))).style.color;

/// A button that runs [onPressed] with its context, labelled [label].
Widget opener(String label, void Function(BuildContext context) onPressed) =>
    Builder(
      builder: (context) =>
          TextButton(onPressed: () => onPressed(context), child: Text(label)),
    );
