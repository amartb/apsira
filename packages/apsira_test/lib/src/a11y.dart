// From relay test/a11y/key_screens_a11y_test.dart @ 09b28810 and lyceum
// test/a11y/key_screens_a11y_test.dart @ 9f4ff27: the three guidelines each
// key screen is held to, as one call.

/// The accessibility pass of a pumped screen. See the package README,
/// "Accessibility".
library;

import 'package:flutter_test/flutter_test.dart';

/// Expects the screen [tester] has pumped to meet Flutter's accessibility
/// guidelines: every tap target labelled (`labeledTapTargetGuideline`) and
/// at least Android's 48 × 48 dp (`androidTapTargetGuideline`), and, when
/// [textContrast], its text at WCAG AA contrast (`textContrastGuideline`).
///
/// Semantics are turned on for the check. The apps check contrast at 200 %
/// only: the guideline samples rendered pixels over a node's whole rect, and
/// at 100 % it measures anti-aliased strokes rather than the colours drawn
/// (the token pairs themselves are proved in apsira_ui's tokens_contrast).
Future<void> expectAccessible(
  WidgetTester tester, {
  bool textContrast = true,
}) async {
  final semantics = tester.ensureSemantics();
  try {
    await tester.pump();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    if (textContrast) {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
  } finally {
    semantics.dispose();
  }
}
