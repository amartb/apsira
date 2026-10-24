// AC-12.4 (D-APK-017): every screen-sized widget is sound in English and
// Spanish at 100 % to 200 % text, on a common and a small phone, dark and
// light (apsira_test's expectLayoutSound; the step frame, the language step
// and Help's pages have theirs beside their other tests). From viaticum
// test/features/first_open/first_open_screen_test.dart @ 78d38e0 (group
// "large text": the intro and the tour's steps).
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';
import 'support/tour.dart';

void main() {
  testWidgets('the intro', (tester) async {
    await expectLayoutSound(
      tester,
      () => FirstOpenIntro(
        appTitle: 'Viaticum',
        mark: (_) => const SizedBox.square(dimension: FirstOpenIntro.markSize),
        onDone: () {},
      ),
      host: host,
    );
  });

  for (var step = 0; step < sampleTour.length; step++) {
    testWidgets('the tour player, step ${step + 1}', (tester) async {
      await expectLayoutSound(
        tester,
        () => sampleTourScreen(initialStep: step),
        host: const LayoutHost(
          localizationsDelegates: delegates,
          supportedLocales: [Locale('en'), Locale('es')],
          forbidSideways: true,
        ),
      );
    });
  }

  testWidgets('a tour played from Help, its last step', (tester) async {
    await expectLayoutSound(
      tester,
      () => HelpTourScreen(
        title: 'Copias de seguridad',
        steps: sampleTour,
        initialStep: sampleTour.length - 1,
        onClose: () {},
      ),
      host: host,
    );
  });
}
