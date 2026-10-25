// From lyceum test/widgets/kit/kit_widgets_test.dart @ 9f4ff27 (the
// Overlays group: confirmDestructive, the sheet's handle, title and body,
// the root navigator), with the barrier case, the Spanish default labels
// and the surfaces drawn from the tokens under plain `build` (D-APK-014).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The `Material` the open sheet or dialog paints its surface with.
Material _surface(WidgetTester tester, Type of) => tester.widget<Material>(
  find.descendant(of: find.byType(of), matching: find.byType(Material)).first,
);

/// The barrier of the route on top.
Color? _barrier(WidgetTester tester) =>
    tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).last.color;

void main() {
  group('confirmDestructive', () {
    Future<bool?> run(
      WidgetTester tester,
      Future<void> Function() close, {
      Brightness b = Brightness.dark,
    }) async {
      bool? result;
      await pumpKit(
        tester,
        opener('go', (ctx) async {
          result = await confirmDestructive(
            ctx,
            title: 'Delete source?',
            confirmLabel: 'Delete source',
          );
        }),
        brightness: b,
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await close();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('resolves true on confirm', (tester) async {
      expect(
        await run(tester, () => tester.tap(find.text('Delete source'))),
        isTrue,
      );
    });

    testWidgets('resolves false on cancel', (tester) async {
      expect(await run(tester, () => tester.tap(find.text('Cancel'))), isFalse);
    });

    testWidgets('resolves false when the barrier is tapped', (tester) async {
      expect(
        await run(tester, () => tester.tapAt(const Offset(4, 4))),
        isFalse,
      );
    });

    testBothModes('the confirm button is the error fill', (tester, b) async {
      await pumpKit(
        tester,
        opener('go', (ctx) => confirmDestructive(ctx, title: 'Delete?')),
        brightness: b,
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final t = tokensAt(tester, find.text('go'));
      final scheme = Theme.of(tester.element(find.text('go'))).colorScheme;
      final confirm = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(confirm.style?.backgroundColor?.resolve({}), scheme.error);
      expect(confirm.style?.foregroundColor?.resolve({}), scheme.onError);
      expect(
        destructiveButtonStyle(t).backgroundColor?.resolve({}),
        t.family(ApsiraFamily.redOrange).solid,
      );
    });

    testWidgets('labels default to ApsiraL10n (es)', (tester) async {
      await pumpKit(
        tester,
        opener('go', (ctx) => confirmDestructive(ctx, title: '¿Eliminar?')),
        locale: const Locale('es'),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });
  });

  group('confirmAction', () {
    testWidgets('resolves true on confirm; labels from ApsiraL10n (es)', (
      tester,
    ) async {
      bool? result;
      await pumpKit(
        tester,
        opener('go', (ctx) async {
          result = await confirmAction(ctx, title: '¿Seguir?');
        }),
        locale: const Locale('es'),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('showApsiraDialog', () {
    testWidgets('renders a String or a Widget content', (tester) async {
      await pumpKit(
        tester,
        opener(
          'go',
          (ctx) => showApsiraDialog<void>(
            context: ctx,
            title: 'Title',
            content: 'Body text',
            actions: (_) => [const Text('act')],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Body text'), findsOneWidget);
      expect(find.text('act'), findsOneWidget);
    });

    for (final full in [false, true]) {
      testBothModes('draws its surface from the tokens (buildFull: $full)', (
        tester,
        b,
      ) async {
        await pumpKit(
          tester,
          opener(
            'go',
            (ctx) => showApsiraDialog<void>(context: ctx, title: 'Title'),
          ),
          brightness: b,
          theme: full ? fullTheme(b) : null,
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        final t = tokensAt(tester, find.text('go'));
        final surface = _surface(tester, AlertDialog);
        expect(surface.color, t.surface);
        expect(surface.surfaceTintColor, ApsiraSchemeColors.transparent);
        expect(surface.shape, ApsiraThemeData.dialogShape(t));
        expect(_barrier(tester), t.scrim);
      });
    }
  });

  group('showApsiraSheet', () {
    testWidgets('renders handle, title and body', (tester) async {
      await pumpKit(
        tester,
        opener(
          'open',
          (ctx) => showApsiraSheet<void>(
            context: ctx,
            title: 'Filters',
            builder: (_) => const Text('sheet body'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SheetHandle), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
    });

    testWidgets('opens on the root navigator, over a nested navigator', (
      tester,
    ) async {
      final root = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ApsiraThemeData.dark,
          navigatorKey: root,
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (ctx) => TextButton(
                  onPressed: () => showApsiraSheet<void>(
                    context: ctx,
                    builder: (_) => const Text('sheet body'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final body = tester.element(find.text('sheet body'));
      expect(
        body.findAncestorStateOfType<NavigatorState>(),
        same(root.currentState),
      );
    });

    for (final full in [false, true]) {
      testBothModes('draws its surface from the tokens (buildFull: $full)', (
        tester,
        b,
      ) async {
        await pumpKit(
          tester,
          opener(
            'open',
            (ctx) => showApsiraSheet<void>(
              context: ctx,
              builder: (_) => const Text('sheet body'),
            ),
          ),
          brightness: b,
          theme: full ? fullTheme(b) : null,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final t = tokensAt(tester, find.text('open'));
        final surface = _surface(tester, BottomSheet);
        expect(surface.color, t.surface);
        expect(surface.surfaceTintColor, ApsiraSchemeColors.transparent);
        expect(
          surface.shape,
          ApsiraShapes.sheetTop.copyWith(side: BorderSide(color: t.border)),
        );
        expect(surface.clipBehavior, Clip.antiAlias);
        expect(_barrier(tester), t.scrim);
        final handle = tester.widget<Container>(
          find.descendant(
            of: find.byType(SheetHandle),
            matching: find.byType(Container),
          ),
        );
        expect((handle.decoration! as BoxDecoration).color, t.ring);
      });
    }
  });

  testWidgets('the dialog is sound at large text, EN and ES', (tester) async {
    await expectKitLayoutSound(
      tester,
      () => const ApsiraDialog(
        title: '¿Eliminar la fuente y todas sus notas?',
        content:
            'Se eliminarán la fuente, sus citas y las notas que la mencionan.',
        actions: [Text('Cancelar')],
      ),
    );
  });

  testWidgets('the sheet body is sound at large text, EN and ES', (
    tester,
  ) async {
    await expectKitLayoutSound(
      tester,
      () => const Align(
        alignment: Alignment.bottomCenter,
        child: ApsiraSheet(
          title: 'Filtros de la lista',
          scrollable: true,
          child: Text('Solo las notas con etiqueta y fecha de hoy'),
        ),
      ),
    );
  });
}
