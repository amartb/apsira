// From relay test/data/platform/image_picker_photo_source_test.dart @
// 09b28810, with the optional PhotoSizing LYCEUM's capture uses (D-APK-015).
// ImagePickerPhotoSource (07 P2-06, D-017): the system camera and the
// Android photo picker with multi-select, through image_picker, asked for
// no resizing and no re-encoding; the photo's MIME type and upright size
// come from its first bytes (ImageMeta), and the camera's failures are
// codes. The picker is a fake subclass; the files are the media fixtures.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

const _media = 'test/fixtures/media';

/// Every call's arguments, and what each call answers.
final class _FakePicker extends ImagePicker {
  _FakePicker({this.one, this.many = const [], this.lost, this.error});

  XFile? one;
  List<XFile> many;
  LostDataResponse? lost;
  Object? error;

  final calls = <String>[];
  final sizing = <(double?, double?, int?)>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add('pickImage ${source.name}');
    sizing.add((maxWidth, maxHeight, imageQuality));
    if (error case final error?) throw error;
    return one;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls.add('pickMultiImage');
    sizing.add((maxWidth, maxHeight, imageQuality));
    if (error case final error?) throw error;
    return many;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    calls.add('retrieveLostData');
    return lost ?? LostDataResponse.empty();
  }
}

void main() {
  late ImagePickerPlatform before;
  setUp(() => before = ImagePickerPlatform.instance);
  tearDown(() => ImagePickerPlatform.instance = before);

  test('takePhoto opens the camera, asks for no resizing or re-encoding, '
      'and reads the type and upright size from the file', () async {
    final picker = _FakePicker(one: XFile('$_media/orientation_6.jpg'));
    final result = await ImagePickerPhotoSource(picker: picker).takePhoto();
    final photo = result.valueOrNull!;
    expect(picker.calls, ['pickImage camera']);
    expect(picker.sizing, [(null, null, null)], reason: 'D-017');
    expect(photo.path, '$_media/orientation_6.jpg');
    expect(photo.mimeType, 'image/jpeg');
    expect((photo.width, photo.height), (20, 40), reason: 'orientation 6');
    expect(photo.originalName, 'orientation_6.jpg');
  });

  test('a cancelled camera is Ok(null)', () async {
    final result = await ImagePickerPhotoSource(picker: _FakePicker())
        .takePhoto();
    expect(result, const Ok<CapturedPhoto?, Failure>(null));
  });

  test("the camera's denial and absence are failures, other errors are "
      'thrown', () async {
    Future<Result<CapturedPhoto?, Failure>> take(String code) =>
        ImagePickerPhotoSource(
          picker: _FakePicker(error: PlatformException(code: code)),
        ).takePhoto();
    expect(
      (await take('camera_access_denied')).failureOrNull,
      PhotoSource.cameraDenied,
    );
    expect(
      (await take('no_available_camera')).failureOrNull,
      PhotoSource.cameraUnavailable,
    );
    await expectLater(
      take('already_active'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('pickImages turns on the Android photo picker and returns every '
      'photo picked, in order, without re-encoding', () async {
    final android = ImagePickerAndroid();
    ImagePickerPlatform.instance = android;
    final picker = _FakePicker(
      many: [
        XFile('$_media/photo.png'),
        XFile('$_media/lossy.webp'),
        XFile('$_media/photo.jpg'),
      ],
    );
    final result = await ImagePickerPhotoSource(picker: picker).pickImages();
    expect(android.useAndroidPhotoPicker, isTrue);
    expect(picker.calls, ['pickMultiImage']);
    expect(picker.sizing, [(null, null, null)], reason: 'D-017');
    expect(
      [for (final p in result.valueOrNull!) (p.mimeType, p.width, p.height)],
      [('image/png', 12, 7), ('image/webp', 16, 8), ('image/jpeg', 40, 30)],
    );
  });

  test('a cancelled picker is an empty list', () async {
    final result = await ImagePickerPhotoSource(picker: _FakePicker())
        .pickImages();
    expect(result.valueOrNull, isEmpty);
  });

  test('a file of no known image format keeps the type the picker gave, '
      'with no size', () async {
    final picker = _FakePicker(
      one: XFile('$_media/README.md', mimeType: 'image/bmp'),
    );
    final photo = (await ImagePickerPhotoSource(
      picker: picker,
    ).takePhoto()).valueOrNull!;
    expect(photo.mimeType, 'image/bmp');
    expect(photo.width, isNull);
    final untyped = _FakePicker(one: XFile('$_media/README.md'));
    expect(
      (await ImagePickerPhotoSource(
        picker: untyped,
      ).takePhoto()).valueOrNull!.mimeType,
      'application/octet-stream',
    );
  });

  test(
    'recoverLost returns the photos a killed activity left behind',
    () async {
      final picker = _FakePicker(
        lost: LostDataResponse(
          files: [XFile('$_media/orientation_3.jpg')],
          type: RetrieveType.image,
        ),
      );
      final result = await ImagePickerPhotoSource(picker: picker).recoverLost();
      expect(picker.calls, ['retrieveLostData']);
      expect(result.valueOrNull!.single.path, '$_media/orientation_3.jpg');
      final none = await ImagePickerPhotoSource(picker: _FakePicker())
          .recoverLost();
      expect(none.valueOrNull, isEmpty);
    },
  );

  test('a PhotoSizing for the camera or the gallery is passed as it is '
      '(LYCEUM\'s scaled capture); none is RELAY\'s original bytes', () async {
    final picker = _FakePicker(
      one: XFile('$_media/photo.jpg'),
      many: [XFile('$_media/photo.png')],
    );
    final source = ImagePickerPhotoSource(
      picker: picker,
      camera: const PhotoSizing(maxSide: 2048, quality: 90),
      gallery: const PhotoSizing(quality: 90),
    );
    await source.takePhoto();
    await source.pickImages();
    expect(picker.sizing, [(2048.0, 2048.0, 90), (null, null, 90)]);
  });

  test('a lost camera error is the failure it would have been', () async {
    final picker = _FakePicker(
      lost: LostDataResponse(
        exception: PlatformException(code: 'camera_access_denied'),
        type: RetrieveType.image,
      ),
    );
    final result = await ImagePickerPhotoSource(picker: picker).recoverLost();
    expect(result.failureOrNull, PhotoSource.cameraDenied);
  });
}
