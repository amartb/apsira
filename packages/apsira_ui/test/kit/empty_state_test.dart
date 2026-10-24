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
}
