// AC-5.6: no visible string is written in the package; every one is the
// app's, passed in (until apsira_l10n, D-APK-008).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no Text widget in lib/ is given a string literal', () {
    final literal = RegExp(r'''Text\(\s*['"]''');
    final hits = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (literal.hasMatch(line)) '${f.path}:${i + 1}: $line',
    ];
    expect(hits, isEmpty);
  });
}
