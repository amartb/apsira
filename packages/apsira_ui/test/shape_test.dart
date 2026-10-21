// From relay test/app/theme/relay_shape_test.dart @ 5f606e9
// Shape and spacing: every radius, size and spacing value of UX §2.4 is a
// named constant, and the tables below mirror the spec (RELAY's docs/06 at
// 5f606e9).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('radii (UX §2.4)', () {
    test('each element has its documented radius', () {
      expect(ApsiraRadii.groupCard, 28);
      expect(ApsiraRadii.editorPage, 32);
      expect(ApsiraRadii.sheet, 32);
      expect(ApsiraRadii.drawerPanel, 32);
      expect(ApsiraRadii.captureSheet, 32);
      expect(ApsiraRadii.pinnedCard, 26);
      expect(ApsiraRadii.insetBlock, 22);
      expect(ApsiraRadii.statTile, 22);
      expect(ApsiraRadii.captureTile, 22);
      expect(ApsiraRadii.captureIconTile, 15);
      expect(ApsiraRadii.fab, 24);
      expect(ApsiraRadii.recorderButton, 34);
    });

    test('icon tiles: 14–15 at 40–44 px, 11–12 at 32–36 px', () {
      expect(ApsiraRadii.iconTile(44), 15);
      expect(ApsiraRadii.iconTile(40), 14);
      expect(ApsiraRadii.iconTile(36), 12);
      expect(ApsiraRadii.iconTile(32), 11);
      expect(() => ApsiraRadii.iconTile(38), throwsArgumentError);
      expect(() => ApsiraRadii.iconTile(48), throwsArgumentError);
    });

    test('pills are fully rounded at 24–40 px high', () {
      expect(ApsiraShapes.pill, const StadiumBorder());
      expect(ApsiraSizes.pillMinHeight, 24);
      expect(ApsiraSizes.pillMaxHeight, 40);
    });

    test('rounded rectangles are built from the radii', () {
      expect(
        ApsiraShapes.rounded(ApsiraRadii.groupCard),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      );
      expect(
        ApsiraShapes.sheetTop,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      );
      expect(ApsiraShapes.circle, const CircleBorder());
    });
  });

  group('sizes (UX §2.4)', () {
    test('each element has its documented size', () {
      expect(ApsiraSizes.pinnedCardWidth, 210);
      expect(ApsiraSizes.drawerInset, 8);
      expect(ApsiraSizes.captureIconTile, 44);
      expect(ApsiraSizes.floatingTopBarButton, 48);
      expect(ApsiraSizes.fab, 68);
      expect(ApsiraSizes.recorderButton, 96);
      expect(ApsiraSizes.checkbox, 24);
      expect(ApsiraSizes.checkboxInTaskSheet, 30);
      expect(ApsiraSizes.checkboxRing, 2);
    });
  });

  group('spacing (UX §2.4)', () {
    test('each gap has its documented value', () {
      expect(ApsiraSpacing.grid, 4);
      expect(ApsiraSpacing.screenGutter, 16);
      expect(ApsiraSpacing.largeTitleGutter, 24);
      expect(ApsiraSpacing.cardHeaderTop, 14);
      expect(ApsiraSpacing.cardSide, 20);
      expect(ApsiraSpacing.taskRowVertical, 14);
      expect(ApsiraSpacing.noteRowVertical, 16);
      expect(ApsiraSpacing.dividerAfterCheckbox, 58);
      expect(ApsiraSpacing.dividerAfterIconTile, 78);
      expect(ApsiraSpacing.betweenCards, 16);
      expect(ApsiraSpacing.betweenCardsMax, 18);
      expect(ApsiraSpacing.betweenSections, 18);
      expect(ApsiraSpacing.betweenSectionsMax, 24);
      expect(ApsiraSpacing.betweenPills, 6);
      expect(ApsiraSpacing.betweenPillsMax, 8);
      expect(ApsiraSpacing.titleToMetaPills, 8);
    });

    test('card padding is header 14/20 and rows 14/20 or 16/20', () {
      expect(
        ApsiraSpacing.cardHeader,
        const EdgeInsets.fromLTRB(20, 14, 20, 0),
      );
      expect(
        ApsiraSpacing.taskRow,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      );
      expect(
        ApsiraSpacing.noteRow,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      );
    });
  });
}
