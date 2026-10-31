import 'dart:io';

import 'package:apsira_link/testing/link_release_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

// The example's release-manifest test (contract app-link.md §3.3, rulings
// R-2 and R-5), the one each adopting app writes for its own manifests: the
// dev switch is declared in the dev source set (here src/debug) and in no
// manifest a release build merges.
String _manifest(String path) => File(path).readAsStringSync();

void main() {
  test('the debug source set declares the switch', () {
    expect(
      declaresLinkDevSwitch(
        _manifest('android/app/src/debug/AndroidManifest.xml'),
      ),
      isTrue,
    );
  });

  for (final path in [
    'android/app/src/main/AndroidManifest.xml',
    'android/app/src/profile/AndroidManifest.xml',
    '../android/src/main/AndroidManifest.xml',
  ]) {
    test('$path does not declare the switch', () {
      expect(declaresLinkDevSwitch(_manifest(path)), isFalse);
    });
  }
}
