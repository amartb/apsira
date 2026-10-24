// From relay test/features/theme_preview/theme_preview_test.dart @ 09b28810
// (every token, type style, shape and spacing in both themes; each section
// paints with its own tokens), on the Apsira tokens, with the kit samples
// (D-APK-014). `themePreviewEnabled` stays in each app: the flavour is the
// app's.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:apsira_ui/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The component shapes, by their `ApsiraRadii` / `ApsiraSizes` names.
const shapes = [
  'groupCard',
  'editorPage',
  'sheet',
  'drawerPanel',
  'captureSheet',
  'pinnedCard',
  'insetBlock',
  'statTile',
  'captureTile',
  'captureIconTile',
  'iconTile32',
  'iconTile36',
  'iconTile40',
  'iconTile44',
  'pill',
  'floatingTopBarButton',
  'fab',
  'recorderButton',
  'checkbox',
  'checkboxInTaskSheet',
];

/// The spacing tokens, by their `ApsiraSpacing` names.
const spacing = [
  'grid',
  'screenGutter',
  'largeTitleGutter',
  'cardHeaderTop',
  'cardSide',
  'taskRowVertical',
  'noteRowVertical',
  'dividerAfterCheckbox',
  'dividerAfterIconTile',
  'betweenCards',
  'betweenCardsMax',
  'betweenSections',
  'betweenSectionsMax',
  'betweenPills',
  'betweenPillsMax',
  'titleToMetaPills',
];

/// The kit samples.
const kit = [
  'groupCard',
  'emptyState',
  'familyPill',
  'tagPill',
  'filterPill',
  'iconBox',
  'drawerItem',
];

Finder sample(String theme, String kind, String name) => find.byKey(
  ValueKey('themePreview/$theme/$kind/$name'),
  skipOffstage: false,
);

void main() {
  testWidgets('shows every token, type style, shape and kit sample', (
    tester,
  ) async {
    await pumpKit(tester, const ThemePreviewScreen());
    expect(tester.takeException(), isNull);

    for (final (theme, tokens) in [
      ('dark', ApsiraTheme.dark),
      ('light', ApsiraTheme.light),
    ]) {
      for (final name in tokens.colors.keys) {
        expect(sample(theme, 'color', name), findsOneWidget, reason: name);
      }
      for (final f in ApsiraFamily.values) {
        for (final part in ['solid', 'container', 'onContainer']) {
          final name = '${f.name}.$part';
          expect(sample(theme, 'family', name), findsOneWidget, reason: name);
        }
      }
      expect(sample(theme, 'elevation', 'shadow'), findsOneWidget);
      for (final s in ApsiraTypeStyle.values) {
        expect(sample(theme, 'type', s.name), findsOneWidget, reason: s.name);
      }
      expect(sample(theme, 'type', 'listTitle'), findsOneWidget);
      for (final name in shapes) {
        expect(sample(theme, 'shape', name), findsOneWidget, reason: name);
      }
      for (final name in spacing) {
        expect(sample(theme, 'spacing', name), findsOneWidget, reason: name);
      }
      for (final name in kit) {
        expect(sample(theme, 'kit', name), findsOneWidget, reason: name);
      }
    }
  });

  testWidgets('each theme section paints with its own tokens', (tester) async {
    await pumpKit(tester, const ThemePreviewScreen());
    for (final (theme, tokens) in [
      ('dark', ApsiraTheme.dark),
      ('light', ApsiraTheme.light),
    ]) {
      final ctx = tester.element(sample(theme, 'color', 'ground'));
      expect(ApsiraTheme.of(ctx), tokens, reason: theme);
      final style = tester.widget<Text>(
        find.descendant(
          of: sample(theme, 'type', 'body'),
          matching: find.byType(Text),
          skipOffstage: false,
        ),
      );
      expect(style.style?.fontSize, ApsiraTypography.body.fontSize);
      expect(style.style?.color, tokens.ink);
    }
  });
}
