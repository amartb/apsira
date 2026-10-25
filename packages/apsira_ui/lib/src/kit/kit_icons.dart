// From lyceum lib/app/theme/app_icons.dart @ 9f4ff27 and relay
// lib/app/theme/note_row.dart `ListIcons` @ 09b28810: the glyphs the kit
// draws that are not chrome glyphs of ApsiraIcons.
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// The kit's own glyphs (Lucide, as every Apsira icon).
abstract final class KitIcons {
  /// A remove or clear button's ✕.
  static const IconData close = LucideIcons.x;

  /// A selected filter's check.
  static const IconData check = LucideIcons.check;

  /// The search field's glyph.
  static const IconData search = LucideIcons.search;

  /// The filter button's glyph.
  static const IconData tune = LucideIcons.sliders_horizontal;
}
