// From relay test/fakes/fake_photo_source.dart @ 09b28810.
import 'package:apsira_core/apsira_core.dart';

import '../photo_source.dart';

/// RELAY's fixture photo (its test/fixtures/media/photo.jpg, 40 × 30; this
/// package's test/fixtures/media holds the same file). No file need be
/// behind it.
const fixturePhoto = CapturedPhoto(
  path: 'test/fixtures/media/photo.jpg',
  mimeType: 'image/jpeg',
  originalName: 'photo.jpg',
  width: 40,
  height: 30,
);

/// A photo source that returns fixture photos, a cancel or a failure.
final class FakePhotoSource implements PhotoSource {
  FakePhotoSource({
    this.next = const Ok(fixturePhoto),
    this.picked = const Ok([fixturePhoto]),
    this.lost = const Ok([]),
  });

  /// What the next [takePhoto] returns.
  Result<CapturedPhoto?, Failure> next;

  /// What the next [pickImages] returns.
  Result<List<CapturedPhoto>, Failure> picked;

  /// What the next [recoverLost] returns.
  Result<List<CapturedPhoto>, Failure> lost;

  @override
  Future<Result<CapturedPhoto?, Failure>> takePhoto() async => next;

  @override
  Future<Result<List<CapturedPhoto>, Failure>> pickImages() async => picked;

  @override
  Future<Result<List<CapturedPhoto>, Failure>> recoverLost() async => lost;
}
