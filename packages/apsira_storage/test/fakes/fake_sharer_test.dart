// FakeSharer (relay test/fakes/fake_sharer.dart @ 09b28810, with viaticum
// test/fakes/fake_sharer.dart @ 78d38e0's contents): records every share,
// answers its outcome, throws its error.
import 'dart:io';

import 'package:apsira_storage/apsira_storage.dart';
import 'package:apsira_storage/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records texts and files in order and answers the outcome', () async {
    final sharer = FakeSharer(outcome: ShareOutcome.dismissed);
    expect(
      await sharer.shareText('hello', subject: 's'),
      ShareOutcome.dismissed,
    );
    expect(
      await sharer.shareFile('no/such/file', mimeType: 'text/plain'),
      ShareOutcome.dismissed,
    );
    expect(sharer.texts, [(text: 'hello', subject: 's')]);
    expect(sharer.files, [
      (path: 'no/such/file', mimeType: 'text/plain', subject: null),
    ]);
    expect(sharer.contents, [null], reason: 'no file at the path');
  });

  test('keeps the bytes a shared file had when it was shared', () async {
    final dir = Directory.systemTemp.createTempSync('fake_sharer');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/a.csv')..writeAsBytesSync([1, 2, 3]);
    final sharer = FakeSharer();
    await sharer.shareFile(file.path, mimeType: 'text/csv');
    file.writeAsBytesSync([9]);
    expect(sharer.contents, [
      [1, 2, 3],
    ]);
  });

  test('with an error set, both throw it after recording', () async {
    final sharer = FakeSharer(error: StateError('no sheet'));
    await expectLater(sharer.shareText('x'), throwsStateError);
    await expectLater(
      sharer.shareFile('p', mimeType: 'text/plain'),
      throwsStateError,
    );
    expect(sharer.texts, hasLength(1));
    expect(sharer.files, hasLength(1));
  });
}
