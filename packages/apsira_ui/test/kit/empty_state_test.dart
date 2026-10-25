// From lyceum test/widgets/kit/forms_states_test.dart @ 9f4ff27 (the
// EmptyState group: the card, its tile, title and message, the tonal pill)
// and relay test/app/theme/empty_state_test.dart @ 09b28810 (the action as a
// labelled 48 dp button, none without one, TalkBack's order), on the kit's
// `actionLabel`/`onAction` (D-APK-014).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The card [of] draws: the first `Material` under it with rounded corners.
Finder _card(Finder of) => find
    .descendant(
      of: of,
      matching: find.byWidgetPredicate(
        (w) => w is Material && w.shape is RoundedRectangleBorder,
      ),
    )
    .first;

/// Checks [card] is an Apsira group card: `surface`, a 1 px `border` and the
/// `ApsiraRadii.groupCard` corners.
void _expectGroupCard(WidgetTester tester, Finder card, ApsiraTheme t) {
  final material = tester.widget<Material>(card);
  expect(material.color, t.surface);
  final border = material.shape! as RoundedRectangleBorder;
  expect(border.borderRadius, BorderRadius.circular(ApsiraRadii.groupCard));
  expect(border.side.color, t.border);
  expect(border.side.width, 1);
}

/// The `Material` a button paints its body with.
Material _buttonMaterial(WidgetTester tester, Finder button) =>
    tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first,
    );

