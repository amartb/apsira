// From lyceum test/screens/onboarding/small_screen_layout_test.dart @
// 9f4ff27 and viaticum test/features/first_open/first_open_screen_test.dart
// @ 78d38e0 (group "large text"), for the frame both apps' steps share
// (D-APK-017): the gutter, the step's content filling the screen with its
// actions at the bottom, and a scroll in place of an overflow when large
// text makes it taller.
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

final _calls = <String>[];

Widget _frame({
  bool back = true,
  bool skip = true,
  String? primaryLabel,
  int lines = 1,
}) => Scaffold(
  body: StepFrame(
    onBack: back ? () => _calls.add('back') : null,
    onSkip: skip ? () => _calls.add('skip') : null,
    primaryLabel: primaryLabel,
    onPrimary: () => _calls.add('primary'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        for (var i = 0; i < lines; i++)
          Text('A line of the step that says what it is for, $i'),
        const Spacer(),
      ],
    ),
  ),
);

void main() {
  setUp(_calls.clear);

  testWidgets('Back, Skip and the primary action call back; Continue by '
      'default', (tester) async {
    await pumpHome(tester, _frame());
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(byKey('firstOpen/back'));
    await tester.tap(byKey('firstOpen/skip'));
    await tester.tap(byKey('firstOpen/continue'));
    expect(_calls, ['back', 'skip', 'primary']);
  });

  testWidgets('without onBack or onSkip there is no Back or Skip', (
    tester,
  ) async {
    await pumpHome(tester, _frame(back: false, skip: false));
    expect(byKey('firstOpen/back'), findsNothing);
    expect(byKey('firstOpen/skip'), findsNothing);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('the primary label is the given one, in Spanish the shared '
      'words', (tester) async {
    await pumpHome(tester, _frame(primaryLabel: 'Start'));
    expect(find.text('Start'), findsOneWidget);
    await pumpHome(tester, _frame(), locale: const Locale('es'));
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
  });

  testWidgets('the primary action is the accent pill at the bottom, Skip at '
      'the top end', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await pumpHome(tester, _frame());
    final primary = tester.getRect(byKey('firstOpen/continue'));
    expect(primary.bottom, closeTo(844 - ApsiraSpacing.screenGutter, 1));
    expect(primary.height, greaterThanOrEqualTo(48));
    final skip = tester.getRect(byKey('firstOpen/skip'));
    expect(skip.right, closeTo(390 - ApsiraSpacing.screenGutter, 1));
    expect(skip.top, closeTo(ApsiraSpacing.screenGutter, 1));
    final material = tester.widget<Material>(
      find
          .descendant(
            of: byKey('firstOpen/continue'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, ApsiraTheme.dark.accentFill);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.maxScrollExtent, 0, reason: 'a step that fits');
  });

  testWidgets('a step taller than the screen scrolls; nothing overflows', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    await pumpHome(tester, _frame(lines: 30), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
    await tester.ensureVisible(byKey('firstOpen/continue'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('firstOpen/continue'));
    expect(_calls, ['primary']);
  });

  testWidgets('is sound at large text, in English and Spanish', (tester) async {
    await expectLayoutSound(tester, () => _frame(lines: 4), host: host);
  });
}
