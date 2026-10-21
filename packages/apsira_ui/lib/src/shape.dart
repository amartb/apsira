// From relay lib/app/theme/relay_shape.dart @ 5f606e9
import 'package:flutter/material.dart';

/// Corner radii of UX §2.4, in logical pixels.
abstract final class ApsiraRadii {
  /// Group card.
  static const double groupCard = 28;

  /// The editor's page card.
  static const double editorPage = 32;

  /// Sheet top corners.
  static const double sheet = 32;

  /// The drawer panel (floating [ApsiraSizes.drawerInset] from the edges).
  static const double drawerPanel = 32;

  /// The capture sheet.
  static const double captureSheet = 32;

  /// Pinned card ([ApsiraSizes.pinnedCardWidth] wide).
  static const double pinnedCard = 26;

  /// Inset block in a card (task block, fields panel, embed), `tint` fill.
  static const double insetBlock = 22;

  /// Stat tile, tonal fill.
  static const double statTile = 22;

  /// Capture tile, tonal fill.
  static const double captureTile = 22;

  /// The solid icon tile inside a capture tile
  /// ([ApsiraSizes.captureIconTile] px).
  static const double captureIconTile = 15;

  /// FAB ([ApsiraSizes.fab] square).
  static const double fab = 24;

  /// Recorder main button ([ApsiraSizes.recorderButton] square).
  static const double recorderButton = 34;

  /// Icon tile radius by tile size in whole pixels: 14–15 at 40–44 px,
  /// 11–12 at 32–36 px.
  static const Map<int, double> iconTiles = {32: 11, 36: 12, 40: 14, 44: 15};

  /// The radius of an icon tile of [size] px; throws [ArgumentError] for a
  /// size UX §2.4 does not define.
  static double iconTile(double size) =>
      (size == size.roundToDouble() ? iconTiles[size.round()] : null) ??
      (throw ArgumentError.value(size, 'size', 'icon tiles are 32–44 px'));

  /// Every radius, for checks against the spec (values repeat).
  static List<double> get all => [
    groupCard,
    editorPage,
    sheet,
    drawerPanel,
    captureSheet,
    pinnedCard,
    insetBlock,
    statTile,
    captureTile,
    captureIconTile,
    fab,
    recorderButton,
    ...iconTiles.values,
  ];
}

/// Element sizes of UX §2.4, in logical pixels.
abstract final class ApsiraSizes {
  /// The drawer floats this far from the screen edges.
  static const double drawerInset = 8;

  /// Pinned cards are this wide and scroll horizontally.
  static const double pinnedCardWidth = 210;

  /// The solid icon tile in a capture tile.
  static const double captureIconTile = 44;

  /// Pill and chip height range; pills are fully rounded.
  static const double pillMinHeight = 24;
  static const double pillMaxHeight = 40;

  /// Floating top-bar button: a circle, `surface` and `shadow`.
  static const double floatingTopBarButton = 48;

  /// FAB, square.
  static const double fab = 68;

  /// Recorder main button, square.
  static const double recorderButton = 96;

  /// Checkbox circle in lists, in the task sheet, and its ring width.
  static const double checkbox = 24;
  static const double checkboxInTaskSheet = 30;
  static const double checkboxRing = 2;

  /// Every size, for checks against the spec (values repeat).
  static List<double> get all => [
    drawerInset,
    pinnedCardWidth,
    captureIconTile,
    pillMinHeight,
    pillMaxHeight,
    floatingTopBarButton,
    fab,
    recorderButton,
    checkbox,
    checkboxInTaskSheet,
    checkboxRing,
    for (final px in ApsiraRadii.iconTiles.keys) px.toDouble(),
  ];
}

/// Spacing of UX §2.4 (a 4-pt grid), in logical pixels.
abstract final class ApsiraSpacing {
  /// The grid unit.
  static const double grid = 4;

  /// Screen gutter to card edges.
  static const double screenGutter = 16;

  /// Screen gutter for large titles.
  static const double largeTitleGutter = 24;

  /// Inside group cards: the header's top padding.
  static const double cardHeaderTop = 14;

  /// Inside group cards: side padding of the header and the rows.
  static const double cardSide = 20;

  /// Vertical padding of task rows.
  static const double taskRowVertical = 14;

  /// Vertical padding of note rows.
  static const double noteRowVertical = 16;

  /// Inset dividers start at the text column: after a checkbox…
  static const double dividerAfterCheckbox = 58;

  /// …and after an icon tile.
  static const double dividerAfterIconTile = 78;

  /// Between cards, 16–18.
  static const double betweenCards = 16;
  static const double betweenCardsMax = 18;

  /// Between sections, 18–24.
  static const double betweenSections = 18;
  static const double betweenSectionsMax = 24;

  /// Between pills, 6–8.
  static const double betweenPills = 6;
  static const double betweenPillsMax = 8;

  /// From a row's title to its meta pills.
  static const double titleToMetaPills = 8;

  /// A group card's header padding (14 top, 20 sides).
  static const cardHeader = EdgeInsets.fromLTRB(
    cardSide,
    cardHeaderTop,
    cardSide,
    0,
  );

  /// A task row's padding (14/20).
  static const taskRow = EdgeInsets.symmetric(
    horizontal: cardSide,
    vertical: taskRowVertical,
  );

  /// A note row's padding (16/20).
  static const noteRow = EdgeInsets.symmetric(
    horizontal: cardSide,
    vertical: noteRowVertical,
  );

  /// Every spacing value, for checks against the spec (values repeat).
  static List<double> get all => [
    grid,
    screenGutter,
    largeTitleGutter,
    cardHeaderTop,
    cardSide,
    taskRowVertical,
    noteRowVertical,
    dividerAfterCheckbox,
    dividerAfterIconTile,
    betweenCards,
    betweenCardsMax,
    betweenSections,
    betweenSectionsMax,
    betweenPills,
    betweenPillsMax,
    titleToMetaPills,
  ];
}

/// Shapes built from [ApsiraRadii]. The `border` side (D-066) is added where
/// the surface is drawn, from the `ApsiraTheme` tokens.
abstract final class ApsiraShapes {
  /// A rounded rectangle of [radius].
  static RoundedRectangleBorder rounded(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  /// Sheets: top corners only.
  static const sheetTop = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(ApsiraRadii.sheet),
    ),
  );

  /// Pills and chips: fully rounded.
  static const pill = StadiumBorder();

  /// Floating top-bar buttons and checkboxes.
  static const circle = CircleBorder();
}
