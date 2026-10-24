// From relay test/app/theme/discovery_test.dart @ 09b28810 (D-APK-017).
//
// Discoverability's shared pieces: the hint that rotates through its
// examples while the field is empty, the suggestion chips that put a token
// at the caret, and the one-time tip card (bordered, one line and its
// button, read by TalkBack, wrapping at large text).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

Widget _host(
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: ApsiraThemeData.dark,
  locale: locale,
  localizationsDelegates: delegates,
  supportedLocales: ApsiraL10n.supportedLocales,
  builder: (context, inner) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: inner!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  group('HintRotation', () {
    Widget rotation({required bool active}) => HintRotation(
      hints: const ['one', 'two', 'three'],
      active: active,
      builder: (_, hint) => Text(hint ?? '', key: const Key('hint')),
    );

    String hint(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('hint'))).data!;

    testWidgets('starts on the first hint and steps every period, wrapping', (
      tester,
    ) async {
      await tester.pumpWidget(_host(rotation(active: true)));
      expect(hint(tester), 'one');
      await tester.pump(hintRotationPeriod);
      expect(hint(tester), 'two');
      await tester.pump(hintRotationPeriod);
      expect(hint(tester), 'three');
      await tester.pump(hintRotationPeriod);
      expect(hint(tester), 'one');
    });

    testWidgets('holds still while inactive (the field has text)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(rotation(active: false)));
      await tester.pump(hintRotationPeriod * 3);
      expect(hint(tester), 'one');
      await tester.pumpWidget(_host(rotation(active: true)));
      await tester.pump(hintRotationPeriod);
      expect(hint(tester), 'two');
    });
  });

  group('insertToken', () {
    TextEditingController at(String text, int caret) =>
        TextEditingController(text: text)
          ..selection = TextSelection.collapsed(offset: caret);

    test('into an empty field: the token, the caret after it', () {
      final c = at('', 0);
      insertToken(c, 'vence:hoy');
      expect(c.text, 'vence:hoy ');
      expect(c.selection.baseOffset, c.text.length);
    });

    test('a key token keeps the caret on its colon (its values follow)', () {
      final c = at('tag:home', 8);
      insertToken(c, 'type:');
      expect(c.text, 'tag:home type:');
      expect(c.selection.baseOffset, 'tag:home type:'.length);
    });

    test('at the caret mid-text, spaced from the words around it', () {
      final c = at('Dentist @health', 7);
      insertToken(c, '10:00');
      expect(c.text, 'Dentist 10:00 @health');
      expect(c.selection.baseOffset, 'Dentist 10:00 '.length);
    });

    test('a mark (@ or #) waits for its name', () {
      final c = at('Dentist', 7);
      insertToken(c, '@');
      expect(c.text, 'Dentist @');
      expect(c.selection.baseOffset, c.text.length);
    });

    test('with no caret yet, at the end', () {
      final c = TextEditingController(text: 'Gym');
      insertToken(c, 'rem:30m');
      expect(c.text, 'Gym rem:30m ');
    });
  });

  group('SuggestionChipRow', () {
    testWidgets('each chip names its token; a tap gives the token', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        _host(
          SuggestionChipRow(
            label: 'Filters',
            chips: const [
              SuggestionChip(label: 'due:today', token: 'due:today'),
              SuggestionChip(label: '#tag', token: '#'),
            ],
            onChosen: chosen.add,
          ),
        ),
      );
      await tester.tap(find.text('#tag'));
      await tester.tap(find.text('due:today'));
      expect(chosen, ['#', 'due:today']);
    });

    testWidgets('each chip is a 48 dp pill drawn from tokens, read as a '
        'button inside the labelled row', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SuggestionChipRow(
            label: 'Filters',
            chips: const [SuggestionChip(label: 'due:today', token: 'due:')],
            onChosen: (_) {},
          ),
        ),
      );
      final t = ApsiraThemeData.dark.extension<ApsiraTheme>()!;
      final pill = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('due:today'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(pill.color, t.surface);
      expect(pill.shape, StadiumBorder(side: BorderSide(color: t.border)));
      expect(
        tester.getSize(find.byType(IntrinsicWidth)).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSemantics(find.text('due:today')),
        isSemantics(label: 'due:today', isButton: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel('Filters'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('at 2.0 text the chips wrap onto more lines, never sideways', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          SuggestionChipRow(
            label: 'Filters',
            chips: [
              for (final t in [
                'vence:hoy',
                'etiqueta:',
                'tipo:',
                '-es:hecha',
                'tiene:recordatorio',
              ])
                SuggestionChip(label: t, token: t),
            ],
            onChosen: (_) {},
          ),
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final tops = {
        for (final t in ['vence:hoy', 'tiene:recordatorio'])
          tester.getTopLeft(find.text(t)).dy,
      };
      expect(tops, hasLength(2), reason: 'two lines at least');
      for (final t in ['vence:hoy', 'tiene:recordatorio']) {
        expect(tester.getTopRight(find.text(t)).dx, lessThanOrEqualTo(344));
      }
    });
  });

  group('OneTimeTipCard', () {
    testWidgets('bordered; its line and Got it; TalkBack reads both', (
      tester,
    ) async {
      var dismissed = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          OneTimeTipCard(
            id: 'quick_add',
            text: 'Type one line',
            onDismiss: () => dismissed++,
          ),
        ),
      );
      expect(find.byKey(OneTimeTipCard.keyOf('quick_add')), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(OneTimeTipCard.keyOf('quick_add')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final t = ApsiraThemeData.dark.extension<ApsiraTheme>()!;
      expect(
        (box.decoration as BoxDecoration).border,
        Border.all(color: t.border),
      );
      expect(find.bySemanticsLabel('Type one line'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.byKey(OneTimeTipCard.dismissKeyOf('quick_add')),
        ),
        isSemantics(label: 'Got it', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byKey(OneTimeTipCard.dismissKeyOf('quick_add')));
      expect(dismissed, 1);
      handle.dispose();
    });

    testWidgets('at 2.0 text the line wraps whole and the button stays', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const line =
          'Tap + or an empty hour to add; press and hold for the full editor';
      await tester.pumpWidget(
        _host(
          OneTimeTipCard(
            id: 'kairos_day',
            text: line,
            dismissLabel: 'Got it',
            onDismiss: () {},
          ),
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(line));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(
        tester.getSize(find.text(line)).height,
        greaterThan(60),
        reason: 'more than one line',
      );
      final button = find.byKey(OneTimeTipCard.dismissKeyOf('kairos_day'));
      expect(button, findsOneWidget);
      expect(tester.getTopRight(button).dx, lessThanOrEqualTo(344));
    });

    testWidgets('Got it is the shared tipGotIt, Entendido in Spanish', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          OneTimeTipCard(id: 'quick_add', text: 'Una línea', onDismiss: () {}),
          locale: const Locale('es'),
        ),
      );
      expect(find.text(es.tipGotIt), findsOneWidget);
      expect(es.tipGotIt, 'Entendido');
    });

    testWidgets('its icon is the given one', (tester) async {
      await tester.pumpWidget(
        _host(
          OneTimeTipCard(
            id: 'quick_add',
            text: 'Type one line',
            icon: Icons.star,
            onDismiss: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });
}
