// From relay lib/features/settings/ui/settings_rows.dart @ 09b28810 (the
// settings rows) and relay lib/app/theme/relay_theme.dart @ 09b28810 (the
// menu items), unchanged but for names (D-APK-013): `SettingsChoiceRow`'s
// options are `SettingsOption`s in place of `(value, label)` records.
//
// The pieces Settings is built from (UX §7.4; UX §2.1, §2.4; D-065, D-066):
// a group (its header, then a bordered card on `surface` with the card
// `shadow` in light mode), a row (a neutral 32 px icon tile, the label, an
// optional sub-line, then the value and a chevron, or a trailing widget such
// as a switch), and a choice row that opens the theme's menu (F8), the
// current choice checked.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'colors.dart';
import 'icons.dart';
import 'shape.dart';
import 'theme.dart';
import 'typography.dart';

/// The icon tile's size (UX §7.4).
const double settingsIconTile = 32;

/// A group: [title] above a card of [children], with an inset divider
/// between rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final shape = ApsiraShapes.rounded(ApsiraRadii.groupCard)
        .copyWith(side: BorderSide(color: t.border));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ApsiraSpacing.cardSide,
            0,
            ApsiraSpacing.cardSide,
            ApsiraSpacing.grid * 2,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: ApsiraTypography.meta.copyWith(color: t.ink2),
            ),
          ),
        ),
        DecoratedBox(
          decoration: ShapeDecoration(shape: shape, shadows: t.shadow),
          child: Material(
            color: t.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SettingsDivider(),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The inset divider between rows, from the text column to the card's side
/// padding, so it stays inside the card (UX §2.1 item 1).
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: ApsiraSpacing.cardSide + settingsIconTile + ApsiraSpacing.grid * 3,
    endIndent: ApsiraSpacing.cardSide,
    color: ApsiraTheme.of(context).border,
  );
}

/// A row: the icon tile, [label] and [subline], then [trailing], or
/// [value] and a chevron when [onTap] is given.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subline,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
  });

  final IconData icon;
  final String label;
  final String? subline;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Whether the chevron shows after the value; a row with nothing to open
  /// (the version) has none.
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final neutral = t.family(ApsiraFamily.neutral);
    final row = Padding(
      padding: ApsiraSpacing.taskRow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final valueMax = constraints.maxWidth * 0.4;
          // From 130 % text, the value goes under the label, which then keeps
          // the row's width for whole words (UX §5).
          final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
          return Row(
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: neutral.container,
                  shape: ApsiraShapes.rounded(
                    ApsiraRadii.iconTile(settingsIconTile),
                  ).copyWith(side: BorderSide(color: t.border)),
                ),
                child: SizedBox.square(
                  dimension: settingsIconTile,
                  child: Icon(icon, size: 18, color: neutral.onContainer),
                ),
              ),
              const SizedBox(width: ApsiraSpacing.grid * 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ApsiraTypography.rowTitle.copyWith(color: t.ink),
                    ),
                    if (subline case final subline?)
                      Text(
                        subline,
                        style: ApsiraTypography.meta.copyWith(color: t.ink2),
                      ),
                    if (stacked && value != null)
                      Text(
                        value!,
                        style: ApsiraTypography.snippet.copyWith(color: t.ink2),
                      ),
                  ],
                ),
              ),
              if (trailing case final trailing?)
                trailing
              else ...[
                if (value case final value? when !stacked)
                  ConstrainedBox(
                    // Beside the label, the value takes at most 40 % of the row.
                    constraints: BoxConstraints(maxWidth: valueMax),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: ApsiraSpacing.grid * 2,
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: ApsiraTypography.snippet.copyWith(color: t.ink2),
                      ),
                    ),
                  ),
                if (chevron) Icon(ApsiraIcons.chevron, size: 18, color: t.ink2),
              ],
            ],
          );
        },
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// One choice of a [SettingsChoiceRow]: its [value] and the [label] the
/// menu and the row show for it.
@immutable
final class SettingsOption<T> {
  const SettingsOption(this.value, this.label);

  final T value;
  final String label;
}

/// A row whose value is one of [options]: tapping it opens a menu of their
/// labels, the current one marked, and [onSelected] gets the choice.
class SettingsChoiceRow<T> extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.subline,
  });

  final IconData icon;
  final String label;
  final String? subline;

  /// The choices and their labels, in menu order.
  final List<SettingsOption<T>> options;

  /// The current choice; null shows no value.
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    String? labelOf(T? value) {
      for (final option in options) {
        if (option.value == value) return option.label;
      }
      return null;
    }

    return PopupMenuButton<T>(
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          ApsiraMenuItem(
            value: option.value,
            label: option.label,
            chosen: option.value == selected,
          ),
      ],
      child: SettingsRow(
        icon: icon,
        label: label,
        subline: subline,
        value: labelOf(selected),
      ),
    );
  }
}

