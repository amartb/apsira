// From relay test/features/help/help_screen_test.dart @ 09b28810 and
// viaticum test/features/help/help_screen_test.dart @ 78d38e0, for the
// shell both apps' Help share (D-APK-017). The tours, the how-tos and their
// words are the app's; here they are fixtures.
//
// Help lists its groups of rows (each row its icon, label and one-line
// subline, read as one button, 48 dp at least, spanning its card; a group's
// title a header); a tour plays on its own screen under its title, and
// Done or Skip closes it; a how-to is a page of numbered steps, each read
// as "Step n", and worked examples (typed text in the monospace face, taps
// in the body face, and what you get, each read as one sentence), safe at
// large text; the paths are /help/tour/<id> and /help/howto/<id>.
import 'dart:async';

import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

final _opened = <String>[];

HelpRow _row(String kind, String id, String label, String subline) => HelpRow(
  key: kind == 'tour' ? HelpKeys.tour(id) : HelpKeys.howTo(id),
  icon: Icons.school_outlined,
  label: label,
  subline: subline,
  onTap: () => _opened.add('$kind/$id'),
);

Widget _page() => HelpScreen(
  groups: [
    HelpGroup(
      children: [
        _row(
          'tour',
          'basic',
          'Take the basic tour',
          'The essentials · 5 steps',
        ),
      ],
    ),
    HelpGroup(
      title: 'Tours by topic',
      children: [
        _row('tour', 'backups', 'Backups', 'Where your copies go · 4 steps'),
        _row('tour', 'search', 'Search', 'Find anything · 3 steps'),
      ],
    ),
    HelpGroup(
      title: 'How-tos',
      children: [_row('howto', 'language', 'Change the language', '3 steps')],
    ),
  ],
);

const _steps = [
  'Open Settings from the menu.',
  'Tap Language.',
  'Choose English, Español or Follow phone.',
];

const _examples = [
  HowToExample(
    how: 'Type in Search',
    input: 'due<7d -is:done',
    result: 'Everything due within a week, not done yet',
    typed: true,
    breakable: true,
  ),
  HowToExample(
    how: 'Tap',
    input: 'Settings → Language → Español',
    result: 'Relay in Spanish',
  ),
];

Widget _howTo({List<HowToExample> examples = _examples}) => HowToPage(
  title: 'Change the language of the whole app, even its first screens',
  steps: _steps,
  stepLabel: (n, step) => 'Step $n: $step',
  examples: examples,
  examplesHeader: 'Examples',
  exampleResultLabel: 'You get',
  exampleLabel: (e) => '${e.how}: ${e.input}. You get: ${e.result}',
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
}) async {
  _opened.clear();
  await pumpHome(tester, home, locale: locale);
  await tester.pumpAndSettle();
}

