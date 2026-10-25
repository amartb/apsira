// The cover's lock glyph: Material's lock_outline by default (RELAY's), or
// the app's own glyph ([LockCover.icon], LYCEUM's Lucide lock), drawn at the
// cover's size in `accentText` either way; the shield passes it on.
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const _glyph = IconData(0xe900, fontFamily: 'TestGlyphs');

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: ApsiraThemeData.light,
    localizationsDelegates: const [
      ApsiraL10n.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: ApsiraL10n.supportedLocales,
    home: child,
  ),
);

/// The colour and size the [icon] is drawn with.
(Color?, double?) _drawn(WidgetTester tester, IconData icon) {
  final finder = find.byIcon(icon);
  final theme = IconTheme.of(tester.element(finder));
  final widget = tester.widget<Icon>(finder);
  return (widget.color ?? theme.color, widget.size ?? theme.size);
}

void main() {
  testWidgets('by default the cover draws Material\'s lock_outline', (
    tester,
  ) async {
    await _pump(tester, const LockCover(appTitle: 'Relay'));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(_drawn(tester, Icons.lock_outline), (
      ApsiraTheme.light.accentText,
      ApsiraSizes.checkboxInTaskSheet,
    ));
  });

  testWidgets('the app\'s glyph replaces it, at the same size and colour', (
    tester,
  ) async {
    await _pump(
      tester,
      const LockCover(appTitle: 'Lyceum', icon: Icon(_glyph)),
    );
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(_drawn(tester, _glyph), (
      ApsiraTheme.light.accentText,
      ApsiraSizes.checkboxInTaskSheet,
    ));
  });

  testWidgets('the shield passes the app\'s glyph to its cover', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: lockOverrides(
          store: settingsOf(const LockSettings(enabled: true)),
          authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
          clock: FakeClock(t0),
          sink: MemorySink(),
        ),
        child: MaterialApp(
          theme: ApsiraThemeData.light,
          localizationsDelegates: const [
            ApsiraL10n.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: ApsiraL10n.supportedLocales,
          builder: (context, child) => LockShield(
            appTitle: 'Lyceum',
            promptReason: (_) => 'Unlock Lyceum.',
            coverIcon: const Icon(_glyph),
            child: child!,
          ),
          home: const Text('content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LockCover), findsOneWidget);
    expect(find.byIcon(_glyph), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });
}
