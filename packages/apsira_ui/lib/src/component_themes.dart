// From relay lib/app/theme/relay_theme.dart @ 09b28810 (the menus, RELAY's
// call-site snack styling) and lyceum lib/app/theme/lyceum_theme.dart @
// 9f4ff27 (the R-10 buttons and the sub-themes of `buildFull`), D-APK-013.
import 'package:flutter/material.dart';

import 'colors.dart';
import 'shape.dart';
import 'theme.dart';
import 'typography.dart';

/// The Material sub-themes built from the tokens (D-APK-013).
///
/// [ApsiraThemeData.build] applies the shared set: the four menu themes
/// ([popupMenuTheme], [menuStyle], [menuItemStyle]), [snackBarTheme], and
/// [textButtonTheme] and [outlinedButtonTheme] (R-10). The others are
/// LYCEUM's, applied together by [ApsiraThemeData.buildFull]; an app may
/// also take any one of them on its own.
abstract final class ApsiraComponentThemes {
  // The shared set.

  /// A menu's surface edge: the inset-block radius with its 1 px `border`
  /// (D-066), flat, since depth comes from the border.
  static RoundedRectangleBorder menuShape(ApsiraTheme t) =>
      ApsiraShapes.rounded(ApsiraRadii.insetBlock)
          .copyWith(side: BorderSide(color: t.border));

  /// Inside a menu's edge: the rows stay clear of the rounded corners, so
  /// a row's ink never reaches past them.
  static const menuPadding = EdgeInsets.all(ApsiraSpacing.grid * 2);

  /// A menu row's label: body text in `ink`, `ink3` when disabled. It
  /// scales with the system text size, and the row (48 dp at least,
  /// Material's default) grows with it.
  static WidgetStateProperty<TextStyle> menuLabel(ApsiraTheme t) =>
      WidgetStateProperty.resolveWith(
        (states) => ApsiraTypography.body.copyWith(
          color: states.contains(WidgetState.disabled) ? t.ink3 : t.ink,
        ),
      );

  /// Every `PopupMenuButton` and `showMenu` (RELAY F8): no call site styles
  /// its own menu. Groups are split with `PopupMenuDivider`, which takes
  /// `line` from [ThemeData.dividerColor]; rows are `ApsiraMenuItem`s and
  /// paired actions (Undo, Redo) an `ApsiraMenuButtons` row on top.
  static PopupMenuThemeData popupMenuTheme(ApsiraTheme t) => PopupMenuThemeData(
    color: t.surface,
    surfaceTintColor: ApsiraSchemeColors.transparent,
    elevation: 0,
    shape: menuShape(t),
    menuPadding: menuPadding,
    labelTextStyle: menuLabel(t),
    textStyle: ApsiraTypography.body.copyWith(color: t.ink),
    iconColor: t.ink2,
    // Below its button, as RELAY's direction board draws the note's ⋮ menu.
    position: PopupMenuPosition.under,
  );

