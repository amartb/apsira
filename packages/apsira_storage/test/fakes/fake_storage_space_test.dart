// FakeStorageSpace (lyceum test/fakes/fake_storage_space.dart @ 9f4ff27,
// with freeBytes): answers what it is set to, null by default, and counts
// the questions.
import 'package:apsira_storage/apsira_storage.dart';
import 'package:apsira_storage/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is unmeasurable by default', () async {
    final space = FakeStorageSpace();
    expect(space, isA<StorageSpace>());
    expect(await space.appFreeBytes(), isNull);
    expect(await space.freeBytes('t'), isNull);
  });

  test('answers what it is set to and records each question', () async {
    final space = FakeStorageSpace(free: 10, folderFree: 20);
    expect(await space.appFreeBytes(), 10);
    expect(await space.freeBytes('content://tree/a'), 20);
    space.free = 0;
    expect(await space.appFreeBytes(), 0);
    expect(space.calls, 2);
    expect(space.folders, ['content://tree/a']);
  });
}
