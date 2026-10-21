// The consumer smoke test (packages brief §4): a MaterialApp on
// ApsiraThemeData.build resolves the package-qualified font families, and an
// app's own ThemeExtensions travel beside the tokens.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app's own extension, as a consumer would add one.
@immutable
class AppRoles extends ThemeExtension<AppRoles> {
  const AppRoles(this.name);

  final String name;

  @override
  AppRoles copyWith({String? name}) => AppRoles(name ?? this.name);

  @override
  AppRoles lerp(covariant ThemeExtension<AppRoles>? other, double t) => this;
}

/// The style the [RichText] holding [text] resolves to.
TextStyle resolved(WidgetTester tester, String text) => tester
    .widget<RichText>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style!;

void main() {
  testWidgets('a MaterialApp on ApsiraThemeData.build(ApsiraTheme.dark) '
      'resolves the Expanded family', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ApsiraThemeData.build(ApsiraTheme.dark),
        home: Builder(
          // A Material, as every screen has, gives a plain Text the
          // theme's default style (bodyMedium).
          builder: (ctx) => Material(
            child: Column(
              children: [
                // The display role: RELAY maps the `display` style onto
                // Material's displaySmall (ApsiraTypography.textTheme).
                Text('x', style: Theme.of(ctx).textTheme.displaySmall),
                const Text('plain'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      resolved(tester, 'x').fontFamily,
      'packages/apsira_ui/ArchivoExpanded',
    );
    expect(resolved(tester, 'plain').fontFamily, 'packages/apsira_ui/Archivo');
  });

  testWidgets('build(t, extensions: [x]) exposes both t and x', (tester) async {
    const roles = AppRoles('lyceum');
    late ApsiraTheme tokens;
    late AppRoles? found;
    await tester.pumpWidget(
      MaterialApp(
        theme: ApsiraThemeData.build(ApsiraTheme.dark, extensions: [roles]),
        home: Builder(
          builder: (ctx) {
            tokens = ApsiraTheme.of(ctx);
            found = Theme.of(ctx).extension<AppRoles>();
            return const SizedBox();
          },
        ),
      ),
    );
    expect(identical(tokens, ApsiraTheme.dark), isTrue);
    expect(identical(found, roles), isTrue);
  });
}
