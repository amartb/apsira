// From lyceum test/support/layout/bundled_fonts.dart @ 9f4ff27 and relay
// test/support/golden/relay_golden.dart @ 09b28810 (loadRelayFonts): the
// fonts of the asset bundle, apsira_ui's among them, load into the engine.
import 'package:apsira_test/apsira_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("loads every family of the bundle, apsira_ui's included", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final families = await loadBundledFonts();
    expect(
      families,
      containsAll(<String>[
        'packages/apsira_ui/ArchivoExpanded',
        'packages/apsira_ui/Archivo',
        'packages/apsira_ui/JetBrainsMono',
      ]),
    );
  });

  test('loadAppFonts loads once and returns the same families', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final first = loadAppFonts();
    expect(identical(first, loadAppFonts()), isTrue);
    expect(await first, contains('packages/apsira_ui/Archivo'));
  });
}
