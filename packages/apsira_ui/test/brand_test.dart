// From relay test/app/licenses_test.dart @ 5f606e9, widened to the fonts'
// licences (RELAY's registerFontLicences in lib/app/bootstrap.dart) and the
// lockup. The package's own bundle holds its assets unqualified, so the
// licence texts are read through a bundle that maps a consumer's key
// (packages/apsira_ui/<path>) to the file; example/ proves the real bundle.
import 'dart:io';

import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a consumer's asset key from the package's own file.
class PackageFileBundle extends CachingAssetBundle {
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    const prefix = 'packages/apsira_ui/';
    expect(key, startsWith(prefix));
    final bytes = File(key.substring(prefix.length)).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

/// Every licence entry the registry yields, by its package names.
Future<Map<String, String>> registered() async => {
  await for (final entry in LicenseRegistry.licenses)
    entry.packages.join(', '): entry.paragraphs.map((p) => p.text).join('\n'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(LicenseRegistry.reset);

  test('the licence assets are the package-qualified licence files', () {
    expect(ApsiraBrand.licenceAssets, {
      'packages/apsira_ui/lib/fonts/LICENSE-Archivo.txt': 'Archivo Expanded',
      'packages/apsira_ui/lib/fonts/OFL-Archivo.txt': 'Archivo',
      'packages/apsira_ui/lib/fonts/OFL-JetBrainsMono.txt': 'JetBrains Mono',
      'packages/apsira_ui/lib/licenses/lucide.txt': 'Lucide',
    });
  });

  test('registerLicences adds the three OFLs and Lucide\'s ISC', () async {
    final bundle = PackageFileBundle();
    ApsiraBrand.registerLicences(bundle: bundle);
    final licences = await registered();
    expect(licences.keys.toSet(), {
      'Archivo Expanded',
      'Archivo',
      'JetBrains Mono',
      'Lucide',
    });
    expect(licences['Archivo Expanded'], contains('SIL OPEN FONT LICENSE'));
    expect(licences['Archivo'], contains('SIL Open Font License, Version 1.1'));
    expect(licences['JetBrains Mono'], contains('JetBrains Mono Project'));
    expect(licences['Lucide'], contains('ISC License'));
    expect(licences['Lucide'], contains('Lucide Contributors'));
    expect(bundle.requested.toSet(), ApsiraBrand.licenceAssets.keys.toSet());
  });

  test('the reversed lockup is the package\'s PNG', () {
    const lockup = ApsiraBrand.lockupReversed;
    expect(lockup.package, 'apsira_ui');
    expect(
      lockup.keyName,
      'packages/apsira_ui/lib/brand/apsira-labs-horizontal-reversed-1600w.png',
    );
    final bytes = File(lockup.assetName).readAsBytesSync();
    // PNG signature.
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
