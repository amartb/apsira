// From relay lib/features/home/ui/home_screen.dart `_showUndo` and
// lib/features/notes_list/ui/list_dialogs.dart `showListSnack` @ 09b28810
// (the 8 helpers' shape: hide the current snack, the message, Undo for
// 5 s) and viaticum lib/features/archives/ui/archive_people_sheets.dart
// `showUndoSnack` @ 78d38e0 (the failure snack), D-APK-014.
import 'dart:async';

import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter/material.dart';

/// Shows [message] on [messenger] with *Undo* (`commonUndo`) for
/// [duration], in place of the snack on screen; its look is the theme's
/// `snackBarTheme` (D-APK-013).
///
/// *Undo* calls [onUndo] once. When it returns false (the undo could not
/// write) and [undoFailedMessage] is given, that message follows as a snack
/// of its own; when it returns true nothing more is shown.
///
/// [persist] is Flutter's `SnackBar.persist`: left null, a snack with an
/// action stays until it is acted on or dismissed (RELAY's); false lets it
/// go after [duration] (VIATICUM's).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoSnack(
  ScaffoldMessengerState messenger, {
  required String message,
  required FutureOr<bool> Function() onUndo,
  String? undoFailedMessage,
  Duration duration = const Duration(seconds: 5),
  bool? persist,
}) {
  final l10n = ApsiraL10n.of(messenger.context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      persist: persist,
      action: SnackBarAction(
        label: l10n.commonUndo,
        onPressed: () async {
          final undone = await onUndo();
          final failed = undoFailedMessage;
          if (undone || failed == null || !messenger.mounted) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failed), duration: duration));
        },
      ),
    ),
  );
}
