// From relay lib/features/theme_preview/ui/theme_preview_screen.dart @
// 09b28810, on the Apsira tokens, with a section of kit samples
// (D-APK-014). VIATICUM's state roles and `room` set are VIATICUM's tokens
// and stay in VIATICUM.
import 'package:flutter/material.dart';

import '../colors.dart';
import '../icons.dart';
import '../kit/kit.dart';
import '../shape.dart';
import '../theme.dart';
import '../typography.dart';

/// The app bar's title: the screen's name, for the developer.
const _title = 'ThemePreview';

/// The elevation sample's label.
const _shadowLabel = 'shadow + border';

/// The kit samples' texts: the widgets' own names.
const _groupCard = 'GroupCard';
const _cardSlice = 'CardSlice';
const _emptyState = 'EmptyState';
const _tagPill = 'TagPill';
const _filterPill = 'FilterPill';
const _drawerItem = 'DrawerItem';
const _remove = 'remove';
const _message = 'message';

/// The debug screen: every colour token, semantic family, the elevation,
/// every type style, every component shape, every spacing value and a
/// sample of each kit widget family, once in the dark theme and once in the
/// light one.
///
/// Each sample is keyed `themePreview/<dark|light>/<kind>/<name>` so tests
/// can find it. Only `ApsiraTheme` tokens paint it. An app gates the route
/// with its own flavour check.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(_title)),
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ThemeSection('dark', ApsiraTheme.dark),
            _ThemeSection('light', ApsiraTheme.light),
          ],
        ),
      ),
    );
  }
}

/// The spacing values by their `ApsiraSpacing` names.
const _spacing = {
  'grid': ApsiraSpacing.grid,
  'screenGutter': ApsiraSpacing.screenGutter,
  'largeTitleGutter': ApsiraSpacing.largeTitleGutter,
  'cardHeaderTop': ApsiraSpacing.cardHeaderTop,
  'cardSide': ApsiraSpacing.cardSide,
  'taskRowVertical': ApsiraSpacing.taskRowVertical,
  'noteRowVertical': ApsiraSpacing.noteRowVertical,
  'dividerAfterCheckbox': ApsiraSpacing.dividerAfterCheckbox,
  'dividerAfterIconTile': ApsiraSpacing.dividerAfterIconTile,
  'betweenCards': ApsiraSpacing.betweenCards,
  'betweenCardsMax': ApsiraSpacing.betweenCardsMax,
  'betweenSections': ApsiraSpacing.betweenSections,
  'betweenSectionsMax': ApsiraSpacing.betweenSectionsMax,
  'betweenPills': ApsiraSpacing.betweenPills,
  'betweenPillsMax': ApsiraSpacing.betweenPillsMax,
  'titleToMetaPills': ApsiraSpacing.titleToMetaPills,
};

