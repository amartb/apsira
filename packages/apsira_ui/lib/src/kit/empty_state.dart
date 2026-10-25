// From lyceum lib/app/theme/kit/state/empty_state.dart @ 9f4ff27 (RELAY's
// welcome card: the card, its icon tile, title, message and tonal pill),
// with relay lib/app/theme/empty_state.dart @ 09b28810's action as a label,
// a callback and a key in place of an action widget (D-APK-014); LYCEUM's
// `FilledButton.tonalIcon` actions are [EmptyState.actionIcon] and the mic
// rationale's Cancel the second action (audio_recorder_parts.dart @ 9f4ff27).
// [EmptyState.inline] is relay lib/app/theme/empty_state.dart @ 09b28810
// unchanged but for names: its `line` is `title`, its `action` `actionLabel`.
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
/// [actionLabel] and [onAction], the action drawn as the tonal pill (with
/// [actionIcon] before its label) and, with [secondaryActionLabel] and
/// [onSecondaryAction], a second tonal pill under it. No illustrations.
///
/// [EmptyState.inline] is RELAY's cardless variant for a list, day or view
/// that has its own padding: a bordered `tint` block on the
/// `ApsiraRadii.insetBlock` radius with a `surface` icon tile, the [title] in
/// `ink2` and the action as an `accentText` text button under it, at least
/// 48 dp tall.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionKey,
    this.family,
    this.compact = false,
  }) : _inline = false;

  /// RELAY's inline block: the icon tile, the [title] as its one line and
  /// the action as a text button.
  const EmptyState.inline({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  }) : message = null,
       actionIcon = null,
       secondaryActionLabel = null,
       onSecondaryAction = null,
       secondaryActionKey = null,
       family = null,
       compact = false,
       _inline = true;

  /// The inline block's decoration (RELAY's key).
  static const blockKey = ValueKey('emptyState/block');

  /// The inline block's icon tile (RELAY's key).
  static const iconTileKey = ValueKey('emptyState/icon');

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

  /// The action's glyph before its label (LYCEUM's +), at 20 px;
  /// none by default.
  final IconData? actionIcon;

  /// The second action's label ("Cancel"); with [onSecondaryAction], a
  /// tonal pill under the first.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// The second action button's key.
  final Key? secondaryActionKey;

  /// Draws the icon in a family's `solid`; `ink2` without one ([IconBox]).
  final ApsiraFamily? family;

  /// The inline variant for empty tabs and sections: a smaller tile, less
  /// space around the card.
  final bool compact;

  final bool _inline;

  /// The icon tile's size: RELAY's 40 px editor tile, 36 px when compact.
  static const double _tile = 40;
  static const double _compactTile = 36;

  /// The action's glyph: LYCEUM's `LyceumIconSize.md`.
  static const double _actionIconSize = 20;

  /// RELAY's inline tile and its glyph.
  static const double _inlineTile = 36;
  static const double _inlineGlyph = 18;

  @override
  Widget build(BuildContext context) {
    if (_inline) return _buildInline(context);
    final t = ApsiraTheme.of(context);
    final label = actionLabel;
    final onAction = this.onAction;
    final actionIcon = this.actionIcon;
    final secondaryLabel = secondaryActionLabel;
    final onSecondary = onSecondaryAction;
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
              if (actionIcon == null)
                TextButton(
                  key: actionKey,
                  style: PillButtons.tonal(t),
                  onPressed: onAction,
                  child: Text(label),
                )
              else
                TextButton.icon(
                  key: actionKey,
                  style: PillButtons.tonal(t),
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: _actionIconSize),
                  label: Text(label),
                ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              // Under the first as LYCEUM stacked them; alone, where the
              // first would be.
              SizedBox(
                height: label != null && onAction != null
                    ? ApsiraSpacing.grid
                    : ApsiraSpacing.grid * 4,
              ),
              TextButton(
                key: secondaryActionKey,
                style: PillButtons.tonal(t),
                onPressed: onSecondary,
                child: Text(secondaryLabel),
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

  Widget _buildInline(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final label = actionLabel;
    final onAction = this.onAction;
    return DecoratedBox(
      key: blockKey,
      decoration: ShapeDecoration(
        color: t.tint,
        shape: ApsiraShapes.rounded(ApsiraRadii.insetBlock)
            .copyWith(side: BorderSide(color: t.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ApsiraSpacing.grid * 4,
          ApsiraSpacing.grid * 3,
          ApsiraSpacing.grid * 4,
          ApsiraSpacing.grid * 3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                key: iconTileKey,
                decoration: ShapeDecoration(
                  color: t.surface,
                  shape: ApsiraShapes.rounded(ApsiraRadii.iconTile(_inlineTile))
                      .copyWith(side: BorderSide(color: t.border)),
                ),
                child: SizedBox.square(
                  dimension: _inlineTile,
                  child: Icon(icon, size: _inlineGlyph, color: t.accentText),
                ),
              ),
            ),
            const SizedBox(width: ApsiraSpacing.grid * 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: ApsiraSpacing.grid * 2),
                    child: Text(
                      title,
                      style: ApsiraTypography.body.copyWith(color: t.ink2),
                    ),
                  ),
                  if (label != null && onAction != null)
                    TextButton(
                      key: actionKey,
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: t.accentText,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: ApsiraSpacing.grid * 2,
                        ),
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      child: Text(label, style: ApsiraTypography.pill),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
