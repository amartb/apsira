// The example shows the ThemePreview (D-APK-014): from its home, in the
// dark theme and in the light one, every section builds without an error.
import 'package:apsira_ui_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _sample(String theme, String kind, String name) => find.byKey(
  ValueKey('themePreview/$theme/$kind/$name'),
  skipOffstage: false,
);

void main() {
  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('the ThemePreview opens from home (${mode.name})', (
      tester,
    ) async {
      await tester.pumpWidget(ExampleApp(themeMode: mode));
      await tester.tap(find.text('ThemePreview'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final theme in ['dark', 'light']) {
        expect(_sample(theme, 'color', 'ground'), findsOneWidget);
        expect(_sample(theme, 'shape', 'groupCard'), findsOneWidget);
        expect(_sample(theme, 'kit', 'emptyState'), findsOneWidget);
      }
    });
  }
}
