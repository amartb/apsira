// From lyceum test/support/pump_lyceum.dart @ 9f4ff27: pumpApsira puts a
// widget in an app's theme, locale and text scale, inside a Scaffold.
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pumps the widget in apsira_ui dark at 100 % by default', (
    tester,
  ) async {
    await pumpApsira(tester, const Text('Hello'));
    final context = tester.element(find.text('Hello'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(ApsiraTheme.of(context), ApsiraTheme.dark);
    expect(MediaQuery.textScalerOf(context), AndroidFontScaler(1));
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('takes a theme, a locale and an Android text scale', (
    tester,
  ) async {
    await pumpApsira(
      tester,
      const Text('Hola'),
      theme: ApsiraThemeData.light,
      locale: const Locale('en', 'US'),
      textScale: 2,
      wrapInScaffold: false,
    );
    final context = tester.element(find.text('Hola'));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Localizations.localeOf(context), const Locale('en', 'US'));
    expect(MediaQuery.textScalerOf(context), AndroidFontScaler(2));
    expect(find.byType(Scaffold), findsNothing);
  });

  testWidgets('pumps in the brightness asked for, through the host', (
    tester,
  ) async {
    await pumpApsira(tester, const Text('x'), brightness: Brightness.light);
    expect(
      Theme.of(tester.element(find.text('x'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('unmountAndFlush leaves no widget and no pending timer', (
    tester,
  ) async {
    await pumpApsira(tester, const Text('gone'));
    await unmountAndFlush(tester);
    expect(find.text('gone'), findsNothing);
  });

  testBothModes('a widget in each mode', (tester, brightness) async {
    await pumpApsira(tester, const Text('m'), brightness: brightness);
    expect(Theme.of(tester.element(find.text('m'))).brightness, brightness);
  });
}
