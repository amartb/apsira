// From lyceum lib/app/theme/kit/state/empty_state.dart @ 9f4ff27 (RELAY's
// welcome card: the card, its icon tile, title, message and tonal pill),
// with relay lib/app/theme/empty_state.dart @ 09b28810's action as a label,
// a callback and a key in place of an action widget (D-APK-014).
import 'package:flutter/material.dart';

import '../colors.dart';
import '../shape.dart';
import '../theme.dart';
import '../typography.dart';
import 'icon_box.dart';
import 'pill_buttons.dart';

/// The one empty state: an empty list, day, view or section says what goes
/// there and offers its action as a button. A card (`surface`, its 1 px
/// `border`, the `ApsiraRadii.groupCard` corners) holding an icon tile, the
/// [title] in `cardTitle`, an optional `ink2` [message] and, with
/// [actionLabel] and [onAction], the action drawn as the tonal pill. No
/// illustrations.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.family,
    this.compact = false,
  });

  final IconData icon;

  /// What goes here ("No sources yet"), translated by the app.
  final String title;

  /// Guidance ("Add one with +"), translated by the app.
  final String? message;

  /// The action's label; with [onAction], the button under the text.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The action button's key, where a screen keeps the one its own button
  /// had.
  final Key? actionKey;

  /// Draws the icon in a family's `solid`; `ink2` without one ([IconBox]).
  final ApsiraFamily? family;

  /// The inline variant for empty tabs and sections: a smaller tile, less
  /// space around the card.
  final bool compact;

  /// The icon tile's size: RELAY's 40 px editor tile, 36 px when compact.
  static const double _tile = 40;
  static const double _compactTile = 36;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final label = actionLabel;
    final onAction = this.onAction;
    final message = this.message;
    final card = Material(
      // A Material, not a decorated box: a list tile or an ink well inside
      // draws its ink on the card.
      color: t.surface,
      shape: ApsiraShapes.rounded(ApsiraRadii.groupCard)
          .copyWith(side: BorderSide(color: t.border)),
      child: Padding(
        padding: const EdgeInsets.all(ApsiraSpacing.cardSide),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: IconBox(
                icon,
                family: family,
                size: compact ? _compactTile : _tile,
              ),
            ),
            const SizedBox(height: ApsiraSpacing.grid * 3),
            Semantics(
              header: true,
              child: Text(
                title,
                style: ApsiraTypography.cardTitle.copyWith(color: t.ink),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: ApsiraSpacing.grid * 2),
              Text(
                message,
                style: ApsiraTypography.body.copyWith(color: t.ink2),
              ),
            ],
            if (label != null && onAction != null) ...[
              const SizedBox(height: ApsiraSpacing.grid * 4),
              TextButton(
                key: actionKey,
                style: PillButtons.tonal(t),
                onPressed: onAction,
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: ApsiraSpacing.screenGutter,
          vertical: ApsiraSpacing.grid * (compact ? 2 : 4),
        ),
        child: SizedBox(width: double.infinity, child: card),
      ),
    );
  }
}