/// A menu row (F8): an optional 20 dp leading [icon] in `ink2`, the
/// [label] in the theme's menu text, and on a select menu a check mark in
/// `accentText` after the [chosen] one. A [danger] row (Trash, Delete)
/// takes the red-orange solid for its icon and label (D-065: colour marks
/// the destructive action, never fills the row).
class ApsiraMenuItem<T> extends PopupMenuItem<T> {
  ApsiraMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    required String label,
    IconData? icon,
    bool danger = false,
    bool chosen = false,
  }) : super(
         child: _ApsiraMenuRow(
           label: label,
           icon: icon,
           danger: danger,
           chosen: chosen,
           enabled: enabled,
         ),
       );

  /// The check mark after the chosen row (RELAY's `AppIcons.chosen`).
  static const IconData chosenMark = LucideIcons.check;
}

class _ApsiraMenuRow extends StatelessWidget {
  const _ApsiraMenuRow({
    required this.label,
    required this.icon,
    required this.danger,
    required this.chosen,
    required this.enabled,
  });

  final String label;
  final IconData? icon;
  final bool danger;
  final bool chosen;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final mark = !enabled
        ? t.ink3
        : danger
        ? t.family(ApsiraFamily.redOrange).solid
        : null;
    return Semantics(
      selected: chosen,
      child: Row(
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: 20, color: mark ?? t.ink2),
            const SizedBox(width: ApsiraSpacing.grid * 3),
          ],
          Expanded(
            child: Text(
              label,
              style: mark == null ? null : TextStyle(color: mark),
            ),
          ),
          if (chosen)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ApsiraSpacing.grid * 3,
              ),
              child: Icon(
                ApsiraMenuItem.chosenMark,
                size: 20,
                color: t.accentText,
              ),
            ),
        ],
      ),
    );
  }
}

/// One of an [ApsiraMenuButtons] row's actions: its menu [value], [icon]
/// and [label], and whether it can be chosen now.
@immutable
final class ApsiraMenuButton<T> {
  const ApsiraMenuButton({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.key,
  });

  final T value;
  final IconData icon;
  final String label;
  final bool enabled;
  final Key? key;
}

/// Paired actions side by side at a menu's top (F8: the note's Undo and
/// Redo): bordered `tint` buttons of 48 dp, each closing the menu with its
/// value. From 130 % text they stack, so a label is never broken.
class ApsiraMenuButtons<T> extends PopupMenuEntry<T> {
  const ApsiraMenuButtons({super.key, required this.buttons});

  final List<ApsiraMenuButton<T>> buttons;

  @override
  double get height => kMinInteractiveDimension + ApsiraSpacing.grid * 2;

  @override
  bool represents(T? value) => false;

  @override
  State<ApsiraMenuButtons<T>> createState() => _ApsiraMenuButtonsState<T>();
}

class _ApsiraMenuButtonsState<T> extends State<ApsiraMenuButtons<T>> {
  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final shape = ApsiraShapes.rounded(ApsiraRadii.iconTile(40))
        .copyWith(side: BorderSide(color: t.border));
    Widget button(ApsiraMenuButton<T> b) {
      final ink = b.enabled ? t.ink : t.ink3;
      return Semantics(
        button: true,
        enabled: b.enabled,
        child: Material(
          key: b.key,
          color: t.tint,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: b.enabled ? () => Navigator.pop<T>(context, b.value) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ApsiraSpacing.grid * 2,
                  vertical: ApsiraSpacing.grid,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(b.icon, size: 18, color: b.enabled ? t.ink2 : t.ink3),
                    const SizedBox(width: ApsiraSpacing.grid * 1.5),
                    Flexible(
                      child: Text(
                        b.label,
                        style: ApsiraTypography.snippet.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    const gap = SizedBox.square(dimension: ApsiraSpacing.grid * 2);
    final children = [
      for (final (i, b) in widget.buttons.indexed) ...[
        if (i > 0) gap,
        if (stacked) button(b) else Expanded(child: button(b)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: ApsiraSpacing.grid * 2),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            )
          : Row(children: children),
    );
  }
}
