// From lyceum test/widgets/kit/kit_widgets_test.dart (Search & filters) and
// test/widgets/kit/forms_states_test.dart (the SearchFilterBar group) @
// 9f4ff27, the labels from ApsiraL10n (D-APK-014).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('SearchFilterBar reports text, clears, and badges filters', (
    tester,
  ) async {
    final seen = <String>[];
    var filtered = false;
    await pumpKit(
      tester,
      SearchFilterBar(
        onChanged: seen.add,
        activeFilterCount: 2,
        onFilter: () => filtered = true,
      ),
    );
    await tester.enterText(find.byType(TextField), 'tuch');
    await tester.pump();
    expect(seen.last, 'tuch');
    expect(find.text('Search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(seen.last, '');
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter'));
    expect(filtered, isTrue);
  });

  testWidgets('SearchFilterBar labels default to ApsiraL10n (es)', (
    tester,
  ) async {
    await pumpKit(
      tester,
      SearchFilterBar(onChanged: (_) {}, onFilter: () {}),
      locale: const Locale('es'),
    );
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.byTooltip('Filtrar'), findsOneWidget);
  });

  testBothModes('the search field is an outlined pill', (tester, b) async {
    await pumpKit(
      tester,
      SearchFilterBar(onChanged: (_) {}, onFilter: () {}),
      brightness: b,
    );
    final t = tokensAt(tester, find.byType(SearchFilterBar));
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, t.surface);
    final enabled = decoration.enabledBorder! as OutlineInputBorder;
    final focused = decoration.focusedBorder! as OutlineInputBorder;
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(52),
    );
    expect(enabled.borderRadius, BorderRadius.circular(26));
    expect(enabled.borderSide.color, t.border);
    expect(focused.borderSide.color, t.accentText);
  });

  testWidgets('takes autofocus', (tester) async {
    await pumpKit(tester, SearchFilterBar(onChanged: (_) {}));
    EditableText field() => tester.widget(find.byType(EditableText));
    expect(field().focusNode.hasFocus, isFalse);
    await pumpKit(
      tester,
      SearchFilterBar(key: UniqueKey(), onChanged: (_) {}, autofocus: true),
    );
    await tester.pump();
    expect(field().focusNode.hasFocus, isTrue);
  });

  for (final withFilter in [false, true]) {
    testWidgets('ends at the card gutter (filter: $withFilter)', (
      tester,
    ) async {
      await pumpKit(
        tester,
        SearchFilterBar(onChanged: (_) {}, onFilter: withFilter ? () {} : null),
      );
      final width = tester.getSize(find.byType(SearchFilterBar)).width;
      final field = tester.getRect(find.byType(TextField));
      expect(field.left, ApsiraSpacing.screenGutter);
      final end = withFilter
          ? tester.getRect(find.byType(IconButton)).right
          : field.right;
      expect(end, width - ApsiraSpacing.screenGutter);
    });
  }

  testWidgets('ActiveFilterPills offers clear and clear all', (tester) async {
    var cleared = 0;
    await pumpKit(
      tester,
      ActiveFilterPills(
        filters: [('A', () {}), ('B', () {})],
        onClearAll: () => cleared++,
      ),
    );
    expect(find.byTooltip('Clear'), findsNWidgets(2));
    await tester.tap(find.text('Clear all'));
    expect(cleared, 1);
  });

  testWidgets('ActiveFilterPills labels default to ApsiraL10n (es)', (
    tester,
  ) async {
    await pumpKit(
      tester,
      ActiveFilterPills(
        filters: [('A', () {}), ('B', () {})],
        onClearAll: () {},
      ),
      locale: const Locale('es'),
    );
    expect(find.byTooltip('Borrar'), findsNWidgets(2));
    expect(find.text('Borrar todo'), findsOneWidget);
  });

  testWidgets('no filters draw nothing', (tester) async {
    await pumpKit(tester, const ActiveFilterPills(filters: []));
    expect(find.byType(TagPill), findsNothing);
  });

  testWidgets('the search bar and its pills are sound at large text', (
    tester,
  ) async {
    await expectKitLayoutSound(
      tester,
      () => Column(
        children: [
          SearchFilterBar(
            onChanged: (_) {},
            onFilter: () {},
            activeFilterCount: 3,
          ),
          ActiveFilterPills(
            filters: [
              ('Etiqueta: #casa', () {}),
              ('Carpeta: Proyectos', () {}),
            ],
            onClearAll: () {},
          ),
        ],
      ),
    );
  });
}
