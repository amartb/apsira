// The brand files are copied unchanged (docs/agent-rules.md): every file
// listed in lib/fonts/SHA256SUMS and lib/brand/SHA256SUMS hashes to its line,
// and every file apsira-brand/ supplies is byte-identical in lib/. The second
// half needs the repository's apsira-brand/ beside packages/; it is skipped
// with a notice when the package is used outside the repository.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `sha256sum` lines of [file]: file name → hex digest.
Map<String, String> sums(String file) => {
  for (final line in File(file).readAsLinesSync())
    if (line.trim().isNotEmpty)
      line.substring(66).replaceFirst(RegExp(r'^\*'), ''): line.substring(
        0,
        64,
      ),
};

String digest(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

/// The repository's brand directory, seen from the package root.
const brandRoot = '../../apsira-brand';

/// apsira-brand/ directory → the lib/ directory its files are copied to.
const copies = {
  '$brandRoot/06-fonts': 'lib/fonts',
  '$brandRoot/02-lockups/horizontal/png': 'lib/brand',
};

void main() {
  for (final dir in ['lib/fonts', 'lib/brand']) {
    test('every file in $dir/SHA256SUMS hashes to its line', () {
      final listed = sums('$dir/SHA256SUMS');
      expect(listed, isNotEmpty);
      for (final MapEntry(key: name, value: hex) in listed.entries) {
        expect(digest('$dir/$name'), hex, reason: '$dir/$name');
      }
    });

    test('every file in $dir but the sums and README is listed', () {
      final listed = sums('$dir/SHA256SUMS').keys.toSet();
      final present = {
        for (final f in Directory(dir).listSync().whereType<File>())
          f.uri.pathSegments.last,
      }..removeAll(['SHA256SUMS', 'README.md']);
      expect(present, listed);
    });
  }

  test('the files apsira-brand supplies are byte-identical in lib/', () {
    if (!Directory(brandRoot).existsSync()) {
      markTestSkipped(
        'apsira-brand/ not found at $brandRoot: the byte comparison with '
        'the brand runs only inside the apsira repository',
      );
      return;
    }
    // Every font file the brand supplies is shipped.
    for (final f in Directory(copies.keys.first).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      expect(
        File('lib/fonts/$name').existsSync(),
        isTrue,
        reason: 'lib/fonts/$name',
      );
      expect(digest('lib/fonts/$name'), digest(f.path), reason: name);
    }
    // Every lockup shipped is the brand's own file.
    for (final f in Directory('lib/brand').listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name == 'SHA256SUMS') continue;
      final source = '${copies.keys.last}/$name';
      expect(File(source).existsSync(), isTrue, reason: source);
      expect(digest('lib/brand/$name'), digest(source), reason: name);
    }
  });
}
