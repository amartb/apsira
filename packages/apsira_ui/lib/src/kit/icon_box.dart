// From lyceum lib/app/theme/kit/list/icon_box.dart @ 9f4ff27 (relay's
// bordered icon tile, lib/app/theme/note_row.dart); LYCEUM's module and
// status become an ApsiraFamily and `filled` (D-APK-014).
import 'package:flutter/material.dart';

import '../colors.dart';
import '../shape.dart';
import '../theme.dart';

/// A rounded square holding an icon: the leading mark of list rows and
/// feature tiles. Corners from `ApsiraRadii.iconTiles` (40 px → 14), and the
/// 1 px `border` every Apsira surface carries.
///
/// A [family] is an accent: its `solid` icon on the neutral `tint` tile;
/// [filled] makes it a fill instead, the family's `container` with the icon
/// in `onContainer` (a status). With no family, an `ink2` icon on `tint`.
class IconBox extends StatelessWidget {
  const IconBox(
    this.icon, {
    super.key,
    this.family,
    this.filled = false,
    this.size = 40,
  });

  final IconData icon;
  final ApsiraFamily? family;

  /// Whether the [family] fills the tile (a status) rather than colouring
  /// the icon (a module's accent).
  final bool filled;
  final double size;

  /// The icon-tile radius of the defined tile size nearest [size] (32, 36,
  /// 40, 44; a 48 px header tile takes the 44 px radius).
  static double radiusFor(double size) {
    final nearest = ApsiraRadii.iconTiles.keys.reduce(
      (a, b) => (a - size).abs() <= (b - size).abs() ? a : b,
    );
    return ApsiraRadii.iconTiles[nearest]!;
  }

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final f = family == null ? null : t.family(family!);
    final (Color bg, Color fg) = switch (f) {
      null => (t.tint, t.ink2),
      final f when filled => (f.container, f.onContainer),
      final f => (t.tint, f.solid),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(radiusFor(size)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}
