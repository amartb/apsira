// From viaticum test/critical/layout_large_text_test.dart @ 78d38e0 (the
// "Android 14 font scaling" group) and lyceum
// test/critical/layout_check_controls_test.dart @ 9f4ff27 (its scaler test).
import 'package:apsira_test/apsira_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android 14 font scaling', () {
    test('1.0 is linear', () {
      final s = AndroidFontScaler(1);
      expect(s.scale(14), 14);
      expect(s.scale(34), 34);
    });

    test('reads the platform table at its points', () {
      expect(AndroidFontScaler(1.3).scale(18), closeTo(21.6, 1e-6));
      expect(AndroidFontScaler(1.5).scale(14), closeTo(22, 1e-6));
      expect(AndroidFontScaler(2).scale(14), closeTo(26, 1e-6));
      expect(AndroidFontScaler(2).scale(24), closeTo(36, 1e-6));
    });

    test('interpolates between points, so large type grows less', () {
      // 34 px display: between 30 -> 38 and 100 -> 100 at 2.0.
      expect(AndroidFontScaler(2).scale(34), closeTo(38 + 4 / 70 * 62, 1e-6));
      // 12.5 px pill: between 12 -> 24 and 14 -> 26.
      expect(AndroidFontScaler(2).scale(12.5), closeTo(24.5, 1e-6));
      // below the first point, from zero.
      expect(AndroidFontScaler(2).scale(4), closeTo(8, 1e-6));
    });

    test('Android 14 scales large type less than body text', () {
      final scaler = AndroidFontScaler(2);
      expect(scaler.scale(14), 26);
      expect(scaler.scale(30), 38);
      expect(AndroidFontScaler(1).scale(14), 14);
    });

    test('refuses a scale the platform has no table for', () {
      expect(() => AndroidFontScaler(1.4), throwsArgumentError);
      expect(() => AndroidFontScaler(1.7), throwsArgumentError);
    });

    test('androidFontScale is the scaler for a system font scale', () {
      final TextScaler s = androidFontScale(2);
      expect(s, AndroidFontScaler(2));
      expect(s.scale(14), 26);
      expect(androidFontScale(1.3), isNot(AndroidFontScaler(1.5)));
    });
  });
}
