// From relay test/app/theme/tour/tour_player_test.dart @ 09b28810, with
// viaticum test/app/theme/tour/tour_player_test.dart @ 78d38e0's step keys
// and taps (D-APK-017).
//
// The tour player: one step at a time (its scene, title and body), page dots
// read as "Step n of m", Skip, Back and Next (Done on the last), an optional
// secondary action on the last step; tap targets of 48 dp; under reduce
// motion every scene shows its end state and nothing animates; TalkBack
// reads the title, the body and the scene's summary; the primary action is
// the one accent fill. VIATICUM's taps: under the body, each path the step
// teaches as one row of the app's own labels, which wraps instead of
// scrolling sideways and which TalkBack reads as one sentence.
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

/// The progress each scene was last built with, by step.
final _progress = <int, double>{};

/// Step 1 teaches two paths; the others none.
TourStepData _step(int i) => TourStepData(
  title: 'Title $i',
  body: 'Body $i',
  summary: 'Scene $i shows something',
  taps: i == 1
      ? const [
          ['Trips', 'Import package'],
          ['Settings', 'Help'],
        ]
      : const [],
  scene: (context, progress) => AnimatedBuilder(
    animation: progress,
    builder: (_, _) {
      _progress[i] = progress.value;
      return SizedBox(
        width: 200,
        height: 80,
        child: Text('scene $i', key: ValueKey('scene/$i')),
      );
    },
  ),
);

final _steps = [for (var i = 0; i < 3; i++) _step(i)];

final _calls = <String>[];