  /// The same menu for `MenuAnchor` and `DropdownMenu`.
  static MenuStyle menuStyle(ApsiraTheme t) => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(t.surface),
    surfaceTintColor: const WidgetStatePropertyAll(
      ApsiraSchemeColors.transparent,
    ),
    elevation: const WidgetStatePropertyAll(0),
    shape: WidgetStatePropertyAll(menuShape(t)),
    padding: const WidgetStatePropertyAll(menuPadding),
  );

  /// A `MenuAnchor` row: 48 dp at least, its label as a popup menu's.
  static ButtonStyle menuItemStyle(ApsiraTheme t) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(0, kMinInteractiveDimension),
    ),
    textStyle: menuLabel(t),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? t.ink3 : t.ink,
    ),
    iconColor: WidgetStatePropertyAll(t.ink2),
  );

  /// Every snack: what RELAY's call sites set on each `SnackBar` — the
  /// bordered `surface` at the inset-block radius, floating, the message in
  /// `snippet` and `ink`, the action in `accentText`.
  static SnackBarThemeData snackBarTheme(ApsiraTheme t) => SnackBarThemeData(
    backgroundColor: t.surface,
    behavior: SnackBarBehavior.floating,
    shape: menuShape(t),
    contentTextStyle: ApsiraTypography.snippet.copyWith(color: t.ink),
    actionTextColor: t.accentText,
  );

  /// Accent-coloured labels are text (R-10): `accentText`, the accent made
  /// to read on `ground` and `panel`, not the fill colour Material's
  /// `primary` gives them (4.39:1 on the light ground, under 4.5:1).
  static TextButtonThemeData textButtonTheme(ApsiraTheme t) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.accentText),
      );

  /// The outlined button's label, as [textButtonTheme]'s (R-10).
  static OutlinedButtonThemeData outlinedButtonTheme(ApsiraTheme t) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: t.accentText),
      );

  // LYCEUM's list (`buildFull`).

  /// The drawer panel's width.
  static const double drawerWidth = 296;

  /// The FAB's glyph (RELAY `ShellCaptureButton`).
  static const double fabIcon = 30;

  /// Dividers in `line`.
  static DividerThemeData dividerTheme(ApsiraTheme t) =>
      DividerThemeData(color: t.line);

  /// RELAY `ShellCaptureButton`: an `accentFill` square with its 1 px
  /// `border`, the + in `onAccent`, flat (depth comes from the border).
  static FloatingActionButtonThemeData floatingActionButtonTheme(
    ApsiraTheme t,
  ) => FloatingActionButtonThemeData(
    backgroundColor: t.accentFill,
    foregroundColor: t.onAccent,
    shape: ApsiraShapes.rounded(ApsiraRadii.fab)
        .copyWith(side: BorderSide(color: t.border)),
    sizeConstraints: const BoxConstraints.tightFor(
      width: ApsiraSizes.fab,
      height: ApsiraSizes.fab,
    ),
    iconSize: fabIcon,
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 0,
    highlightElevation: 0,
    disabledElevation: 0,
  );

  /// The bar sits on the screen's `ground`: no tint, no scrolled-under
  /// elevation.
  static AppBarTheme appBarTheme(ApsiraTheme t) => AppBarTheme(
    backgroundColor: t.ground,
    foregroundColor: t.ink,
    surfaceTintColor: t.ground,
    elevation: 0,
    scrolledUnderElevation: 0,
  );

  /// Tabs in `ink` over `ink3`, the `accentFill` indicator under the label.
  /// No `tabAlignment`: it asserts on a fixed (non-scrolling) tab bar.
  static TabBarThemeData tabBarTheme(ApsiraTheme t) => TabBarThemeData(
    labelColor: t.ink,
    unselectedLabelColor: t.ink3,
    labelStyle: ApsiraTypography.rowTitle,
    unselectedLabelStyle: ApsiraTypography.rowTitle,
    indicatorColor: t.accentFill,
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: t.border,
  );

  /// A card: the bordered `surface` at the group-card radius, flat.
  static CardThemeData cardTheme(ApsiraTheme t) => CardThemeData(
    color: t.surface,
    surfaceTintColor: ApsiraSchemeColors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: ApsiraShapes.rounded(ApsiraRadii.groupCard)
        .copyWith(side: BorderSide(color: t.border)),
  );

  /// RELAY's editors (`valueInputDecoration`): dense and unfilled, 1 px
  /// outlines at the capture-icon-tile radius, `accentText` when focused,
  /// red-orange when refused, the labels and hints in `ink3`.
  static InputDecorationThemeData inputDecorationTheme(ApsiraTheme t) {
    OutlineInputBorder input(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ApsiraRadii.captureIconTile),
      borderSide: BorderSide(color: c),
    );
    final error = t.family(ApsiraFamily.redOrange).solid;
    return InputDecorationThemeData(
      isDense: true,
      filled: false,
      hintStyle: ApsiraTypography.body.copyWith(color: t.ink3),
      labelStyle: ApsiraTypography.meta.copyWith(color: t.ink3),
      errorStyle: ApsiraTypography.meta.copyWith(color: error),
      errorMaxLines: 3,
      border: input(t.border),
      enabledBorder: input(t.border),
      disabledBorder: input(t.line),
      focusedBorder: input(t.accentText),
      errorBorder: input(error),
      focusedErrorBorder: input(error),
    );
  }

  /// A chip: a bordered pill on `surface`, `accC` when chosen.
  static ChipThemeData chipTheme(ApsiraTheme t) => ChipThemeData(
    backgroundColor: t.surface,
    selectedColor: t.accC,
    checkmarkColor: t.onAccC,
    side: BorderSide(color: t.border),
    shape: ApsiraShapes.pill,
    labelStyle: ApsiraTypography.pill.copyWith(color: t.ink),
  );

  /// A bottom sheet: the bordered `surface` over the `scrim`.
  static BottomSheetThemeData bottomSheetTheme(ApsiraTheme t) =>
      BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: ApsiraSchemeColors.transparent,
        modalBarrierColor: t.scrim,
        clipBehavior: Clip.antiAlias,
        shape: ApsiraShapes.sheetTop.copyWith(
          side: BorderSide(color: t.border),
        ),
      );

  /// A dialog: [ApsiraThemeData.dialogShape] on `surface`, over the `scrim`.
  static DialogThemeData dialogTheme(ApsiraTheme t) => DialogThemeData(
    backgroundColor: t.surface,
    surfaceTintColor: ApsiraSchemeColors.transparent,
    barrierColor: t.scrim,
    shape: ApsiraThemeData.dialogShape(t),
  );

  /// The drawer: the bordered `panel`, [drawerWidth] wide, over the `scrim`.
  static DrawerThemeData drawerTheme(ApsiraTheme t) => DrawerThemeData(
    backgroundColor: t.panel,
    surfaceTintColor: ApsiraSchemeColors.transparent,
    scrimColor: t.scrim,
    width: drawerWidth,
    shape: ApsiraShapes.rounded(ApsiraRadii.drawerPanel)
        .copyWith(side: BorderSide(color: t.border)),
  );
}
