// From relay test/a11y/key_screens_a11y_test.dart @ 09b28810 and lyceum
// test/a11y/key_screens_a11y_test.dart @ 9f4ff27 (its control): the three
// guidelines of the accessibility pass, each with a fixture that fails it and
// one that passes.
import 'package:apsira_test/apsira_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(loadAppFonts);

  const english = GoldenVariant(Locale('en'), Brightness.dark, 1);
  const spanish = GoldenVariant(Locale('es'), Brightness.light, 2);

  Future<TestFailure?> failureOf(Future<void> Function() run) async {
    try {
      await run();
    } on TestFailure catch (e) {
      return e;
    }
    return null;
  }

  testWidgets('a labelled 48 dp button with legible text passes', (
    tester,
  ) async {
    for (final variant in [english, spanish]) {
      await pumpGolden(
        tester,
        variant,
        Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Save')),
          ),
        ),
      );
      // Contrast at 200 % only, as the apps check it (expectAccessible).
      await expectAccessible(tester, textContrast: variant.textScale > 1);
    }
  });

  testWidgets('an unlabelled button fails the labelled-tap guideline', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      english,
      Scaffold(
        body: Center(
          child: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ),
      ),
    );
    final failure = await failureOf(() => expectAccessible(tester));
    expect(failure, isNotNull);
    expect(failure!.message, contains('label'));
  });

  testWidgets('a 40 dp button fails the tap-target guideline', (tester) async {
    await pumpGolden(
      tester,
      english,
      Scaffold(
        body: Center(
          child: IconButton(
            tooltip: 'Add',
            onPressed: () {},
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size.square(40),
              maximumSize: const Size.square(40),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
    final failure = await failureOf(() => expectAccessible(tester));
    expect(failure, isNotNull);
    expect(failure!.message, contains('48'));
  });

  testWidgets('faint text fails the contrast guideline, unless it is off', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      spanish,
      const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(
          child: Text('Faint', style: TextStyle(color: Color(0xFFDDDDDD))),
        ),
      ),
    );
    final failure = await failureOf(() => expectAccessible(tester));
    expect(failure, isNotNull);
    expect(failure!.message, contains('contrast'));
    await expectAccessible(tester, textContrast: false);
  });
}
