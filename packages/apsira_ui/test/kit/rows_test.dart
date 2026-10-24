// From lyceum test/widgets/kit/group_card_test.dart @ 9f4ff27 (icon tiles
// carry a 1 px border on `tint`) and test/navigation/app_drawer_test.dart @
// 9f4ff27 (the active item is a full-width accC pill, a module glyph in its
// accent and onAccC when active, the count as trailing meta), on
// `ApsiraFamily` (D-APK-014).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

BoxDecoration _box(WidgetTester tester, IconData icon) =>
    tester
            .widget<Container>(
              find.ancestor(
                of: find.byIcon(icon),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

/// The `Material` a drawer item paints its pill with.
Material _pill(WidgetTester tester, String label) => tester.widget<Material>(
  find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
);

void main() {
  group('IconBox', () {
    testBothModes('an icon tile carries a 1 px border on tint', (
      tester,
      b,
    ) async {
      await pumpKit(tester, const IconBox(ApsiraIcons.folder), brightness: b);
      final t = tokensAt(tester, find.byType(IconBox));
      final box = _box(tester, ApsiraIcons.folder);
      expect(box.color, t.tint);
      expect(box.border, Border.all(color: t.border));
      expect(box.borderRadius, BorderRadius.circular(ApsiraRadii.iconTile(40)));
      expect(
        tester.widget<Icon>(find.byIcon(ApsiraIcons.folder)).color,
        t.ink2,
      );
    });

    testBothModes('a family is the glyph accent; filled is its container', (
      tester,
      b,
    ) async {
      await pumpKit(
        tester,
        const Column(
          children: [
            IconBox(ApsiraIcons.folder, family: ApsiraFamily.blue),
            IconBox(
              ApsiraIcons.warning,
              family: ApsiraFamily.redOrange,
              filled: true,
            ),
          ],
        ),
        brightness: b,
      );
      final t = tokensAt(tester, find.byType(Column));
      expect(_box(tester, ApsiraIcons.folder).color, t.tint);
      expect(
        tester.widget<Icon>(find.byIcon(ApsiraIcons.folder)).color,
        t.family(ApsiraFamily.blue).solid,
      );
      final red = t.family(ApsiraFamily.redOrange);
      expect(_box(tester, ApsiraIcons.warning).color, red.container);
      expect(
        tester.widget<Icon>(find.byIcon(ApsiraIcons.warning)).color,
        red.onContainer,
      );
    });

    test('radiusFor takes the nearest defined tile', () {
      expect(IconBox.radiusFor(40), ApsiraRadii.iconTiles[40]);
      expect(IconBox.radiusFor(48), ApsiraRadii.iconTiles[44]);
      expect(IconBox.radiusFor(30), ApsiraRadii.iconTiles[32]);
    });
  });

  group('DrawerItem', () {
    Widget items({required bool selected}) => Column(
      children: [
        DrawerItem(
          icon: ApsiraIcons.folder,
          label: 'Sources',
          selected: selected,
          family: ApsiraFamily.blue,
          onTap: () {},
        ),
        DrawerItem(
          icon: ApsiraIcons.plus,
          label: 'Inbox',
          selected: false,
          count: 3,
          onTap: () {},
        ),
      ],
    );

    testBothModes('the active item is a full-width accC pill', (
      tester,
      b,
    ) async {
      await pumpKit(tester, items(selected: true), brightness: b);
      final t = tokensAt(tester, find.text('Sources'));
      final active = _pill(tester, 'Sources');
      expect(active.color, t.accC);
      expect(
        active.borderRadius,
        BorderRadius.circular(ApsiraRadii.drawerPanel),
      );
      expect(textColor(tester, 'Sources'), t.onAccC);
      expect(
        tester.widget<Icon>(find.byIcon(ApsiraIcons.folder)).color,
        t.onAccC,
      );
      expect(_pill(tester, 'Inbox').color, t.accC.withValues(alpha: 0));
      expect(textColor(tester, 'Inbox'), t.ink);
      expect(
        tester.getSemantics(find.text('Sources')),
        isSemantics(isSelected: true, isButton: true, hasSelectedState: true),
      );
      expect(
        tester.getSize(find.byType(DrawerItem).first).height,
        greaterThanOrEqualTo(48),
      );
    });

    testBothModes('a family glyph is in its accent while not active', (
      tester,
      b,
    ) async {
      await pumpKit(tester, items(selected: false), brightness: b);
      final t = tokensAt(tester, find.text('Sources'));
      expect(
        tester.widget<Icon>(find.byIcon(ApsiraIcons.folder)).color,
        t.family(ApsiraFamily.blue).solid,
      );
      expect(tester.widget<Icon>(find.byIcon(ApsiraIcons.plus)).color, t.ink2);
    });

    testWidgets('the count is trailing meta text, then the trailing widget', (
      tester,
    ) async {
      var taps = 0;
      await pumpKit(
        tester,
        DrawerItem(
          icon: ApsiraIcons.plus,
          label: 'Inbox',
          selected: false,
          count: 3,
          trailing: const Icon(ApsiraIcons.chevron, key: Key('trail')),
          onTap: () => taps++,
        ),
      );
      final t = tokensAt(tester, find.text('Inbox'));
      final count = tester.widget<Text>(find.text('3')).style!;
      expect(count.fontSize, ApsiraTypography.meta.fontSize);
      expect(count.color, t.ink3);
      expect(
        tester.getRect(find.text('3')).right,
        lessThanOrEqualTo(tester.getRect(find.byKey(const Key('trail'))).left),
      );
      await tester.tap(find.text('Inbox'));
      expect(taps, 1);
    });
  });

  testWidgets('DrawerHeaderBlock stacks its mark, tagline and child', (
    tester,
  ) async {
    await pumpKit(
      tester,
      const DrawerHeaderBlock(
        mark: Text('LYCEUM'),
        tagline: 'Research and writing',
        child: Text('Selector'),
      ),
    );
    final mark = tester.getRect(find.text('LYCEUM'));
    final tagline = tester.getRect(find.text('Research and writing'));
    final child = tester.getRect(find.text('Selector'));
    expect(mark.bottom, lessThanOrEqualTo(tagline.top));
    expect(tagline.bottom, lessThanOrEqualTo(child.top));
    final t = tokensAt(tester, find.text('LYCEUM'));
    expect(textColor(tester, 'Research and writing'), t.ink2);
  });

  testWidgets('the rows are sound at large text, EN and ES', (tester) async {
    await expectKitLayoutSound(
      tester,
      () => ListView(
        children: [
          const DrawerHeaderBlock(
            mark: Text('LYCEUM'),
            tagline: 'Investigación y escritura',
          ),
          const IconBox(ApsiraIcons.folder, family: ApsiraFamily.green),
          DrawerItem(
            icon: ApsiraIcons.folder,
            label: 'Fuentes y bibliografía',
            selected: true,
            onTap: () {},
          ),
          DrawerItem(
            icon: ApsiraIcons.plus,
            label: 'Bandeja de entrada',
            selected: false,
            count: 12,
            onTap: () {},
          ),
        ],
      ),
    );
  });
}