Future<void> _pump(
  WidgetTester tester, {
  List<TourStepData>? steps,
  bool reduceMotion = false,
  String? secondary,
  VoidCallback? onBackFromFirst,
  int initialStep = 0,
  String keyPrefix = 'tour',
  Locale locale = const Locale('en'),
  bool withSkip = true,
  String Function(List<String> path)? tapPathLabel,
}) async {
  _calls.clear();
  _progress.clear();
  await pumpHome(
    tester,
    Scaffold(
      body: TourPlayer(
        steps: steps ?? _steps,
        onDone: () => _calls.add('done'),
        onSkip: withSkip ? () => _calls.add('skip') : null,
        secondaryLabel: secondary,
        onSecondary: secondary == null ? null : () => _calls.add('secondary'),
        onBackFromFirst: onBackFromFirst,
        initialStep: initialStep,
        onStep: (i) => _calls.add('step $i'),
        keyPrefix: keyPrefix,
        tapPathLabel: tapPathLabel,
      ),
    ),
    locale: locale,
    reduceMotion: reduceMotion,
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one step at a time: Next walks on, Back walks back, Done on '
      'the last ends the tour', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Title 0'), findsOneWidget);
    expect(find.text('Body 0'), findsOneWidget);
    expect(find.text('Title 1'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    // No way back from the first step unless the caller gives one.
    expect(byKey('tour/back'), findsNothing);

    await _tap(tester, 'tour/next');
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Title 0'), findsNothing);
    await _tap(tester, 'tour/back');
    expect(find.text('Title 0'), findsOneWidget);
    await _tap(tester, 'tour/next');
    await _tap(tester, 'tour/next');
    expect(find.text('Title 2'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(_calls, ['step 1', 'step 0', 'step 1', 'step 2']);

    await _tap(tester, 'tour/next');
    expect(_calls.last, 'done');
    expect(find.text('Title 2'), findsOneWidget, reason: 'the caller moves');
  });

  testWidgets('each step is keyed <prefix>/step/<n>', (tester) async {
    await _pump(tester, initialStep: 2);
    await tester.pumpAndSettle();
    expect(byKey('tour/step/2'), findsOneWidget);
    expect(find.text('Title 2'), findsOneWidget);
    expect(byKey('tour/step/0'), findsNothing);
  });

  testWidgets('Skip ends the tour from any step', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    await _tap(tester, 'tour/next');
    await _tap(tester, 'tour/skip');
    expect(_calls, ['step 1', 'skip']);
  });

  testWidgets('without onSkip there is no Skip', (tester) async {
    await _pump(tester, withSkip: false);
    await tester.pumpAndSettle();
    expect(byKey('tour/skip'), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('Back on the first step goes to onBackFromFirst when given', (
    tester,
  ) async {
    var back = 0;
    await _pump(tester, onBackFromFirst: () => back++);
    await tester.pumpAndSettle();
    await _tap(tester, 'tour/back');
    expect(back, 1);
    expect(find.text('Title 0'), findsOneWidget);
  });

  testWidgets('the secondary action shows on the last step only', (
    tester,
  ) async {
    await _pump(tester, secondary: 'Show me more', initialStep: 1);
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Show me more'), findsNothing);
    await _tap(tester, 'tour/next');
    expect(find.text('Show me more'), findsOneWidget);
    await _tap(tester, 'tour/secondary');
    expect(_calls, ['step 2', 'secondary']);
  });

  testWidgets('keys follow keyPrefix', (tester) async {
    await _pump(tester, keyPrefix: 'firstOpen');
    await tester.pumpAndSettle();
    expect(byKey('firstOpen/skip'), findsOneWidget);
    expect(byKey('firstOpen/next'), findsOneWidget);
    expect(byKey('firstOpen/step/0'), findsOneWidget);
    expect(byKey('tour/next'), findsNothing);
  });

  testWidgets('every control is at least 48 × 48 dp', (tester) async {
    await _pump(
      tester,
      secondary: 'Show me more',
      onBackFromFirst: () {},
      initialStep: 2,
    );
    await tester.pumpAndSettle();
    for (final key in [
      'tour/skip',
      'tour/back',
      'tour/next',
      'tour/secondary',
    ]) {
      final size = tester.getSize(byKey(key));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets('with full motion the scene plays from its start to its end', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump();
    expect(_progress[0], lessThan(0.1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(_progress[0], 1.0);
  });

  testWidgets('under reduce motion each scene shows its end state and '
      'nothing animates', (tester) async {
    await _pump(tester, reduceMotion: true);
    expect(_progress[0], 1.0);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(byKey('tour/next'));
    await tester.pump();
    // The button's ink answers the touch; the tour itself moves nothing.
    expect(_progress[1], 1.0);
    expect(find.text('Title 0'), findsNothing, reason: 'no cross-fade');
  });

  testWidgets("TalkBack reads the title, the body, the scene's summary and "
      'the progress', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Title 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Body 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Scene 0 shows something'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    // The scene's own widgets are pictures, not controls.
    expect(find.bySemanticsLabel('scene 0'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Spanish words for the controls and the progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('es'), initialStep: 2);
    await tester.pumpAndSettle();
    expect(find.text('Saltar'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 3 de 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the primary action is the one accent fill', (tester) async {
    await _pump(tester, secondary: 'More', initialStep: 2);
    await tester.pumpAndSettle();
    final tokens = ApsiraTheme.of(tester.element(byKey('tour/next')));
    Color? fill(String key) {
      final material = tester.widget<Material>(
        find.descendant(of: byKey(key), matching: find.byType(Material)).first,
      );
      return material.color;
    }

    expect(fill('tour/next'), tokens.accentFill);
    for (final key in ['tour/skip', 'tour/secondary']) {
      expect(fill(key), anyOf(isNull, const Color(0x00000000)), reason: key);
    }
  });

  group('the taps', () {
    testWidgets('each path is a row of its labels under the body', (
      tester,
    ) async {
      await _pump(tester, initialStep: 1);
      await tester.pumpAndSettle();
      for (final (i, path) in _steps[1].taps.indexed) {
        final row = byKey('tour/taps/$i');
        expect(row, findsOneWidget);
        for (final label in path) {
          expect(
            find.descendant(of: row, matching: find.text(label)),
            findsOneWidget,
            reason: label,
          );
        }
        expect(
          tester.getTopLeft(row).dy,
          greaterThan(tester.getBottomLeft(find.text('Body 1')).dy - 1),
          reason: 'under the body',
        );
      }
      expect(byKey('tour/taps/2'), findsNothing);
    });

    testWidgets('a step that teaches no taps shows none', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      expect(byKey('tour/taps/0'), findsNothing);
    });

    testWidgets('a long path wraps; it never scrolls sideways', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      const path = [
        'Ajustes y preferencias del viaje',
        'Copias de seguridad',
        'Restaurar desde una copia de seguridad…',
      ];
      await _pump(
        tester,
        steps: [
          TourStepData(
            title: 'T',
            body: 'B',
            summary: 'S',
            taps: const [path],
            scene: (_, _) => const SizedBox(height: 40),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final row = byKey('tour/taps/0');
      expect(
        find.descendant(of: row, matching: find.byType(Scrollable)),
        findsNothing,
      );
      final first = tester.getTopLeft(find.text(path.first)).dy;
      final last = tester.getTopLeft(find.text(path.last)).dy;
      expect(last, greaterThan(first), reason: 'the last label on a new run');
      expect(tester.getTopRight(row).dx, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });

    testWidgets("TalkBack reads each path as one sentence, the app's", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        initialStep: 1,
        tapPathLabel: (path) => 'Tap ${path.join(', then ')}',
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Tap Trips, then Import package'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Tap Settings, then Help'), findsOneWidget);
      // The labels are read inside the sentence, not one by one.
      expect(find.bySemanticsLabel('Trips'), findsNothing);
      semantics.dispose();
    });

    testWidgets('without tapPathLabel the labels are read in order', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, initialStep: 1);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Trips, Import package'), findsOneWidget);
      semantics.dispose();
    });
  });
}
