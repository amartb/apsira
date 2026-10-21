// From relay test/app/theme/app_icons_test.dart @ 5f606e9: the chrome part.
// ApsiraIcons holds exactly the nine chrome glyphs, each its own Lucide glyph
// from flutter_lucide; the stored-icon registry is an app's own.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each chrome glyph and the Lucide glyph it is (RELAY's AppIcons @ 5f606e9).
const chrome = <String, (IconData, IconData)>{
  'back': (ApsiraIcons.back, LucideIcons.arrow_left),
  'chevron': (ApsiraIcons.chevron, LucideIcons.chevron_right),
  'plus': (ApsiraIcons.plus, LucideIcons.plus),
  'verified': (ApsiraIcons.verified, LucideIcons.circle_check),
  'running': (ApsiraIcons.running, LucideIcons.loader_circle),
  'failed': (ApsiraIcons.failed, LucideIcons.circle_x),
  'folder': (ApsiraIcons.folder, LucideIcons.folder),
  'dragHandle': (ApsiraIcons.dragHandle, LucideIcons.grip_vertical),
  'warning': (ApsiraIcons.warning, LucideIcons.triangle_alert),
};

void main() {
  test('there are nine chrome glyphs', () {
    expect(chrome, hasLength(9));
  });

  test('each chrome glyph is its Lucide glyph, from flutter_lucide', () {
    for (final MapEntry(key: name, value: (icon, lucide)) in chrome.entries) {
      expect(icon.codePoint, lucide.codePoint, reason: name);
      expect(icon.fontPackage, ApsiraIcons.fontPackage, reason: name);
      expect(icon.fontFamily, isNotNull, reason: name);
    }
    expect(ApsiraIcons.fontPackage, 'flutter_lucide');
  });

  test('every chrome glyph is its own glyph', () {
    final glyphs = <int, String>{};
    for (final MapEntry(key: name, value: (icon, _)) in chrome.entries) {
      final other = glyphs[icon.codePoint];
      expect(other, isNull, reason: '$name and $other share a glyph');
      glyphs[icon.codePoint] = name;
    }
  });
}
