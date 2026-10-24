// From lyceum test/domain/export/canonical_json_test.dart @ 9f4ff27
// P4-01: the bundle's JSON is canonical — keys sorted at every level, no
// insignificant whitespace, BLOBs as base64 — so the same data gives the
// same bytes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:test/test.dart';

void main() {
  test('keys are sorted at every level, in code-unit order', () {
    final text = encodeSortedJson({
      'b': 1,
      'a': {'z': null, 'Z': true, 'é': false},
      'c': [
        {'y': 2, 'x': 1},
      ],
    });
    expect(
      text,
      '{"a":{"Z":true,"z":null,"é":false},"b":1,"c":[{"x":1,"y":2}]}',
    );
  });

  test('values as stored: integers, text, reals, BLOBs as base64, null', () {
    final out = StringBuffer();
    writeSortedJson([
      -7,
      'línea "uno"\nlínea dos\u0001',
      1.5,
      Uint8List.fromList([0, 255, 1]),
      null,
      <Object?>[],
      <String, Object?>{},
    ], out);
    expect(
      out.toString(),
      '[-7,"línea \\"uno\\"\\nlínea dos\\u0001",1.5,"AP8B",null,[],{}]',
    );
    // It is JSON: it reads back.
    expect(jsonDecode(out.toString()), hasLength(7));
  });

  test('the same data in another insertion order gives the same bytes', () {
    expect(
      encodeSortedJson({'b': 2, 'a': 1}),
      encodeSortedJson({'a': 1, 'b': 2}),
    );
  });

  test('what JSON cannot hold is a bug', () {
    expect(() => encodeSortedJson(double.nan), throwsArgumentError);
    expect(() => encodeSortedJson(double.infinity), throwsArgumentError);
    expect(() => encodeSortedJson(DateTime(2026)), throwsArgumentError);
    expect(() => encodeSortedJson({1: 'x'}), throwsArgumentError);
  });
}
