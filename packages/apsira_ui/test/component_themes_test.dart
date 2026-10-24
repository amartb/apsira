// From relay test/app/theme/relay_menu_theme_test.dart @ 09b28810 (the theme
// checks) and lyceum lib/app/theme/lyceum_theme.dart @ 9f4ff27 (the values
// buildFull carries), D-APK-013.
//
// `ApsiraThemeData.build` carries exactly the shared set — `highlightColor`,
// the four menu themes, the snack theme and the R-10 text and outlined
// buttons — with RELAY's values, and every other sub-theme is Material's
// default: that is the set every app, VIATICUM included (Q4-a), receives.
// `buildFull` adds LYCEUM's list on top.
import 'dart:io';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Material's own `ThemeData` for the same scheme: its sub-themes are the
/// defaults `build` must leave alone.
ThemeData materialDefault(ThemeData data) =>
    ThemeData(colorScheme: data.colorScheme);

void expectMenuShape(ShapeBorder? border, ApsiraTheme t) {
  final shape = border! as RoundedRectangleBorder;
  expect(shape.borderRadius, BorderRadius.circular(ApsiraRadii.insetBlock));
  expect(shape.side.color, t.border);
  expect(shape.side.width, 1);
}

void main() {
  for (final (name, t) in [
    ('dark', ApsiraTheme.dark),
    ('light', ApsiraTheme.light),
  ]) {
    group('$name build: the shared set (RELAY 09b28810)', () {
      final data = ApsiraThemeData.build(t);

      test('the current choice is marked in tint', () {
        expect(data.highlightColor, t.tint);
      });

      test(
        'popup menus are the bordered surface, flat, below their button',
        () {
          final m = data.popupMenuTheme;
          expect(m.color, t.surface);
          expect(m.surfaceTintColor, const Color(0x00000000));
          expect(m.elevation, 0);
          expectMenuShape(m.shape, t);
          expect(m.menuPadding, const EdgeInsets.all(ApsiraSpacing.grid * 2));
          expect(m.iconColor, t.ink2);
          expect(m.position, PopupMenuPosition.under);
          expect(m.textStyle!.color, t.ink);
          final label = m.labelTextStyle!;
          expect(label.resolve({})!.fontSize, ApsiraTypography.body.fontSize);
          expect(label.resolve({})!.color, t.ink);
          expect(label.resolve({WidgetState.disabled})!.color, t.ink3);
        },
      );

      test('MenuAnchor and DropdownMenu menus match', () {
        for (final style in [
          data.menuTheme.style!,
          data.dropdownMenuTheme.menuStyle!,
        ]) {
          expect(style.backgroundColor!.resolve({}), t.surface);
          expect(style.surfaceTintColor!.resolve({}), const Color(0x00000000));
          expect(style.elevation!.resolve({}), 0);
          expectMenuShape(style.shape!.resolve({}), t);
          expect(
            style.padding!.resolve({}),
            const EdgeInsets.all(ApsiraSpacing.grid * 2),
          );
        }
        final item = data.menuButtonTheme.style!;
        expect(item.minimumSize!.resolve({})!.height, kMinInteractiveDimension);
        expect(
          item.textStyle!.resolve({})!.fontSize,
          ApsiraTypography.body.fontSize,
        );
        expect(item.foregroundColor!.resolve({}), t.ink);
        expect(item.foregroundColor!.resolve({WidgetState.disabled}), t.ink3);
        expect(item.iconColor!.resolve({}), t.ink2);
      });

      test('snacks are RELAY\'s call-site styling', () {
        final s = data.snackBarTheme;
        expect(s.backgroundColor, t.surface);
        expect(s.behavior, SnackBarBehavior.floating);
        expectMenuShape(s.shape, t);
        expect(s.contentTextStyle!.fontSize, ApsiraTypography.snippet.fontSize);
        expect(
          s.contentTextStyle!.fontFamily,
          ApsiraTypography.snippet.fontFamily,
        );
        expect(s.contentTextStyle!.color, t.ink);
        expect(s.actionTextColor, t.accentText);
      });

      test('text and outlined buttons write in accentText (R-10)', () {
        expect(
          data.textButtonTheme.style!.foregroundColor!.resolve({}),
          t.accentText,
        );
        expect(
          data.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
          t.accentText,
        );
      });

      test('every LYCEUM-only sub-theme is Material\'s default', () {
        final m = materialDefault(data);
        expect(data.dividerTheme, m.dividerTheme, reason: 'divider');
        expect(
          data.floatingActionButtonTheme,
          m.floatingActionButtonTheme,
          reason: 'FAB',
        );
        expect(data.appBarTheme, m.appBarTheme, reason: 'app bar');
        expect(data.actionIconTheme, m.actionIconTheme, reason: 'action icons');
        expect(data.tabBarTheme, m.tabBarTheme, reason: 'tabs');
        expect(data.cardTheme, m.cardTheme, reason: 'card');
        expect(
          data.inputDecorationTheme,
          m.inputDecorationTheme,
          reason: 'input decoration',
        );
        expect(data.chipTheme, m.chipTheme, reason: 'chip');
        expect(data.bottomSheetTheme, m.bottomSheetTheme, reason: 'sheet');
        expect(data.dialogTheme, m.dialogTheme, reason: 'dialog');
        expect(data.drawerTheme, m.drawerTheme, reason: 'drawer');
      });

      test('so do the button themes outside the shared set', () {
        final m = materialDefault(data);
        expect(data.elevatedButtonTheme, m.elevatedButtonTheme);
        expect(data.filledButtonTheme, m.filledButtonTheme);
        expect(data.iconButtonTheme, m.iconButtonTheme);
        expect(data.listTileTheme, m.listTileTheme);
        expect(data.navigationBarTheme, m.navigationBarTheme);
      });
    });

    group('$name buildFull: LYCEUM\'s list (lyceum 9f4ff27)', () {
      final data = ApsiraThemeData.buildFull(t);
      final edge = BorderSide(color: t.border);

      test('keeps the shared set and the tokens', () {
        final shared = ApsiraThemeData.build(t);
        expect(data.highlightColor, shared.highlightColor);
        // The label is a WidgetStateProperty closure: compare what it holds.
        expect(data.popupMenuTheme.color, shared.popupMenuTheme.color);
        expect(data.popupMenuTheme.shape, shared.popupMenuTheme.shape);
        expect(data.popupMenuTheme.position, shared.popupMenuTheme.position);
        expect(
          data.popupMenuTheme.labelTextStyle!.resolve({}),
          shared.popupMenuTheme.labelTextStyle!.resolve({}),
        );
        expect(data.snackBarTheme, shared.snackBarTheme);
        expect(
          data.textButtonTheme.style!.foregroundColor!.resolve({}),
          t.accentText,
        );
        expect(
          data.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
          t.accentText,
        );
        expect(identical(data.extension<ApsiraTheme>(), t), isTrue);
      });

      test('dividers are line', () {
        expect(data.dividerTheme.color, t.line);
      });

      test('the FAB is the flat bordered accentFill square', () {
        final f = data.floatingActionButtonTheme;
        expect(f.backgroundColor, t.accentFill);
        expect(f.foregroundColor, t.onAccent);
        expect(
          f.shape,
          ApsiraShapes.rounded(ApsiraRadii.fab).copyWith(side: edge),
        );
        expect(
          f.sizeConstraints,
          const BoxConstraints.tightFor(
            width: ApsiraSizes.fab,
            height: ApsiraSizes.fab,
          ),
        );
        expect(f.iconSize, 30);
        for (final e in [
          f.elevation,
          f.focusElevation,
          f.hoverElevation,
          f.highlightElevation,
          f.disabledElevation,
        ]) {
          expect(e, 0);
        }
      });

      test('the app bar sits on ground, never tinted', () {
        final a = data.appBarTheme;
        expect(a.backgroundColor, t.ground);
        expect(a.foregroundColor, t.ink);
        expect(a.surfaceTintColor, t.ground);
        expect(a.elevation, 0);
        expect(a.scrolledUnderElevation, 0);
      });

      test('tabs: ink over ink3, the accentFill indicator under the label', () {
        final b = data.tabBarTheme;
        expect(b.labelColor, t.ink);
        expect(b.unselectedLabelColor, t.ink3);
        expect(b.labelStyle, ApsiraTypography.rowTitle);
        expect(b.unselectedLabelStyle, ApsiraTypography.rowTitle);
        expect(b.indicatorColor, t.accentFill);
        expect(b.indicatorSize, TabBarIndicatorSize.label);
        expect(b.dividerColor, t.border);
        expect(b.tabAlignment, isNull);
      });

      test('cards are the bordered surface at the group-card radius', () {
        final c = data.cardTheme;
        expect(c.color, t.surface);
        expect(c.surfaceTintColor, const Color(0x00000000));
        expect(c.elevation, 0);
        expect(c.margin, EdgeInsets.zero);
        expect(c.clipBehavior, Clip.antiAlias);
        expect(
          c.shape,
          ApsiraShapes.rounded(ApsiraRadii.groupCard).copyWith(side: edge),
        );
      });

      test('fields are dense, unfilled, accentText when focused', () {
        final i = data.inputDecorationTheme;
        final error = t.family(ApsiraFamily.redOrange).solid;
        OutlineInputBorder input(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(ApsiraRadii.captureIconTile),
          borderSide: BorderSide(color: c),
        );
        expect(i.isDense, isTrue);
        expect(i.filled, isFalse);
        expect(i.hintStyle!.color, t.ink3);
        expect(i.hintStyle!.fontSize, ApsiraTypography.body.fontSize);
        expect(i.labelStyle!.color, t.ink3);
        expect(i.labelStyle!.fontSize, ApsiraTypography.meta.fontSize);
        expect(i.errorStyle!.color, error);
        expect(i.errorMaxLines, 3);
        expect(i.border, input(t.border));
        expect(i.enabledBorder, input(t.border));
        expect(i.disabledBorder, input(t.line));
        expect(i.focusedBorder, input(t.accentText));
        expect(i.errorBorder, input(error));
        expect(i.focusedErrorBorder, input(error));
      });

      test('chips are bordered pills, accC when chosen', () {
        final c = data.chipTheme;
        expect(c.backgroundColor, t.surface);
        expect(c.selectedColor, t.accC);
        expect(c.checkmarkColor, t.onAccC);
        expect(c.side, edge);
        expect(c.shape, ApsiraShapes.pill);
        expect(c.labelStyle!.color, t.ink);
        expect(c.labelStyle!.fontSize, ApsiraTypography.pill.fontSize);
      });

      test('bottom sheets are the bordered surface over the scrim', () {
        final s = data.bottomSheetTheme;
        expect(s.backgroundColor, t.surface);
        expect(s.modalBackgroundColor, t.surface);
        expect(s.surfaceTintColor, const Color(0x00000000));
        expect(s.modalBarrierColor, t.scrim);
        expect(s.clipBehavior, Clip.antiAlias);
        expect(s.shape, ApsiraShapes.sheetTop.copyWith(side: edge));
      });

      test('dialogs are the bordered surface over the scrim', () {
        final d = data.dialogTheme;
        expect(d.backgroundColor, t.surface);
        expect(d.surfaceTintColor, const Color(0x00000000));
        expect(d.barrierColor, t.scrim);
        expect(d.shape, ApsiraThemeData.dialogShape(t));
      });

      test('the drawer is the bordered panel, 296 wide', () {
        final d = data.drawerTheme;
        expect(d.backgroundColor, t.panel);
        expect(d.surfaceTintColor, const Color(0x00000000));
        expect(d.scrimColor, t.scrim);
        expect(d.width, 296);
        expect(
          d.shape,
          ApsiraShapes.rounded(ApsiraRadii.drawerPanel).copyWith(side: edge),
        );
      });

      test('action icons stay the app\'s (its own glyphs)', () {
        expect(data.actionIconTheme, materialDefault(data).actionIconTheme);
      });
    });
  }

  test('build and buildFull attach an app\'s extensions after the tokens', () {
    const extra = _Extra();
    for (final data in [
      ApsiraThemeData.build(ApsiraTheme.dark, extensions: [extra]),
      ApsiraThemeData.buildFull(ApsiraTheme.dark, extensions: [extra]),
    ]) {
      expect(
        identical(data.extension<ApsiraTheme>(), ApsiraTheme.dark),
        isTrue,
      );
      expect(identical(data.extension<_Extra>(), extra), isTrue);
    }
  });

  test('component_themes.dart holds no colour literal', () {
    final src = File('lib/src/component_themes.dart').readAsStringSync();
    // `ApsiraSchemeColors.` is the literals' own home, not a literal.
    expect(src, isNot(contains(RegExp(r'\bColors\.'))));
    expect(src, isNot(contains(RegExp(r'\bColor\('))));
  });
}

class _Extra extends ThemeExtension<_Extra> {
  const _Extra();

  @override
  _Extra copyWith() => this;

  @override
  _Extra lerp(covariant ThemeExtension<_Extra>? other, double t) => this;
}
