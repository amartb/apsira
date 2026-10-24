// From lyceum test/support/layout/android_font_scale.dart @ 9f4ff27, itself
// viaticum test/support/layout/android_font_scale.dart @ 78d38e0 (relay
// test/support/android_font_scaler.dart @ 09b28810 carries the same tables).

/// Android 14's non-linear font scaling, for the large-text layout harness
/// (from VIATICUM's, LYCEUM's and RELAY's identical copies).
///
/// From Android 14 the system scales large type less than body text: each
/// font scale has a table of sp → dp points, and sizes between two points
/// are interpolated (AOSP `FontScaleConverterFactory` and
/// `FontScaleConverterImpl`, API 34). On a phone Flutter's `MediaQuery`
/// reads this curve from the platform; in a host test it cannot, so the
/// harness carries the platform's tables. It models the platform only: any
/// cap on top is the app's own and stays in `lib/`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A [TextScaler] that scales as Android 14 does at one of its font scales.
@immutable
class AndroidFontScaler extends TextScaler {
  /// The scaler for the system font scale [factor]: 1.0 (linear) or one of
  /// the platform's tables ([tables]). Throws [ArgumentError] otherwise.
  AndroidFontScaler(this.factor)
    : _to = factor == 1
          ? null
          : tables[factor] ??
                (throw ArgumentError.value(
                  factor,
                  'factor',
                  'Android 14 has tables for ${tables.keys.join(', ')}',
                ));

  /// The system font scale.
  final double factor;

  final List<double>? _to;

  /// The sp points every table maps.
  static const List<double> fromSp = [8, 10, 12, 14, 18, 20, 24, 30, 100];

  /// The dp each point of [fromSp] becomes, by font scale.
  static final Map<double, List<double>> tables = {
    1.15: [9.2, 11.5, 13.8, 16.4, 19.8, 21.8, 25.2, 30, 100],
    1.3: [10.4, 13, 15.6, 18.8, 21.6, 23.6, 26.4, 30, 100],
    1.5: [12, 15, 18, 22, 24, 26, 28, 30, 100],
    1.8: [14.4, 18, 21.6, 24.4, 27.6, 30.8, 32.8, 34.8, 100],
    2: [16, 20, 24, 26, 30, 34, 36, 38, 100],
  };

  @override
  double scale(double fontSize) {
    final to = _to;
    if (to == null) return fontSize;
    final sp = fontSize.abs();
    final sign = fontSize.isNegative ? -1.0 : 1.0;
    // Past the last point: that point's ratio (1:1 at 100 sp).
    if (sp >= fromSp.last) return fontSize * to.last / fromSp.last;
    var lowerSp = 0.0;
    var lowerDp = 0.0;
    for (var i = 0; i < fromSp.length; i++) {
      if (sp <= fromSp[i]) {
        final t = (sp - lowerSp) / (fromSp[i] - lowerSp);
        return sign * (lowerDp + t * (to[i] - lowerDp));
      }
      lowerSp = fromSp[i];
      lowerDp = to[i];
    }
    throw StateError('unreachable');
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;

  @override
  bool operator ==(Object other) =>
      other is AndroidFontScaler && other.factor == factor;

  @override
  int get hashCode => Object.hash(AndroidFontScaler, factor);

  @override
  String toString() => 'AndroidFontScaler($factor×)';
}

/// The [TextScaler] Android 14 applies at the system font scale
/// [systemScale]: [AndroidFontScaler] by its interface's name.
TextScaler androidFontScale(double systemScale) =>
    AndroidFontScaler(systemScale);
