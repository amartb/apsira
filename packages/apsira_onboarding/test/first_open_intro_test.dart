// From viaticum test/features/first_open/first_open_screen_test.dart @
// 78d38e0 (group "the intro"), with relay
// test/features/first_open/first_open_screen_test.dart @ 09b28810 (group
// "intro") and first_open_intro_underline_test.dart @ 09b28810
// (D-APK-017).
//
// The intro: the app's mark draws, its name settles, then "Developed by"
// and the Apsira Labs lockup; it ends by itself or on a tap, calling onDone
// once. Under reduce motion nothing draws or moves: a 1 s cross-fade.
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

/// The progress the mark was last built with.
double? _mark;

var _done = 0;

Future<void> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  Widget? lockup,
  Locale locale = const Locale('en'),
  String? semanticsLabel,
}) async {
  _mark = null;
  _done = 0;
  await pumpHome(
    tester,
    FirstOpenIntro(
      appTitle: 'Relay',
      mark: (progress) {
        _mark = progress;
        return Semantics(
          label: 'The Relay mark',
          child: const SizedBox.square(
            key: Key('mark'),
            dimension: FirstOpenIntro.markSize,
          ),
        );
      },
      lockup: lockup,
      semanticsLabel: semanticsLabel,
      onDone: () => _done++,
    ),
    locale: locale,
    reduceMotion: reduceMotion,
  );
}

double _opacity(WidgetTester tester, Key key) =>
    tester.widget<Opacity>(find.byKey(key)).opacity;

void main() {
  testWidgets('the mark draws, the name settles, then the lockup; it ends '
      'by itself, once', (tester) async {
    await _pump(tester);
    expect(_mark, 0);
    expect(_opacity(tester, FirstOpenIntro.creditKey), 0);
    expect(find.text('RELAY'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(_mark, closeTo(0.5, 0.01));

    await tester.pump(const Duration(milliseconds: 1700));
    expect(_mark, 1);
    expect(_opacity(tester, FirstOpenIntro.nameKey), 1);
    expect(_opacity(tester, FirstOpenIntro.creditKey), 0);

    await tester.pump(const Duration(milliseconds: 1700));
    expect(_opacity(tester, FirstOpenIntro.creditKey), 1);
    expect(_opacity(tester, FirstOpenIntro.brandKey), 0);
    expect(find.text(en.firstOpenDevelopedBy), findsOneWidget);
    expect(find.bySemanticsLabel(en.firstOpenApsiraLabs), findsOneWidget);
    expect(_done, 0);

    await tester.pump(FirstOpenIntro.fullDuration);
    await tester.pumpAndSettle();
    expect(_done, 1);
  });

  testWidgets('a tap skips it at any point, and ends it once', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(byKey('firstOpen/intro'));
    await tester.pump();
    expect(_done, 1);
    await tester.pump(FirstOpenIntro.fullDuration);
    expect(_done, 1, reason: 'the animation stopped at the tap');
  });

  testWidgets('reduce motion gives the cross-fade, nothing drawn or moved', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: true);
    expect(_mark, 1);
    expect(_opacity(tester, FirstOpenIntro.nameKey), 1);
    expect(_opacity(tester, FirstOpenIntro.brandKey), 1);
    expect(_opacity(tester, FirstOpenIntro.creditKey), 0);
    final at0 = tester.getTopLeft(byKey('mark'));

    await tester.pump(const Duration(milliseconds: 1500));
    expect(_mark, 1);
    expect(tester.getTopLeft(byKey('mark')), at0, reason: 'nothing moves');
    expect(_opacity(tester, FirstOpenIntro.creditKey), closeTo(0.5, 0.01));
    expect(
      _opacity(tester, FirstOpenIntro.brandKey) +
          _opacity(tester, FirstOpenIntro.creditKey),
      closeTo(1, 0.01),
    );

    await tester.pump(FirstOpenIntro.reducedDuration);
    await tester.pumpAndSettle();
    expect(_done, 1);
  });

  testWidgets('TalkBack hears a button that skips it, and the mark', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(
      tester.getSemantics(byKey('firstOpen/intro')),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        hint: en.firstOpenIntroSkipHint,
      ),
    );
    expect(find.bySemanticsLabel('The Relay mark'), findsOneWidget);
    semantics.dispose();
    await tester.tap(byKey('firstOpen/intro'));
  });

  testWidgets('with the app\'s label, TalkBack hears a labelled button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, semanticsLabel: 'Skip the introduction');
    expect(
      tester.getSemantics(byKey('firstOpen/intro')),
      isSemantics(
        label: 'Skip the introduction',
        isButton: true,
        hasTapAction: true,
        hint: en.firstOpenIntroSkipHint,
      ),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    await tester.tap(byKey('firstOpen/intro'));
  });

  testWidgets('in Spanish: Desarrollado por, and the hint', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('es'));
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.text('Desarrollado por'), findsOneWidget);
    expect(
      tester.getSemantics(byKey('firstOpen/intro')),
      isSemantics(hint: 'Toca para saltar'),
    );
    semantics.dispose();
    await tester.tap(byKey('firstOpen/intro'));
  });

  testWidgets('the lockup is apsira_ui\'s reversed lockup by default', (
    tester,
  ) async {
    await _pump(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, ApsiraBrand.lockupReversed);
    expect(image.width, FirstOpenIntro.lockupWidth);
    await tester.tap(byKey('firstOpen/intro'));
  });

  testWidgets('a supplied lockup is shown in its place', (tester) async {
    await _pump(tester, lockup: const SizedBox(key: Key('apsira-lockup')));
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.byKey(const Key('apsira-lockup')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(byKey('firstOpen/intro'));
  });

  testWidgets('it sits on a Material and no text is underlined', (
    tester,
  ) async {
    await _pump(tester, lockup: const SizedBox());
    await tester.pump(const Duration(milliseconds: 4200));
    final intro = find.byType(FirstOpenIntro);
    final texts = find.descendant(of: intro, matching: find.byType(Text));
    expect(texts, findsWidgets);
    for (final element in texts.evaluate()) {
      final text = element.widget as Text;
      final style = DefaultTextStyle.of(element).style.merge(text.style);
      expect(
        style.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: '"${text.data}" is decorated',
      );
    }
    await tester.tap(byKey('firstOpen/intro'));
  });

  testWidgets('it is on the dark ground in the light theme too', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ApsiraThemeData.light,
        localizationsDelegates: delegates,
        home: FirstOpenIntro(
          appTitle: 'Relay',
          mark: (_) => const SizedBox.square(dimension: 120),
          lockup: const SizedBox(),
          onDone: () {},
        ),
      ),
    );
    final ground = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(FirstOpenIntro),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(ground.color, ApsiraTheme.dark.ground);
    await tester.tap(byKey('firstOpen/intro'));
  });
}
