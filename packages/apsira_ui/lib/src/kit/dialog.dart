// From lyceum lib/app/theme/kit/overlay/lyceum_dialog.dart @ 9f4ff27
// (showLyceumDialog, LyceumDialog, confirmDestructive, confirmAction,
// destructiveButtonStyle), the surface drawn from the tokens rather than
// from `buildFull`'s dialogTheme, the labels from ApsiraL10n (D-APK-014).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter/material.dart';

import '../colors.dart';
import '../theme.dart';

/// Shows the one dialog shape, an [ApsiraDialog] over the `scrim`.
///
/// [content] may be a `String` (rendered as body text) or a `Widget`.
Future<T?> showApsiraDialog<T>({
  required BuildContext context,
  required String title,
  Object? content,
  List<Widget> Function(BuildContext dialogContext)? actions,
  bool barrierDismissible = true,
  bool scrollable = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: ApsiraTheme.of(context).scrim,
    builder: (ctx) => ApsiraDialog(
      title: title,
      content: content,
      actions: actions?.call(ctx) ?? const [],
      scrollable: scrollable,
    ),
  );
}

/// The one dialog: an [AlertDialog] on `surface`, with the group-card
/// radius and its 1 px `border` (`ApsiraThemeData.dialogShape`) and no
/// surface tint, from the tokens, the same under `build` and `buildFull`.
/// Use it directly only where an API needs a dialog widget; otherwise call
/// [showApsiraDialog].
///
/// [content] may be a `String` (rendered as body text) or a `Widget`.
class ApsiraDialog extends StatelessWidget {
  const ApsiraDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
    this.icon,
    this.scrollable = false,
  });

  final String title;
  final Object? content;
  final List<Widget> actions;

  /// Optional icon above the title (a warning for a security prompt).
  final Widget? icon;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return AlertDialog(
      backgroundColor: t.surface,
      surfaceTintColor: ApsiraSchemeColors.transparent,
      shape: ApsiraThemeData.dialogShape(t),
      icon: icon,
      title: Text(title),
      scrollable: scrollable,
      content: switch (content) {
        null => null,
        final String s => Text(s),
        final Widget w => w,
        _ => Text('$content'),
      },
      actions: actions.isEmpty ? null : actions,
    );
  }
}

/// Asks the user to confirm a destructive action. The confirm button is
/// labelled with the specific verb ([confirmLabel], "Delete source";
/// `commonDelete` by default), drawn in the error fill, and the dialog
/// resolves to `true` only when it is pressed: cancel and the barrier give
/// `false`. The title and message scroll, so a long message is never cut
/// at a large text scale.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showApsiraDialog<bool>(
    context: context,
    title: title,
    content: message,
    scrollable: true,
    actions: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: Text(cancelLabel ?? ApsiraL10n.of(ctx).commonCancel),
      ),
      FilledButton(
        style: destructiveButtonStyle(ApsiraTheme.of(ctx)),
        onPressed: () => Navigator.of(ctx).pop(true),
        child: Text(confirmLabel ?? ApsiraL10n.of(ctx).commonDelete),
      ),
    ],
  );
  return result ?? false;
}

/// Asks the user to confirm a non-destructive action; `true` only on
/// confirm (`commonConfirm` by default).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showApsiraDialog<bool>(
    context: context,
    title: title,
    content: message,
    actions: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: Text(cancelLabel ?? ApsiraL10n.of(ctx).commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(ctx).pop(true),
        child: Text(confirmLabel ?? ApsiraL10n.of(ctx).commonConfirm),
      ),
    ],
  );
  return result ?? false;
}

/// The filled-button style of a destructive action: the error fill (the
/// red-orange family's `solid`) with its AA on-colour, as the theme's
/// `colorScheme.error` and `onError`.
ButtonStyle destructiveButtonStyle(ApsiraTheme t) {
  final scheme = ApsiraThemeData.colorScheme(t);
  return FilledButton.styleFrom(
    backgroundColor: scheme.error,
    foregroundColor: scheme.onError,
  );
}
