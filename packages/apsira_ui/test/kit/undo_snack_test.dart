// From relay lib/features/home/ui/home_screen.dart `_showUndo` and
// lib/features/notes_list/ui/list_dialogs.dart `showListSnack` @ 09b28810
// (hide the current snack, the message, Undo for 5 s) and viaticum
// lib/features/archives/ui/archive_people_sheets.dart `showUndoSnack` @
// 78d38e0 (the failure snack when the undo could not write), D-APK-014.
// Neither app tested its helper on its own; these are the kit's tests.
import 'dart:async';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Pumps a scaffold whose button shows the undo snack with [onUndo].
Future<void> _pump(
  WidgetTester tester,
  FutureOr<bool> Function() onUndo, {
  String? undoFailedMessage,
  bool? persist,
  Locale locale = const Locale('en'),
}) async {
  await pumpKit(
    tester,
    opener(
      'act',
      (ctx) => showUndoSnack(
        ScaffoldMessenger.of(ctx),
        message: 'Task done',
        onUndo: onUndo,
        undoFailedMessage: undoFailedMessage,
        persist: persist,
      ),
    ),
    locale: locale,
  );
  await tester.tap(find.text('act'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Undo calls onUndo once and shows nothing more on true', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, () {
      calls++;
      return true;
    }, undoFailedMessage: 'Could not undo');
    expect(find.text('Task done'), findsOneWidget);
    // A second tap while the snack is still leaving calls nothing.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.tap(find.text('Undo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Could not undo'), findsNothing);
  });

  testWidgets('a failed undo shows undoFailedMessage', (tester) async {
    await _pump(tester, () async => false, undoFailedMessage: 'Could not undo');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Could not undo'), findsOneWidget);
    expect(find.text('Task done'), findsNothing);
    final failure = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(failure.action, isNull);
    expect(failure.duration, const Duration(seconds: 5));
  });

  testWidgets('a failed undo without a message shows nothing', (tester) async {
    await _pump(tester, () => false);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the snack replaces the current one and lasts 5 s', (
    tester,
  ) async {
    await pumpKit(
      tester,
      opener('act', (ctx) {
        final messenger = ScaffoldMessenger.of(ctx)
          ..showSnackBar(const SnackBar(content: Text('Older')));
        showUndoSnack(messenger, message: 'Task done', onUndo: () => true);
      }),
    );
    await tester.tap(find.text('act'));
    await tester.pumpAndSettle();
    expect(find.text('Older'), findsNothing);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.duration, const Duration(seconds: 5));
    // RELAY's: Flutter's default, a snack with an action stays.
    expect(snack.persist, isTrue);
  });

  testWidgets('persist: false dismisses after its duration (VIATICUM)', (
    tester,
  ) async {
    await _pump(tester, () => true, persist: false);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the Undo label defaults to ApsiraL10n (es)', (tester) async {
    await _pump(tester, () => true, locale: const Locale('es'));
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testBothModes('the snack takes the shared snack theme', (tester, b) async {
    await pumpKit(
      tester,
      opener(
        'act',
        (ctx) => showUndoSnack(
          ScaffoldMessenger.of(ctx),
          message: 'Task done',
          onUndo: () => true,
        ),
      ),
      brightness: b,
    );
    await tester.tap(find.text('act'));
    await tester.pumpAndSettle();
    final t = tokensAt(tester, find.text('act'));
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, t.surface);
    expect(textColor(tester, 'Undo'), t.accentText);
  });

  testWidgets('the undo snack is sound at large text, EN and ES', (
    tester,
  ) async {
    await expectKitLayoutSound(tester, () => const _ShowsSnack());
  });
}

/// A scaffold that shows the undo snack once it is built.
class _ShowsSnack extends StatefulWidget {
  const _ShowsSnack();

  @override
  State<_ShowsSnack> createState() => _ShowsSnackState();
}

class _ShowsSnackState extends State<_ShowsSnack> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showUndoSnack(
        ScaffoldMessenger.of(context),
        message: 'Se completaron tres tareas de la lista de hoy',
        onUndo: () => true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}
