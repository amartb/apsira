// From relay lib/features/notes_list/ui/list_widgets.dart @ 09b28810
// (FilterPill, AddFilterPill and its dashed stadium) and lyceum
// lib/app/theme/kit/feedback/status_pill.dart @ 9f4ff27 (StatusPill as
// FamilyPill, TagPill, StatusDot, their pill), LyceumStatus → ApsiraFamily
// (D-APK-014).
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../colors.dart';
import '../icons.dart';
import '../shape.dart';
import '../theme.dart';
import '../typography.dart';
import 'kit_icons.dart';

/// A selected filter pill: `accC` fill with a check, its label, and a
/// remove button.
///
/// The pill is drawn [visualHeight] high (pills are 24–40), and it and its
/// remove button take [height], Android's 48 dp tap target, as Material's
/// chips do.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  /// The height every filter pill and their strip take: the tap target.
  static const double height = 48;

  /// The height a filter pill is drawn, centred in [height].
  static const double visualHeight = ApsiraSizes.pillMaxHeight;

  /// The space above and below the drawn pill.
  static const double inset = (height - visualHeight) / 2;

  final String label;

  /// The remove button's spoken label ("Remove filter …").
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final style = ApsiraTypography.pill.copyWith(color: t.onAccC);
    return Stack(
      children: [
        Positioned.fill(
          top: inset,
          bottom: inset,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: t.accC,
              shape: StadiumBorder(side: BorderSide(color: t.border)),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: ApsiraSpacing.grid * 3),
              Icon(KitIcons.check, size: 16, color: t.onAccC),
              const SizedBox(width: ApsiraSpacing.betweenPills),
              // The label wraps at large text and the pill grows with it
              // (D-APK-014; RELAY's overflowed past the screen at 150 %).
              Flexible(child: Text(label, style: style)),
              IconButton(
                tooltip: removeLabel,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(height),
                ),
                onPressed: onRemove,
                icon: Icon(KitIcons.close, size: 16, color: t.onAccC),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "+ Filter": a dashed `ring` pill on the ground, drawn and tappable as
/// [FilterPill] is.
class AddFilterPill extends StatelessWidget {
  const AddFilterPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedStadium(t.ring),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: FilterPill.height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ApsiraIcons.plus, size: 16, color: t.ink2),
                  const SizedBox(width: ApsiraSpacing.betweenPills),
                  Text(
                    label,
                    style: ApsiraTypography.pill.copyWith(color: t.ink2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A stadium outline in dashes, [FilterPill.inset] in from the top and
/// the bottom.
class _DashedStadium extends CustomPainter {
  const _DashedStadium(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      0.5,
      FilterPill.inset + 0.5,
      size.width - 0.5,
      size.height - FilterPill.inset - 0.5,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height)));
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadium old) => old.colour != colour;
}

/// Diameter of a family pill's leading dot.
const double _pillDot = 6;

/// A fully rounded pill in a family, as a status or a module: the family's
/// tonal fill, its `onContainer` label and, unless an [icon] leads, a dot in
/// its `solid` (an Apsira pill has no outline). Colour is never the only
/// signal: the label always says what it is.
class FamilyPill extends StatelessWidget {
  const FamilyPill({
    super.key,
    required this.label,
    this.family = ApsiraFamily.neutral,
    this.icon,
  });

  /// Translated label.
  final String label;
  final ApsiraFamily family;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final f = ApsiraTheme.of(context).family(family);
    return _Pill(
      label: label,
      fg: f.onContainer,
      bg: f.container,
      icon: icon,
      dot: icon == null ? f.solid : null,
    );
  }
}

/// A neutral outlined pill for tags and free-form labels: no fill, the
/// surface `border` as its edge, the label in `ink2`.
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.onDeleted,
    this.deleteTooltip,
  });

  final String label;
  final VoidCallback? onDeleted;

  /// Translated tooltip for the remove button (wanted with [onDeleted]).
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return _Pill(
      label: label,
      fg: t.ink2,
      border: t.border,
      onDeleted: onDeleted,
      deleteTooltip: deleteTooltip,
    );
  }
}

/// An 8 px dot for dense status marks next to text, in a family's `solid`.
/// Always pair it with a text label or a [semanticsLabel]: never colour
/// alone.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    this.family = ApsiraFamily.neutral,
    this.semanticsLabel,
    this.size = 8,
  });

  final ApsiraFamily family;
  final String? semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ApsiraTheme.of(context).family(family).solid,
        shape: BoxShape.circle,
      ),
    );
    if (semanticsLabel == null) return dot;
    return Semantics(label: semanticsLabel, child: dot);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fg,
    this.bg,
    this.border,
    this.icon,
    this.dot,
    this.onDeleted,
    this.deleteTooltip,
  });

  final String label;
  final Color fg;

  /// The tonal fill; none for an outlined pill.
  final Color? bg;

  /// The outline; none for a tonal pill.
  final Color? border;
  final IconData? icon;

  /// The leading dot's colour; none when an [icon] leads.
  final Color? dot;
  final VoidCallback? onDeleted;
  final String? deleteTooltip;

  static const double _xxs = ApsiraSpacing.grid / 2;
  static const double _iconSize = 14;

  /// LYCEUM's `LyceumRadius.full`: fully round at any height.
  static const double _full = 999;

  @override
  Widget build(BuildContext context) {
    final style = ApsiraTypography.pill.copyWith(color: fg);
    final lead = icon != null || dot != null;
    final border = this.border;
    return Container(
      constraints: const BoxConstraints(minHeight: ApsiraSizes.pillMinHeight),
      padding: EdgeInsets.fromLTRB(
        lead ? ApsiraSpacing.grid * 2 - _xxs : ApsiraSpacing.grid * 2,
        _xxs,
        onDeleted == null ? ApsiraSpacing.grid * 2 : _xxs,
        _xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_full),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: fg),
            const SizedBox(width: ApsiraSpacing.grid),
          ] else if (dot != null) ...[
            Container(
              width: _pillDot,
              height: _pillDot,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: ApsiraSpacing.grid + _xxs),
          ],
          // The label wraps and the pill grows (min height, never fixed).
          Flexible(child: Text(label, style: style)),
          if (onDeleted != null)
            Tooltip(
              message: deleteTooltip ?? '',
              child: InkResponse(
                onTap: onDeleted,
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(_xxs),
                  child: Icon(KitIcons.close, size: _iconSize, color: fg),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
