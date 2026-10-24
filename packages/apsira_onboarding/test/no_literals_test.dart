// D-APK-017, task-specs "Every task": no visible string is written in lib/
// (each comes from ApsiraL10n or a constructor parameter), and no colour
// literal (they live in apsira_ui's colors.dart only).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> _hits(RegExp pattern) => [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      for (final (i, line) in f.readAsLinesSync().indexed)
        if (pattern.hasMatch(line)) '${f.path}:${i + 1}: $line',
];

void main() {
  test('no Text, label or tooltip in lib/ is given a string literal', () {
    expect(
      _hits(RegExp(r'''(Text\(|label: |tooltip: )\s*['"][A-Za-z]''')),
      isEmpty,
    );
  });

  test('no colour literal in lib/', () {
    expect(_hits(RegExp(r'Color\(|Colors\.')), isEmpty);
  });
}
