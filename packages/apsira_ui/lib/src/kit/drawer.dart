// From lyceum lib/app/app_drawer_item.dart `_DrawerItem` and
// lib/app/app_drawer_parts.dart `_DrawerHeader` @ 9f4ff27 (RELAY's drawer
// entry and header, relay lib/features/shell/ui/app_drawer.dart): the
// module accent as an ApsiraFamily, a trailing slot, and the header's frame
// with the app's own mark, tagline and selector passed in (D-APK-014).
import 'package:flutter/material.dart';

import '../colors.dart';
import '../shape.dart';
import '../theme.dart';
import '../typography.dart';

/// A drawer entry as RELAY's: a 48 dp row, a 20 px glyph in a 24 px slot,
/// the label in `rowTitle`, a [count] and a [trailing] widget after it. The
/// active entry is a pill of `accC` across the panel, glyph and label in
/// `onAccC`; the others lie on the panel, glyph in `ink2`, or in its
/// [family]'s accent (the mark a module keeps in the drawer).
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.family,
    this.count = 0,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The family whose `solid` colours the glyph while not selected; null
  /// for destinations across the app.
  final ApsiraFamily? family;

  /// Shown after the label as RELAY's entry count (`meta`, `ink3`) when
  /// above zero.
  final int count;

  /// After the count: a badge, a chevron.
  final Widget? trailing;

  static const double _glyph = 20;
  static const double _slot = 24;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final accent = family == null ? null : t.family(family!).solid;
    final ink = selected ? t.onAccC : t.ink;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ApsiraSpacing.grid * 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? t.accC : t.accC.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(ApsiraRadii.drawerPanel),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: ApsiraSpacing.grid * 3,
                  end: ApsiraSpacing.grid * 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: _slot,
                      child: Center(
                        child: Icon(
                          icon,
                          size: _glyph,
                          color: selected ? t.onAccC : accent ?? t.ink2,
                        ),
                      ),
                    ),
                    const SizedBox(width: ApsiraSpacing.grid * 3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: ApsiraSpacing.grid * 2,
                        ),
                        child: Text(
                          label,
                          style: ApsiraTypography.rowTitle.copyWith(color: ink),
                        ),
                      ),
                    ),
                    if (count > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: ApsiraSpacing.grid * 2,
                        ),
                        child: Text(
                          '$count',
                          style: ApsiraTypography.meta.copyWith(
                            color: selected ? t.onAccC : t.ink3,
                          ),
                        ),
                      ),
                    if (trailing != null) ...[
                      const SizedBox(width: ApsiraSpacing.grid * 2),
                      trailing,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of a drawer: the app's [mark] (its wordmark), a [tagline] in
/// `ink2` under it and an optional [child] (a selector) below, at the
/// drawer's insets.
class DrawerHeaderBlock extends StatelessWidget {
  const DrawerHeaderBlock({
    super.key,
    required this.mark,
    this.tagline,
    this.child,
  });

  final Widget mark;

  /// Translated tagline.
  final String? tagline;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final tagline = this.tagline;
    final child = this.child;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ApsiraSpacing.grid * 5,
        ApsiraSpacing.grid * 6,
        ApsiraSpacing.grid * 4,
        ApsiraSpacing.grid * 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark,
          if (tagline != null) ...[
            const SizedBox(height: ApsiraSpacing.grid / 2),
            Text(
              tagline,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: t.ink2),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: ApsiraSpacing.grid * 4),
            child,
          ],
        ],
      ),
    );
  }
}