/// One theme's samples, under that theme's `ThemeData`.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection(this.name, this.tokens);

  final String name;
  final ApsiraTheme tokens;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ApsiraThemeData.build(tokens),
      child: ColoredBox(
        color: tokens.ground,
        child: Padding(
          padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: ApsiraTypography.display.copyWith(color: tokens.ink),
              ),
              ..._group('colour tokens', [
                for (final MapEntry(:key, :value) in tokens.colors.entries)
                  _Swatch(_key('color', key), key, value),
              ]),
              ..._group('semantic families', [
                for (final f in ApsiraFamily.values) ...[
                  _Swatch(
                    _key('family', '${f.name}.solid'),
                    '${f.name}.solid',
                    tokens.family(f).solid,
                  ),
                  _Swatch(
                    _key('family', '${f.name}.container'),
                    '${f.name}.container',
                    tokens.family(f).container,
                  ),
                  _Swatch(
                    _key('family', '${f.name}.onContainer'),
                    '${f.name}.onContainer',
                    tokens.family(f).onContainer,
                  ),
                ],
              ]),
              ..._group('elevation', [
                _Labelled(
                  key: _key('elevation', 'shadow'),
                  label: _shadowLabel,
                  child: _box(
                    tokens,
                    ApsiraShapes.rounded(ApsiraRadii.groupCard),
                    const Size(120, 72),
                    shadow: tokens.shadow,
                  ),
                ),
              ]),
              ..._group('type', [
                for (final s in ApsiraTypeStyle.values)
                  _TypeSample(_key('type', s.name), s.name, s.style),
                _TypeSample(
                  _key('type', 'listTitle'),
                  'listTitle',
                  ApsiraTypography.listTitle,
                ),
              ], vertical: true),
              ..._group('shapes', _shapes()),
              ..._group('spacing', [
                for (final MapEntry(:key, :value) in _spacing.entries)
                  _SpacingSample(_key('spacing', key), key, value),
              ], vertical: true),
              ..._group('kit', _kit(), vertical: true),
            ],
          ),
        ),
      ),
    );
  }

  ValueKey<String> _key(String kind, String sample) =>
      ValueKey('themePreview/$name/$kind/$sample');

  /// A titled group of samples, wrapped, or stacked when [vertical].
  List<Widget> _group(
    String title,
    List<Widget> samples, {
    bool vertical = false,
  }) => [
    const SizedBox(height: ApsiraSpacing.betweenSectionsMax),
    Text(title, style: ApsiraTypography.cardTitle.copyWith(color: tokens.ink)),
    const SizedBox(height: ApsiraSpacing.titleToMetaPills),
    if (vertical)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in samples)
            Padding(
              padding: const EdgeInsets.only(
                bottom: ApsiraSpacing.betweenPills,
              ),
              child: s,
            ),
        ],
      )
    else
      Wrap(
        spacing: ApsiraSpacing.betweenCards,
        runSpacing: ApsiraSpacing.betweenCards,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: samples,
      ),
  ];

  /// The component shapes, each with its `border` (D-066).
  List<Widget> _shapes() {
    final neutral = tokens.family(ApsiraFamily.neutral);
    Widget shape(
      String id,
      String label,
      ShapeBorder border,
      Size size, {
      Color? fill,
      List<BoxShadow> shadow = const [],
    }) => _Labelled(
      key: _key('shape', id),
      label: label,
      child: _box(tokens, border, size, fill: fill, shadow: shadow),
    );
    RoundedRectangleBorder r(double radius) => ApsiraShapes.rounded(radius);
    return [
      shape(
        'groupCard',
        'groupCard r28',
        r(ApsiraRadii.groupCard),
        const Size(120, 72),
      ),
      shape(
        'editorPage',
        'editorPage r32',
        r(ApsiraRadii.editorPage),
        const Size(120, 72),
      ),
      shape(
        'sheet',
        'sheet top r32',
        ApsiraShapes.sheetTop,
        const Size(160, 64),
      ),
      shape(
        'drawerPanel',
        'drawerPanel r32, inset ${ApsiraSizes.drawerInset}',
        r(ApsiraRadii.drawerPanel),
        const Size(120, 96),
        fill: tokens.panel,
      ),
      shape(
        'captureSheet',
        'captureSheet r32',
        r(ApsiraRadii.captureSheet),
        const Size(160, 72),
      ),
      shape(
        'pinnedCard',
        'pinnedCard r26, ${ApsiraSizes.pinnedCardWidth} wide',
        r(ApsiraRadii.pinnedCard),
        const Size(ApsiraSizes.pinnedCardWidth, 96),
      ),
      shape(
        'insetBlock',
        'insetBlock r22',
        r(ApsiraRadii.insetBlock),
        const Size(120, 56),
        fill: tokens.tint,
      ),
      shape(
        'statTile',
        'statTile r22',
        r(ApsiraRadii.statTile),
        const Size(96, 80),
      ),
      shape(
        'captureTile',
        'captureTile r22',
        r(ApsiraRadii.captureTile),
        const Size(120, 80),
        fill: tokens.accC,
      ),
      shape(
        'captureIconTile',
        'captureIconTile ${ApsiraSizes.captureIconTile} r15',
        r(ApsiraRadii.captureIconTile),
        const Size.square(ApsiraSizes.captureIconTile),
        fill: tokens.accentFill,
      ),
      for (final px in ApsiraRadii.iconTiles.keys)
        shape(
          'iconTile$px',
          'iconTile $px r${ApsiraRadii.iconTile(px.toDouble())}',
          r(ApsiraRadii.iconTile(px.toDouble())),
          Size.square(px.toDouble()),
          fill: neutral.container,
        ),
      shape(
        'pill',
        'pill ${ApsiraSizes.pillMinHeight}–${ApsiraSizes.pillMaxHeight}',
        ApsiraShapes.pill,
        const Size(72, ApsiraSizes.pillMinHeight),
        fill: tokens.accC,
      ),
      shape(
        'floatingTopBarButton',
        'floatingTopBarButton ${ApsiraSizes.floatingTopBarButton}',
        ApsiraShapes.circle,
        const Size.square(ApsiraSizes.floatingTopBarButton),
        shadow: tokens.shadow,
      ),
      shape(
        'fab',
        'fab ${ApsiraSizes.fab} r24',
        r(ApsiraRadii.fab),
        const Size.square(ApsiraSizes.fab),
        fill: tokens.accentFill,
        shadow: tokens.shadow,
      ),
      shape(
        'recorderButton',
        'recorderButton ${ApsiraSizes.recorderButton} r34',
        r(ApsiraRadii.recorderButton),
        const Size.square(ApsiraSizes.recorderButton),
        fill: tokens.family(ApsiraFamily.redOrange).solid,
      ),
      _checkbox('checkbox', ApsiraSizes.checkbox),
      _checkbox('checkboxInTaskSheet', ApsiraSizes.checkboxInTaskSheet),
    ];
  }

  /// One sample of each kit widget family, keyed by its kit name.
  List<Widget> _kit() {
    Widget sample(String id, Widget child) =>
        KeyedSubtree(key: _key('kit', id), child: child);
    return [
      sample(
        'groupCard',
        const GroupCard(
          header: _groupCard,
          children: [
            Padding(padding: ApsiraSpacing.noteRow, child: Text(_cardSlice)),
            Padding(padding: ApsiraSpacing.noteRow, child: Text(_cardSlice)),
          ],
        ),
      ),
      sample(
        'emptyState',
        const EmptyState(
          icon: ApsiraIcons.folder,
          title: _emptyState,
          message: _message,
          compact: true,
        ),
      ),
      sample(
        'familyPill',
        Wrap(
          spacing: ApsiraSpacing.betweenPills,
          runSpacing: ApsiraSpacing.betweenPills,
          children: [
            for (final f in ApsiraFamily.values)
              FamilyPill(label: f.name, family: f),
          ],
        ),
      ),
      sample('tagPill', const TagPill(label: _tagPill)),
      sample(
        'filterPill',
        FilterPill(label: _filterPill, removeLabel: _remove, onRemove: () {}),
      ),
      sample(
        'iconBox',
        Wrap(
          spacing: ApsiraSpacing.betweenPills,
          children: [
            const IconBox(ApsiraIcons.folder),
            for (final f in ApsiraFamily.values) ...[
              IconBox(ApsiraIcons.folder, family: f),
              IconBox(ApsiraIcons.folder, family: f, filled: true),
            ],
          ],
        ),
      ),
      sample(
        'drawerItem',
        ColoredBox(
          color: tokens.panel,
          child: Column(
            children: [
              DrawerItem(
                icon: ApsiraIcons.folder,
                label: _drawerItem,
                selected: true,
                onTap: () {},
              ),
              DrawerItem(
                icon: ApsiraIcons.folder,
                label: _drawerItem,
                selected: false,
                count: 3,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// A checkbox circle: the 2 px `ring`, no fill.
  Widget _checkbox(String id, double size) => _Labelled(
    key: _key('shape', id),
    label: '$id $size, ring ${ApsiraSizes.checkboxRing}',
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: ApsiraShapes.circle.copyWith(
            side: BorderSide(
              color: tokens.ring,
              width: ApsiraSizes.checkboxRing,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A [size] box of [shape] with the theme's `border` side, filled with
/// [fill] (`surface` by default).
Widget _box(
  ApsiraTheme tokens,
  ShapeBorder shape,
  Size size, {
  Color? fill,
  List<BoxShadow> shadow = const [],
}) {
  final side = BorderSide(color: tokens.border);
  final bordered = switch (shape) {
    final OutlinedBorder o => o.copyWith(side: side),
    _ => shape,
  };
  return SizedBox.fromSize(
    size: size,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: bordered,
        color: fill ?? tokens.surface,
        shadows: shadow,
      ),
    ),
  );
}

/// A sample above its label (`meta`, `ink3`).
class _Labelled extends StatelessWidget {
  const _Labelled({
    required super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        const SizedBox(height: ApsiraSpacing.grid),
        Text(label, style: ApsiraTypography.meta.copyWith(color: tokens.ink3)),
      ],
    );
  }
}

/// A colour swatch: the colour on a bordered tile, with its token name.
class _Swatch extends StatelessWidget {
  const _Swatch(Key key, this.name, this.color) : super(key: key);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(
            tokens,
            ApsiraShapes.rounded(ApsiraRadii.iconTile(40)),
            const Size(112, 40),
            fill: color,
          ),
          const SizedBox(height: ApsiraSpacing.grid),
          Text(name, style: ApsiraTypography.meta.copyWith(color: tokens.ink3)),
        ],
      ),
    );
  }
}

/// A type style's name set in that style, in `ink`.
class _TypeSample extends StatelessWidget {
  const _TypeSample(Key key, this.name, this.style) : super(key: key);

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    return Text(name, style: style.copyWith(color: tokens.ink));
  }
}

/// A spacing value drawn as a `ring` bar of its width, with its name.
class _SpacingSample extends StatelessWidget {
  const _SpacingSample(Key key, this.name, this.value) : super(key: key);

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    return Row(
      children: [
        SizedBox(
          width: value,
          height: ApsiraSpacing.betweenPillsMax,
          child: ColoredBox(color: tokens.ring),
        ),
        const SizedBox(width: ApsiraSpacing.betweenPillsMax),
        Text(
          '$name $value',
          style: ApsiraTypography.meta.copyWith(color: tokens.ink2),
        ),
      ],
    );
  }
}
