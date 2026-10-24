// From lyceum test/widgets/kit/group_card_test.dart and
// test/widgets/kit/titles_detail_test.dart @ 9f4ff27 (CardPart, the group
// card, PageTitle, SectionHeader), with LYCEUM's EntityRow rows as plain text
// rows, which stay in LYCEUM; names unchanged (D-APK-014).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The shape a [CardSlice] paints its slice of the card with.
ShapeDecoration _sliceDecoration(WidgetTester tester, Finder slice) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: slice, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as ShapeDecoration;

/// The style [text] is painted with (its own merged with the defaults).
TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

/// A row at the text column after an icon tile, as the apps' rows sit.
class _Row extends StatelessWidget {
  const _Row(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      ApsiraSpacing.dividerAfterIconTile,
      ApsiraSpacing.noteRowVertical,
      ApsiraSpacing.cardSide,
      ApsiraSpacing.noteRowVertical,
    ),
    child: Text(text),
  );
}

void main() {
  test('CardPart.at places a slice in its card', () {
    expect(CardPart.at(0, 1), CardPart.only);
    expect(CardPart.at(0, 3), CardPart.first);
    expect(CardPart.at(1, 3), CardPart.middle);
    expect(CardPart.at(2, 3), CardPart.last);
  });

  testBothModes('slices draw one card with inset dividers', (tester, b) async {
    await pumpKit(
      tester,
      ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: ApsiraSpacing.screenGutter,
        ),
        itemCount: 3,
        itemBuilder: (_, i) => CardSlice(
          part: CardPart.at(i, 3),
          divider: i > 0,
          child: _Row('row $i'),
        ),
      ),
      brightness: b,
    );
    final t = tokensAt(tester, find.text('row 0'));
    final slices = find.byType(CardSlice);
    expect(slices, findsNWidgets(3));

    // One surface with its 1 px border and the group-card corners.
    for (var i = 0; i < 3; i++) {
      final shape = _sliceDecoration(tester, slices.at(i));
      expect(shape.color, t.surface);
      final border = shape.shape as RoundedRectangleBorder;
      expect(border.side, BorderSide(color: t.border));
      expect(border.borderRadius, BorderRadius.circular(ApsiraRadii.groupCard));
    }

    // The slices touch: the card reads as one, at the screen gutter.
    final rects = [for (var i = 0; i < 3; i++) tester.getRect(slices.at(i))];
    expect(rects[0].bottom, rects[1].top);
    expect(rects[1].bottom, rects[2].top);
    expect(rects[0].left, ApsiraSpacing.screenGutter);

    // Two dividers inside the card, inset to the text column; none on top.
    final dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
    expect(dividers, hasLength(2));
    for (final d in dividers) {
      expect(d.indent, ApsiraSpacing.dividerAfterIconTile);
      expect(d.endIndent, ApsiraSpacing.cardSide);
      expect(d.color, t.line);
    }
    expect(
      find.descendant(of: slices.at(0), matching: find.byType(Divider)),
      findsNothing,
    );
  });

  testBothModes('a group card holds its header and rows in one card', (
    tester,
    b,
  ) async {
    await pumpKit(
      tester,
      const GroupCard(
        header: 'Characters',
        children: [_Row('Anna'), _Row('Boris')],
      ),
      brightness: b,
    );
    final t = tokensAt(tester, find.text('Anna'));
    expect(find.byType(CardSlice), findsNWidgets(2));
    expect(find.byType(Divider), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CardSlice).first,
        matching: find.text('Characters'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.text('Characters')),
      isSemantics(isHeader: true, label: 'Characters'),
    );
    final style = tester.widget<Text>(find.text('Characters')).style!;
    expect(style.fontSize, ApsiraTypography.cardTitle.fontSize);
    expect(style.color, t.ink);
  });

  testWidgets('a group card takes its divider indent', (tester) async {
    await pumpKit(
      tester,
      const GroupCard(
        dividerIndent: ApsiraSpacing.dividerAfterCheckbox,
        children: [_Row('Anna'), _Row('Boris')],
      ),
    );
    expect(
      tester.widget<Divider>(find.byType(Divider)).indent,
      ApsiraSpacing.dividerAfterCheckbox,
    );
  });

  group('PageTitle', () {
    testWidgets('PageTitle wraps at 2.0 and is a header', (tester) async {
      const title = 'Personajes secundarios de la segunda parte';
      await pumpKit(
        tester,
        const Align(alignment: Alignment.topLeft, child: PageTitle(title)),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(title));
      expect(text.maxLines, isNull, reason: 'a large title never cuts');
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.getSemantics(find.text(title)),
        isSemantics(isHeader: true, label: title),
      );
    });

    testBothModes('PageTitle is listTitle in ink, or display for a date', (
      tester,
      b,
    ) async {
      await pumpKit(
        tester,
        const Column(
          children: [
            PageTitle('Characters'),
            PageTitle('Thursday 23 October', display: true),
          ],
        ),
        brightness: b,
      );
      final t = tokensAt(tester, find.text('Characters'));
      final list = _styleOf(tester, 'Characters');
      expect(list.fontSize, ApsiraTypography.listTitle.fontSize);
      expect(list.color, t.ink);
      final date = _styleOf(tester, 'Thursday 23 October');
      expect(date.fontSize, ApsiraTypography.display.fontSize);
      expect(date.color, t.ink);
    });

    testWidgets('PageTitle places its leading and trailing beside the text', (
      tester,
    ) async {
      await pumpKit(
        tester,
        const PageTitle(
          'Characters',
          leading: Icon(ApsiraIcons.folder, key: Key('lead')),
          trailing: Icon(ApsiraIcons.plus, key: Key('trail')),
        ),
      );
      final text = tester.getRect(find.text('Characters'));
      expect(
        tester.getRect(find.byKey(const Key('lead'))).right,
        lessThan(text.left),
      );
      expect(
        tester.getRect(find.byKey(const Key('trail'))).left,
        greaterThanOrEqualTo(text.right),
      );
    });
  });

  testBothModes('SectionHeader is a sentence-case group label', (
    tester,
    b,
  ) async {
    await pumpKit(
      tester,
      const SectionHeader('Retired works', count: 3),
      brightness: b,
    );
    final t = tokensAt(tester, find.text('Retired works'));
    expect(find.text('RETIRED WORKS'), findsNothing);
    final label = _styleOf(tester, 'Retired works');
    expect(label.fontSize, ApsiraTypography.meta.fontSize);
    expect(label.color, t.ink2);
    expect(_styleOf(tester, '3').color, t.ink3);
    expect(
      tester.getSemantics(find.text('Retired works')),
      isSemantics(isHeader: true),
    );
  });

  testBothModes('OverlineLabel is an upper-case header in ink3', (
    tester,
    b,
  ) async {
    await pumpKit(tester, const OverlineLabel('Modules'), brightness: b);
    final t = tokensAt(tester, find.text('MODULES'));
    expect(_styleOf(tester, 'MODULES').color, t.ink3);
    expect(
      tester.getSemantics(find.text('MODULES')),
      isSemantics(isHeader: true),
    );
  });

  testWidgets('the layout widgets are sound at large text, EN and ES', (
    tester,
  ) async {
    await expectKitLayoutSound(
      tester,
      () => ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: ApsiraSpacing.screenGutter,
        ),
        children: const [
          PageTitle('Personajes secundarios'),
          SectionHeader('Obras retiradas', count: 12),
          OverlineLabel('Módulos de investigación'),
          GroupCard(
            header: 'Recordatorios de la semana',
            children: [
              _Row('Comprar jabón para la cocina'),
              _Row('Arreglar la puerta del garaje'),
            ],
          ),
        ],
      ),
    );
  });
}
