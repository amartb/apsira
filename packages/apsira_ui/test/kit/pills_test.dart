// From lyceum test/widgets/kit/kit_widgets_test.dart @ 9f4ff27 (the status
// pill reads its family and never a literal, TagPill's delete, StatusDot's
// label; LyceumStatus → ApsiraFamily) and relay
// test/features/notes_list/notes_list_screen_test.dart @ 09b28810 (the filter
// pills and the remove button are 48 dp targets, the pill drawn at its
// visual height), D-APK-014.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The fill colours of the boxes drawn inside [of], outermost first.
List<Color?> _fills(WidgetTester tester, Finder of) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: of, matching: find.byType(DecoratedBox)),
  ))
    switch (box.decoration) {
      final BoxDecoration d => d.color,
      final ShapeDecoration d => d.color,
      _ => null,
    },
];

void main() {
  testWidgets('a family pill reads its family, never a literal', (
    tester,
  ) async {
    for (final base in [ApsiraTheme.dark, ApsiraTheme.light]) {
      // The same set with every family moved on by one: a pill that drew a
      // literal, or a fixed token set, would not follow it.
      const all = ApsiraFamily.values;
      final moved = base.copyWith(
        families: {
          for (final f in all) f: base.family(all[(f.index + 1) % all.length]),
        },
      );
      for (final t in [base, moved]) {
        for (final f in ApsiraFamily.values) {
          await pumpKit(
            tester,
            Center(
              child: FamilyPill(label: f.name, family: f),
            ),
            theme: ApsiraThemeData.build(t),
          );
          // MaterialApp animates a theme change.
          await tester.pumpAndSettle();
          final c = t.family(f);
          final why = '${t.brightness.name} ${f.name}';
          expect(textColor(tester, f.name), c.onContainer, reason: why);
          expect(
            tester.widget<Text>(find.text(f.name)).style?.fontSize,
            ApsiraTypography.pill.fontSize,
            reason: why,
          );
          // The tonal fill, then the leading dot in the family's solid.
          expect(_fills(tester, find.byType(FamilyPill)), [
            c.container,
            c.solid,
          ], reason: why);
        }
      }
    }
  });

  testWidgets('a family pill with an icon leads with it, not the dot', (
    tester,
  ) async {
    await pumpKit(
      tester,
      const FamilyPill(
        label: 'Bible',
        family: ApsiraFamily.pink,
        icon: ApsiraIcons.folder,
      ),
    );
    final t = tokensAt(tester, find.text('Bible'));
    expect(
      tester.widget<Icon>(find.byIcon(ApsiraIcons.folder)).color,
      t.family(ApsiraFamily.pink).onContainer,
    );
    expect(_fills(tester, find.byType(FamilyPill)), [
      t.family(ApsiraFamily.pink).container,
    ]);
  });

  testWidgets('TagPill delete calls back and has a tooltip', (tester) async {
    var deleted = false;
    await pumpKit(
      tester,
      TagPill(
        label: 'tag',
        onDeleted: () => deleted = true,
        deleteTooltip: 'remove',
      ),
    );
    final t = tokensAt(tester, find.text('tag'));
    expect(textColor(tester, 'tag'), t.ink2);
    expect(find.byTooltip('remove'), findsOneWidget);
    await tester.tap(find.byTooltip('remove'));
    expect(deleted, isTrue);
  });

  testWidgets('StatusDot exposes its semantics label', (tester) async {
    await pumpKit(
      tester,
      const StatusDot(family: ApsiraFamily.green, semanticsLabel: 'read'),
    );
    expect(find.bySemanticsLabel('read'), findsOneWidget);
    final t = tokensAt(tester, find.byType(StatusDot));
    expect(_fills(tester, find.byType(StatusDot)), [
      t.family(ApsiraFamily.green).solid,
    ]);
  });

  testBothModes('the filter pills are 48 dp targets drawn at pill height', (
    tester,
    b,
  ) async {
    var removed = 0;
    var added = 0;
    await pumpKit(
      tester,
      Wrap(
        children: [
          FilterPill(
            label: 'Tag: #work',
            removeLabel: 'Remove filter Tag: #work',
            onRemove: () => removed++,
          ),
          AddFilterPill(label: 'Filter', onTap: () => added++),
        ],
      ),
      brightness: b,
    );
    final t = tokensAt(tester, find.text('Filter'));
    for (final pill in [find.byType(AddFilterPill), find.byType(FilterPill)]) {
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(48));
    }
    final drawn = find.descendant(
      of: find.byType(FilterPill),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(drawn.first).height, FilterPill.visualHeight);
    expect(_fills(tester, find.byType(FilterPill)).first, t.accC);
    expect(textColor(tester, 'Tag: #work'), t.onAccC);
    final remove = find.byTooltip('Remove filter Tag: #work');
    expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(remove).width, greaterThanOrEqualTo(48));
    await tester.tap(remove);
    await tester.tap(find.text('Filter'));
    expect((removed, added), (1, 1));
    expect(textColor(tester, 'Filter'), t.ink2);
  });

  testWidgets('the pills are sound at large text, EN and ES', (tester) async {
    await expectKitLayoutSound(
      tester,
      () => Padding(
        padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
        child: Wrap(
          spacing: ApsiraSpacing.betweenPills,
          runSpacing: ApsiraSpacing.betweenPills,
          children: [
            const FamilyPill(label: 'En revisión', family: ApsiraFamily.amber),
            const TagPill(label: 'investigación'),
            FilterPill(
              label: 'Etiqueta: #casa',
              removeLabel: 'Quitar filtro',
              onRemove: () {},
            ),
            AddFilterPill(label: 'Filtrar', onTap: () {}),
            const StatusDot(semanticsLabel: 'leído'),
          ],
        ),
      ),
    );
  });
}
