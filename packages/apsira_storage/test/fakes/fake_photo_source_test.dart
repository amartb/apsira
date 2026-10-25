// FakePhotoSource (relay test/fakes/fake_photo_source.dart @ 09b28810):
// answers its scripted results, the fixture photo by default.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_storage/apsira_storage.dart';
import 'package:apsira_storage/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hands over the fixture photo by default, nothing lost', () async {
    final source = FakePhotoSource();
    expect((await source.takePhoto()).valueOrNull, fixturePhoto);
    expect((await source.pickImages()).valueOrNull, [fixturePhoto]);
    expect((await source.recoverLost()).valueOrNull, isEmpty);
    expect((fixturePhoto.width, fixturePhoto.height), (40, 30));
  });

  test('answers a cancel or a failure when told to', () async {
    final source = FakePhotoSource(
      next: const Ok(null),
      picked: const Err(PhotoSource.cameraDenied),
      lost: const Ok([fixturePhoto]),
    );
    expect((await source.takePhoto()).valueOrNull, isNull);
    expect((await source.pickImages()).failureOrNull, PhotoSource.cameraDenied);
    expect((await source.recoverLost()).valueOrNull, [fixturePhoto]);
    source.next = const Err(PhotoSource.cameraUnavailable);
    expect(
      (await source.takePhoto()).failureOrNull,
      PhotoSource.cameraUnavailable,
    );
  });
}