void main() {
  inlineTests();

  testBothModes('the empty state is a card and keeps its action', (
    tester,
    b,
  ) async {
    var tapped = 0;
    await pumpKit(
      tester,
      EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Nothing yet',
        message: 'Capture something',
        family: ApsiraFamily.blue,
        actionLabel: 'Add',
        onAction: () => tapped++,
      ),
      brightness: b,
    );
    final t = tokensAt(tester, find.byType(EmptyState));
    final card = _card(find.byType(EmptyState));
    _expectGroupCard(tester, card, t);

    // The icon tile, the title, the message: all inside the card.
    final tile = find.descendant(of: card, matching: find.byType(IconBox));
    expect(tile, findsOneWidget);
    expect(tester.widget<IconBox>(tile).family, ApsiraFamily.blue);
    final title = tester.widget<Text>(find.text('Nothing yet')).style!;
    expect(title.fontSize, ApsiraTypography.cardTitle.fontSize);
    expect(title.color, t.ink);
    expect(
      tester.getSemantics(find.text('Nothing yet')),
      matchesSemantics(label: 'Nothing yet', isHeader: true),
    );
    expect(
      tester.widget<Text>(find.text('Capture something')).style!.color,
      t.ink2,
    );

    // The action is drawn as the tonal pill, at least 48 dp tall.
    final action = find.descendant(of: card, matching: find.byType(TextButton));
    expect(action, findsOneWidget);
    final body = _buttonMaterial(tester, action);
    expect(body.color, t.tint);
    expect((body.shape! as StadiumBorder).side.color, t.border);
    expect(textColor(tester, 'Add'), t.ink);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Add'));
    expect(tapped, 1);
  });

  testWidgets('without an action it is the card alone', (tester) async {
    await pumpKit(
      tester,
      const EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Nothing yet',
        actionLabel: 'Add',
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Add'), findsNothing);
  });

  testWidgets('the action keeps the key the screen gives it', (tester) async {
    const key = ValueKey('emptyAction');
    await pumpKit(
      tester,
      EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Nothing yet',
        actionLabel: 'Add',
        onAction: () {},
        actionKey: key,
      ),
    );
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('TalkBack reads the title, then the action as a button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpKit(
      tester,
      EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Nothing due today',
        actionLabel: 'Add task',
        onAction: () {},
      ),
    );
    expect(find.semantics.byLabel('Nothing due today'), findsOne);
    expect(
      tester.getSemantics(find.widgetWithText(TextButton, 'Add task')),
      isSemantics(
        label: 'Add task',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the action carries its icon before the label', (tester) async {
    await pumpKit(
      tester,
      EmptyState(
        icon: ApsiraIcons.folder,
        title: 'No figures yet',
        actionLabel: 'Add figure',
        actionIcon: ApsiraIcons.plus,
        onAction: () {},
      ),
    );
    final action = find.byType(TextButton);
    final glyph = find.descendant(
      of: action,
      matching: find.byIcon(ApsiraIcons.plus),
    );
    expect(glyph, findsOneWidget);
    expect(tester.widget<Icon>(glyph).size, 20);
    expect(
      tester.getTopLeft(glyph).dx,
      lessThan(tester.getTopLeft(find.text('Add figure')).dx),
    );
    // Still the tonal pill, at least 48 dp tall.
    final t = tokensAt(tester, find.byType(EmptyState));
    expect(_buttonMaterial(tester, action).color, t.tint);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
  });

  testWidgets('a second action sits under the first, both tonal pills', (
    tester,
  ) async {
    var opened = 0;
    var cancelled = 0;
    const cancelKey = ValueKey('cancel');
    await pumpKit(
      tester,
      EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Microphone access',
        message: 'Lyceum records voice captures.',
        actionLabel: 'Open settings',
        onAction: () => opened++,
        secondaryActionLabel: 'Cancel',
        onSecondaryAction: () => cancelled++,
        secondaryActionKey: cancelKey,
      ),
    );
    final card = _card(find.byType(EmptyState));
    final buttons = find.descendant(
      of: card,
      matching: find.byType(TextButton),
    );
    expect(buttons, findsNWidgets(2));
    expect(find.byKey(cancelKey), findsOneWidget);
    final t = tokensAt(tester, find.byType(EmptyState));
    expect(_buttonMaterial(tester, find.byKey(cancelKey)).color, t.tint);
    expect(
      tester.getTopLeft(find.byKey(cancelKey)).dy,
      greaterThan(tester.getBottomLeft(buttons.first).dy),
    );
    await tester.tap(find.text('Cancel'));
    expect((opened, cancelled), (0, 1));
    await tester.tap(find.text('Open settings'));
    expect((opened, cancelled), (1, 1));
  });

  testWidgets('without its callback the second action is not drawn', (
    tester,
  ) async {
    await pumpKit(
      tester,
      const EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Nothing yet',
        secondaryActionLabel: 'Cancel',
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('the compact empty state is a card too', (tester) async {
    await pumpKit(
      tester,
      const EmptyState(icon: ApsiraIcons.folder, title: 'None', compact: true),
    );
    final t = tokensAt(tester, find.byType(EmptyState));
    _expectGroupCard(tester, _card(find.byType(EmptyState)), t);
    expect(tester.widget<IconBox>(find.byType(IconBox)).size, 36);
  });

  testWidgets('the empty state is sound at large text, EN and ES', (
    tester,
  ) async {
    await expectKitLayoutSound(
      tester,
      () => EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Ningún resultado para tipo:tarea vence:hoy',
        message: 'Las tareas que vencen hoy aparecen aquí',
        actionLabel: 'Editar filtro',
        onAction: () {},
      ),
    );
  });

  testWidgets('with its icon and a second action: sound at large text, EN '
      'and ES', (tester) async {
    await expectKitLayoutSound(
      tester,
      () => EmptyState(
        icon: ApsiraIcons.folder,
        title: 'Acceso al micrófono',
        message: 'Lyceum usa el micrófono para grabar capturas de voz',
        actionLabel: 'Abrir los ajustes del sistema',
        actionIcon: ApsiraIcons.plus,
        onAction: () {},
        secondaryActionLabel: 'Cancelar',
        onSecondaryAction: () {},
      ),
    );
  });
}

// RELAY's inline variant, from relay test/app/theme/empty_state_test.dart @
// 09b28810: a bordered `tint` block (D-066) with an icon tile, the line in
// `ink2` and the action as an `accentText` text button, at least 48 dp;
// TalkBack reads the line, then the action. No card.
void inlineTests() {
  const line = 'Nothing due today · tasks due today go here';

  testBothModes('inline: a bordered tint block, its tile, line and action', (
    tester,
    b,
  ) async {
    var taps = 0;
    await pumpKit(
      tester,
      EmptyState.inline(
        icon: ApsiraIcons.folder,
        title: line,
        actionLabel: 'Add task',
        onAction: () => taps++,
        actionKey: const ValueKey('add'),
      ),
      brightness: b,
    );
    final t = tokensAt(tester, find.byType(EmptyState));
    final block = tester.widget<DecoratedBox>(find.byKey(EmptyState.blockKey));
    final shape = block.decoration as ShapeDecoration;
    expect(shape.color, t.tint);
    final border = shape.shape as RoundedRectangleBorder;
    expect(border.side.color, t.border);
    expect(border.borderRadius, BorderRadius.circular(ApsiraRadii.insetBlock));
    // No card around it.
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byWidgetPredicate(
          (w) => w is Material && w.shape is RoundedRectangleBorder,
        ),
      ),
      findsNothing,
    );

    final tile = tester.widget<DecoratedBox>(
      find.byKey(EmptyState.iconTileKey),
    );
    expect((tile.decoration as ShapeDecoration).color, t.surface);
    expect(
      tester.getSize(find.byKey(EmptyState.iconTileKey)),
      const Size(36, 36),
    );
    final icon = tester.widget<Icon>(find.byIcon(ApsiraIcons.folder));
    expect((icon.size, icon.color), (18, t.accentText));
    expect(tester.widget<Text>(find.text(line)).style!.color, t.ink2);

    final action = find.byKey(const ValueKey('add'));
    expect(textColor(tester, 'Add task'), t.accentText);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await tester.tap(action);
    expect(taps, 1);
  });

  testWidgets('inline: without an action it is the line alone', (tester) async {
    await pumpKit(
      tester,
      const EmptyState.inline(
        icon: ApsiraIcons.folder,
        title: line,
        actionLabel: 'Add task',
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(find.text(line), findsOneWidget);
  });

  testWidgets('inline: TalkBack reads the line, then the action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpKit(
      tester,
      EmptyState.inline(
        icon: ApsiraIcons.folder,
        title: line,
        actionLabel: 'Add task',
        onAction: () {},
      ),
    );
    expect(find.semantics.byLabel(line), findsOne);
    expect(
      tester.getSemantics(find.widgetWithText(TextButton, 'Add task')),
      isSemantics(
        label: 'Add task',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('inline: sound at large text, EN and ES', (tester) async {
    await expectKitLayoutSound(
      tester,
      () => EmptyState.inline(
        icon: ApsiraIcons.folder,
        title: 'Ningún resultado para tipo:tarea vence:hoy',
        actionLabel: 'Editar filtro',
        onAction: () {},
      ),
    );
  });
}
