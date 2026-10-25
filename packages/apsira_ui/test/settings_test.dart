// From relay test/app/theme/relay_menu_theme_test.dart @ 09b28810 (the menu
// widget tests, the menu rows and the paired buttons) and relay
// test/features/settings/settings_screen_test.dart @ 09b28810 (the group's
// dividers), unchanged but for names (D-APK-013). The rows' 48 dp at 200 %
// text is RELAY's own check: `apsira_test` depends on this package, so its
// layout checker cannot be used here.
//
// One popup-menu style app-wide (F8): every PopupMenuButton takes its look
// from ApsiraThemeData — the bordered `surface` (D-066) with the inset-block
// radius, rows of at least 48 dp, labels in ApsiraTypography.body that scale
// with the system text size, `line` dividers — so no call site styles its
// own menu; rows are ApsiraMenuItem (icon, danger, the chosen mark) and paired
// actions an ApsiraMenuButtons row.
import 'dart:io';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

const _archive = LucideIcons.archive;
const _trash = LucideIcons.trash;
const _undo = LucideIcons.undo_2;
const _redo = LucideIcons.redo_2;
const _theme = LucideIcons.sun_moon;

void main() {
  for (final (name, theme, t) in [
    ('dark', ApsiraThemeData.dark, ApsiraTheme.dark),
    ('light', ApsiraThemeData.light, ApsiraTheme.light),
  ]) {
    group('$name popup menu theme', () {
      testWidgets('an unstyled PopupMenuButton draws it', (tester) async {
        await _open(tester, theme, 1);
        final material = tester.widget<Material>(
          find
              .ancestor(
                of: find.text('Archive'),
                matching: find.byType(Material),
              )
              .last,
        );
        expect(material.color, t.surface);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side.color, t.border);
        expect(
          shape.borderRadius,
          BorderRadius.circular(ApsiraRadii.insetBlock),
        );
        for (final label in ['Archive', 'Share as text']) {
          final row = tester.getSize(
            find
                .ancestor(of: find.text(label), matching: find.byType(InkWell))
                .first,
          );
          expect(row.height, greaterThanOrEqualTo(kMinInteractiveDimension));
        }
        // The divider between the groups.
        expect(find.byType(PopupMenuDivider), findsOneWidget);
      });

      testWidgets('labels grow with the system text size, whole', (
        tester,
      ) async {
        await _open(tester, theme, 1);
        final at100 = tester.getSize(find.text('Share as text')).height;
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        await _open(tester, theme, 2);
        final at200 = tester.getSize(find.text('Share as text')).height;
        // Twice the line, or two whole lines where the menu's width ends.
        expect(at200, greaterThanOrEqualTo(at100 * 2 - 1));
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('menu rows', () {
    for (final (name, theme, t) in [
      ('dark', ApsiraThemeData.dark, ApsiraTheme.dark),
      ('light', ApsiraThemeData.light, ApsiraTheme.light),
    ]) {
      testWidgets('$name: icon in ink2, danger in red-orange, chosen checked', (
        tester,
      ) async {
        await _openRows(tester, theme, 1);
        Color? iconColor(IconData icon) =>
            tester.widget<Icon>(find.byIcon(icon)).color;
        expect(iconColor(_archive), t.ink2);
        final red = t.family(ApsiraFamily.redOrange).solid;
        expect(iconColor(_trash), red);
        final trash = tester.widget<RichText>(
          find.descendant(
            of: find.text('Trash'),
            matching: find.byType(RichText),
          ),
        );
        expect(trash.text.style!.color, red);
        expect(find.byIcon(ApsiraMenuItem.chosenMark), findsOneWidget);
        expect(
          tester.getCenter(find.byIcon(ApsiraMenuItem.chosenMark)).dy,
          closeTo(tester.getCenter(find.text('Archive')).dy, 1),
        );
        expect(iconColor(ApsiraMenuItem.chosenMark), t.accentText);
      });
    }

    testWidgets('paired buttons sit side by side and close with their value', (
      tester,
    ) async {
      final chosen = await _openRows(tester, ApsiraThemeData.dark, 1);
      final undo = tester.getRect(find.text('Undo'));
      final redo = tester.getRect(find.text('Redo'));
      expect(undo.center.dy, closeTo(redo.center.dy, 1));
      expect(redo.left, greaterThan(undo.right));
      final button = find.ancestor(
        of: find.text('Undo'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(button.first).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await tester.tap(find.text('Redo'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty, reason: 'Redo is disabled');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(chosen, [0]);
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('at 200 % the paired buttons stack, nothing overflows', (
      tester,
    ) async {
      await _openRows(tester, ApsiraThemeData.dark, 2);
      final undo = tester.getRect(find.text('Undo'));
      final redo = tester.getRect(find.text('Redo'));
      expect(redo.top, greaterThan(undo.bottom));
      expect(tester.takeException(), isNull);
    });
  });

  test('no menu in lib/ styles itself (the theme does)', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final (widget, banned, itemsArg) in _menuWidgets) {
        for (final call in _calls(src, '$widget<')) {
          final args = _topLevelArgs(call);
          for (final arg in banned) {
            if (args.containsKey(arg)) {
              offenders.add('${file.path}: $widget $arg:');
            }
          }
          final items = args[itemsArg];
          if (items != null && items.contains('ApsiraTypography.')) {
            offenders.add('${file.path}: $widget item text style');
          }
          if (items != null && RegExp(r'\bPopupMenuItem\b').hasMatch(items)) {
            offenders.add('${file.path}: $widget plain PopupMenuItem');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('a group\'s dividers stay inside its card: inset from the '
      'text column to the card\'s side padding (UX §2.4; P3 V-4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ApsiraThemeData.dark,
        home: const Scaffold(
          body: SettingsGroup(
            title: 'Group',
            children: [SizedBox(height: 48), SizedBox(height: 48)],
          ),
        ),
      ),
    );
    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.endIndent, ApsiraSpacing.cardSide);
    expect(divider.indent, greaterThan(0));
  });

  group('settings rows', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('at ${(scale * 100).round()} % every row is 48 dp at least, '
          'nothing overflows', (tester) async {
        await _settings(tester, scale);
        for (final label in ['Version', 'Theme', 'Backups']) {
          final row = find.ancestor(
            of: find.text(label),
            matching: find.byType(SettingsRow),
          );
          expect(
            tester.getSize(row).height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
            reason: label,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at 100 % the value sits beside the label; at 200 % under it', (
      tester,
    ) async {
      await _settings(tester, 1);
      final label = tester.getRect(find.text('Theme'));
      final value = tester.getRect(find.text('Dark'));
      expect(value.center.dy, closeTo(label.center.dy, 1));
      expect(value.left, greaterThan(label.right));
      await _settings(tester, 2);
      expect(
        tester.getRect(find.text('Dark')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Theme')).bottom),
      );
    });

    testWidgets('a row with onTap opens, with its chevron; chevron: false '
        'has none', (tester) async {
      var opened = 0;
      await _settings(tester, 1, onBackups: () => opened++);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Backups'),
            matching: find.byType(SettingsRow),
          ),
          matching: find.byIcon(ApsiraIcons.chevron),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Version'),
            matching: find.byType(SettingsRow),
          ),
          matching: find.byIcon(ApsiraIcons.chevron),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Backups'));
      expect(opened, 1);
    });

    testWidgets('a choice row opens the theme\'s menu, the current choice '
        'checked, and reports the choice', (tester) async {
      final chosen = await _settings(tester, 1);
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.byType(ApsiraMenuItem<ThemeMode>), findsNWidgets(3));
      expect(find.byIcon(ApsiraMenuItem.chosenMark), findsOneWidget);
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();
      expect(chosen, [ThemeMode.light]);
    });
  });
}

/// A Settings screen of one group: a choice row (Theme), a row that opens
/// (Backups) and one with nothing to open (Version), at [scale] times the
/// text size; the returned list gets each theme chosen.
Future<List<ThemeMode>> _settings(
  WidgetTester tester,
  double scale, {
  VoidCallback? onBackups,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final chosen = <ThemeMode>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ApsiraThemeData.dark,
      home: Scaffold(
        body: ListView(
          children: [
            SettingsGroup(
              title: 'Appearance',
              children: [
                SettingsChoiceRow<ThemeMode>(
                  icon: _theme,
                  label: 'Theme',
                  options: const [
                    SettingsOption(ThemeMode.dark, 'Dark'),
                    SettingsOption(ThemeMode.light, 'Light'),
                    SettingsOption(ThemeMode.system, 'Follow system'),
                  ],
                  selected: ThemeMode.dark,
                  onSelected: chosen.add,
                ),
                SettingsRow(
                  icon: _archive,
                  label: 'Backups',
                  subline: 'Every day',
                  value: 'On',
                  onTap: onBackups ?? () {},
                ),
                const SettingsRow(
                  icon: _archive,
                  label: 'Version',
                  value: '0.3.0',
                  chevron: false,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chosen;
}

/// The menu widgets, the per-call arguments that would override the theme,
/// and the argument that builds their items.
const _menuWidgets = [
  (
    'PopupMenuButton',
    {
      'color',
      'shape',
      'elevation',
      'surfaceTintColor',
      'shadowColor',
      'menuPadding',
      'constraints',
    },
    'itemBuilder',
  ),
  ('DropdownButton', {'dropdownColor', 'elevation'}, 'items'),
  ('MenuAnchor', {'style'}, 'menuChildren'),
];

/// The source of every `name(...)` call in [src], parentheses balanced.
Iterable<String> _calls(String src, String name) sync* {
  var from = 0;
  while (true) {
    final at = src.indexOf(name, from);
    if (at < 0) return;
    final open = src.indexOf('(', at);
    var depth = 0;
    for (var i = open; i < src.length; i++) {
      final c = src[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
      if (depth == 0) {
        yield src.substring(open + 1, i);
        from = i;
        break;
      }
    }
  }
}

/// The call's named arguments at its own nesting level, by name.
Map<String, String> _topLevelArgs(String call) {
  final args = <String, String>{};
  var depth = 0;
  var start = 0;
  void take(int end) {
    final part = call.substring(start, end).trim();
    final m = RegExp(r'^(\w+)\s*:').firstMatch(part);
    if (m != null) args[m.group(1)!] = part.substring(m.end);
  }

  for (var i = 0; i < call.length; i++) {
    final c = call[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) {
      take(i);
      start = i + 1;
    }
  }
  take(call.length);
  return args;
}

/// Opens an unstyled menu of two groups at [scale] times the text size.
Future<void> _open(WidgetTester tester, ThemeData theme, double scale) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<int>(
            key: const Key('menu'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Undo')),
              PopupMenuDivider(),
              PopupMenuItem(value: 1, child: Text('Archive')),
              PopupMenuItem(value: 2, child: Text('Share as text')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('menu')));
  await tester.pumpAndSettle();
}

/// Opens a menu of ApsiraMenuButtons (Undo, a disabled Redo) and
/// ApsiraMenuItems (Archive chosen, Trash as danger) at [scale] times the
/// text size; the returned list gets each value chosen.
Future<List<int>> _openRows(
  WidgetTester tester,
  ThemeData theme,
  double scale,
) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final chosen = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<int>(
            key: const Key('menu'),
            onSelected: chosen.add,
            itemBuilder: (_) => [
              const ApsiraMenuButtons(
                buttons: [
                  ApsiraMenuButton(value: 0, icon: _undo, label: 'Undo'),
                  ApsiraMenuButton(
                    value: 1,
                    icon: _redo,
                    label: 'Redo',
                    enabled: false,
                  ),
                ],
              ),
              ApsiraMenuItem(
                value: 2,
                icon: _archive,
                label: 'Archive',
                chosen: true,
              ),
              const PopupMenuDivider(),
              ApsiraMenuItem(
                value: 3,
                icon: _trash,
                label: 'Trash',
                danger: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('menu')));
  await tester.pumpAndSettle();
  return chosen;
}
