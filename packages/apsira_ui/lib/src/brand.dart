// From relay lib/app/licenses.dart and lib/app/bootstrap.dart
// (fontLicences, registerFontLicences) @ 5f606e9, with the lockup RELAY's
// assets/brand/README.md describes.

/// The brand files this package bundles: the Apsira Labs lockup and the
/// licences of the fonts and icons, by the keys a consumer's bundle holds
/// them under (`packages/apsira_ui/…`).
///
/// The fonts' OFL texts and Lucide's ISC licence sit where Flutter does not
/// collect them by itself (it reads only each package's root `LICENSE`), so
/// an app calls [registerLicences] once at start-up and the Licences page
/// lists them beside the packages' own.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// The Apsira Labs lockup and the bundled licences.
abstract final class ApsiraBrand {
  /// The package that bundles the files.
  static const package = 'apsira_ui';

  /// The Apsira Labs horizontal lockup, reversed colourway (for dark
  /// grounds), 1600 × 504 px, copied byte for byte from
  /// `apsira-brand/02-lockups/horizontal/png/`. RELAY shows it on its
  /// first-open intro at 200 px wide, above the brand's 160 px minimum for
  /// a horizontal lockup.
  static const lockupReversed = AssetImage(
    'lib/brand/apsira-labs-horizontal-reversed-1600w.png',
    package: package,
  );

  /// Each licence text's asset key, as a consumer's bundle holds it, to the
  /// name the Licences page shows (`lib/fonts/README.md`).
  static const licenceAssets = {
    'packages/apsira_ui/lib/fonts/LICENSE-Archivo.txt': 'Archivo Expanded',
    'packages/apsira_ui/lib/fonts/OFL-Archivo.txt': 'Archivo',
    'packages/apsira_ui/lib/fonts/OFL-JetBrainsMono.txt': 'JetBrains Mono',
    // Copied verbatim from flutter_lucide's lib/fonts/LICENSE.
    'packages/apsira_ui/lib/licenses/lucide.txt': 'Lucide',
  };

  /// Adds the three fonts' OFL and the Lucide icon font's ISC licence to the
  /// `LicenseRegistry`, read from [bundle] (the app's `rootBundle` when
  /// null) when the Licences page asks for them.
  static void registerLicences({AssetBundle? bundle}) {
    LicenseRegistry.addLicense(() async* {
      final source = bundle ?? rootBundle;
      for (final MapEntry(key: asset, value: name) in licenceAssets.entries) {
        yield LicenseEntryWithLineBreaks([
          name,
        ], await source.loadString(asset));
      }
    });
  }
}