void main() {
  group('the Help page', () {
    testWidgets('lists its groups under Help, in order', (tester) async {
      await _pump(tester, _page());
      expect(find.text('Help'), findsOneWidget);
      final rows = [
        'tour/basic',
        'tour/backups',
        'tour/search',
        'howto/language',
      ];
      final tops = [
        for (final r in rows) tester.getTopLeft(byKey('help/$r')).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('The essentials · 5 steps'), findsOneWidget);
    });

    testWidgets('Ayuda in Spanish', (tester) async {
      await _pump(tester, _page(), locale: const Locale('es'));
      expect(find.text('Ayuda'), findsOneWidget);
    });

    testWidgets('a tap opens the tour or the how-to its row names', (
      tester,
    ) async {
      await _pump(tester, _page());
      await tester.tap(byKey('help/tour/basic'));
      await tester.tap(byKey('help/tour/backups'));
      await tester.tap(byKey('help/howto/language'));
      expect(_opened, ['tour/basic', 'tour/backups', 'howto/language']);
    });

    testWidgets('every row is at least 48 dp tall and spans the card', (
      tester,
    ) async {
      await _pump(tester, _page());
      for (final key in ['help/tour/basic', 'help/tour/search']) {
        final size = tester.getSize(byKey(key));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThan(300), reason: key);
      }
    });

    testWidgets('a row reads as one sentence, a button', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _page());
      final node = tester.getSemantics(byKey('help/tour/backups'));
      expect(node.label, contains('Backups'));
      expect(node.label, contains('Where your copies go · 4 steps'));
      expect(node.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets("a group's title is a heading", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _page());
      expect(
        tester
            .getSemantics(find.text('Tours by topic'))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('a group is a bordered surface card', (tester) async {
      await _pump(tester, _page());
      final t = ApsiraTheme.dark;
      final card = tester.widget<Material>(
        find
            .ancestor(
              of: byKey('help/tour/basic'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, t.surface);
      expect(
        card.shape,
        ApsiraShapes.rounded(ApsiraRadii.groupCard)
            .copyWith(side: BorderSide(color: t.border)),
      );
    });

    testWidgets('is sound at large text, in English and Spanish', (
      tester,
    ) async {
      await expectLayoutSound(tester, _page, host: host);
    });
  });

  group('a tour', () {
    List<TourStepData> steps(int n) => [
      for (var i = 0; i < n; i++)
        TourStepData(
          title: 'Step title $i',
          body: 'Body $i',
          summary: 'Scene $i',
          scene: (_, _) => const SizedBox(height: 40),
        ),
    ];

    testWidgets('plays its steps under its title; Done closes it', (
      tester,
    ) async {
      var closed = 0;
      await _pump(
        tester,
        HelpTourScreen(
          title: 'Backups',
          steps: steps(3),
          onClose: () => closed++,
        ),
      );
      expect(find.text('Backups'), findsOneWidget);
      final player = tester.widget<TourPlayer>(find.byType(TourPlayer));
      expect(player.steps, hasLength(3));
      expect(player.secondaryLabel, isNull, reason: 'no Show me more here');
      for (var i = 0; i < 3; i++) {
        await tester.tap(byKey('tour/next'));
        await tester.pumpAndSettle();
      }
      expect(closed, 1);
    });

    testWidgets('Skip closes it', (tester) async {
      var closed = 0;
      await _pump(
        tester,
        HelpTourScreen(
          title: 'Backups',
          steps: steps(3),
          onClose: () => closed++,
        ),
      );
      await tester.tap(byKey('tour/skip'));
      await tester.pumpAndSettle();
      expect(closed, 1);
    });

    // T12's finding: RELAY's longest Spanish tour title (relay
    // lib/app/l10n/app_es.arb `tourRemindersTitle` @ 09b28810) was cut by
    // the app bar at large text; under a back button it wraps and the bar
    // grows to hold it.
    testWidgets('a long title wraps under the back button, the bar holds it', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 3
        ..physicalSize = const Size(360, 780) * 3;
      addTearDown(tester.view.reset);
      await pumpHome(tester, const Scaffold(), textScale: 2);
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => HelpTourScreen(
                  title: 'Recordatorios y repeticiones',
                  steps: steps(3),
                  onClose: () {},
                ),
              ),
            ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      final title = find.descendant(
        of: find.text('Recordatorios y repeticiones'),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(paragraph.didExceedMaxLines, isFalse, reason: 'no ellipsis');
      final bar = tester.getRect(find.byType(AppBar));
      final text = tester.getRect(title);
      expect(bar.height, greaterThan(kToolbarHeight));
      expect(text.top, greaterThanOrEqualTo(bar.top));
      expect(text.bottom, lessThanOrEqualTo(bar.bottom));
    });

    testWidgets('a title that fits keeps the standard bar', (tester) async {
      await _pump(
        tester,
        HelpTourScreen(title: 'Backups', steps: steps(3), onClose: () {}),
      );
      expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
    });

    testWidgets('a tour with no steps yet is its bar alone', (tester) async {
      await _pump(
        tester,
        HelpTourScreen(title: 'Backups', steps: const [], onClose: () {}),
      );
      expect(find.text('Backups'), findsOneWidget);
      expect(find.byType(TourPlayer), findsNothing);
    });
  });

  group('a how-to', () {
    testWidgets('is its title and numbered steps, each read as "Step n"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _howTo());
      expect(
        find.text(
          'Change the language of the whole app, even its first screens',
        ),
        findsOneWidget,
      );
      for (final (i, step) in _steps.indexed) {
        expect(find.text(step), findsOneWidget);
        expect(find.text('${i + 1}'), findsOneWidget);
        expect(find.bySemanticsLabel('Step ${i + 1}: $step'), findsOneWidget);
      }
      semantics.dispose();
    });

    testWidgets('then its worked examples: where, the text to type in the '
        'monospace face, and what you get, each read as one sentence', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _howTo());
      await tester.scrollUntilVisible(find.text('Examples'), 200);
      expect(find.text('Examples'), findsOneWidget);
      for (final (i, e) in _examples.indexed) {
        final row = byKey('help/example/${i + 1}');
        await tester.scrollUntilVisible(row, 200);
        final shown = e.breakable ? breakableSyntax(e.input) : e.input;
        final input = find.descendant(of: row, matching: find.text(shown));
        expect(input, findsOneWidget, reason: e.input);
        expect(
          tester.widget<Text>(input).style?.fontFamily,
          e.typed
              ? ApsiraFonts.monoQualified
              : isNot(ApsiraFonts.monoQualified),
          reason: 'typed text is monospace, taps the body face',
        );
        expect(
          find.descendant(of: row, matching: find.text(e.result)),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('${e.how}: ${e.input}. You get: ${e.result}'),
          findsOneWidget,
        );
      }
      expect(find.text('You get'), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('without examples there is no examples card', (tester) async {
      await _pump(tester, _howTo(examples: const []));
      expect(find.text('Examples'), findsNothing);
    });

    testWidgets('is safe at large text: its steps and examples wrap, '
        'nothing is clipped and nothing scrolls sideways', (tester) async {
      await expectLayoutSound(
        tester,
        _howTo,
        host: const LayoutHost(
          localizationsDelegates: delegates,
          supportedLocales: [Locale('en'), Locale('es')],
          forbidSideways: true,
        ),
      );
    });

    test('a condition may break after its key or before a comparison, '
        'invisibly', () {
      expect(breakableSyntax('due<7d -is:done'), 'due​<7d -is:​done');
      expect(breakableSyntax('priority>=high'), 'priority​>=high');
    });
  });

  test('the paths are /help/tour/<id> and /help/howto/<id>', () {
    expect(helpTourPath('powerSyntax'), '/help/tour/powerSyntax');
    expect(helpHowToPath('language'), '/help/howto/language');
    expect(HelpKeys.tour('basic'), const Key('help/tour/basic'));
    expect(HelpKeys.howTo('pin'), const Key('help/howto/pin'));
  });
}
