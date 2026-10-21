// From relay lib/app/theme/app_icons.dart @ 5f606e9: the chrome glyphs only.
// The stored-icon registry (ids a database keeps, the type picker, the value
// types) is an app's own and stays in the app.
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// The chrome glyphs every Apsira app shares, over the Lucide glyphs of
/// `flutter_lucide` (D-068, UX §2.6). Screens take these from here, never
/// from the package, so the set can be swapped in one file.
abstract final class ApsiraIcons {
  /// The package every glyph comes from.
  static const String fontPackage = 'flutter_lucide';

  /// A backup verified, a check passed.
  static const IconData verified = LucideIcons.circle_check;

  /// Work in progress (a running backup).
  static const IconData running = LucideIcons.loader_circle;

  /// A failed run.
  static const IconData failed = LucideIcons.circle_x;

  /// A folder.
  static const IconData folder = LucideIcons.folder;

  /// The handle of a reorderable row.
  static const IconData dragHandle = LucideIcons.grip_vertical;

  /// The trailing chevron of a row that opens a screen.
  static const IconData chevron = LucideIcons.chevron_right;

  /// The glyph of a button that creates something.
  static const IconData plus = LucideIcons.plus;

  /// The leading control of a screen that goes back.
  static const IconData back = LucideIcons.arrow_left;

  /// A warning line: something that can't run.
  static const IconData warning = LucideIcons.triangle_alert;
}
