// From relay lib/data/platform/image_picker_photo_source.dart @ 09b28810,
// with the optional PhotoSizing of lyceum
// lib/data/platform/image_picker_photo_source.dart @ 9f4ff27 (D-APK-015).
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;

import 'image_meta.dart';
import 'photo_source.dart';

/// The [PhotoSource] on `image_picker` (RELAY 07 P2-06):
/// `ACTION_IMAGE_CAPTURE` for the camera and the system photo picker
/// (`PickMultipleVisualMedia`) for existing photos. An app that declares no
/// `CAMERA` permission is never asked for one by the plugin, and no storage
/// permission is needed.
///
/// With no [PhotoSizing] (the default), no `maxWidth`, `maxHeight` or
/// `imageQuality` is passed: the plugin then hands back the original bytes,
/// copied into the cache, never re-encoded (RELAY D-017). A sizing for the
/// [camera] or the [gallery] is passed as it is (LYCEUM's scaled capture).
/// The file's type and upright size come from its first bytes
/// ([ImageMeta]). Paths and names are never logged (RELAY D-050).
final class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource({ImagePicker? picker, this.camera, this.gallery})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// How [takePhoto] scales and re-encodes; null keeps the original.
  final PhotoSizing? camera;

  /// How [pickImages] scales and re-encodes; null keeps the originals.
  final PhotoSizing? gallery;

  @override
  Future<Result<CapturedPhoto?, Failure>> takePhoto() => _guard(() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: camera?.maxSide,
      maxHeight: camera?.maxSide,
      imageQuality: camera?.quality,
    );
    return file == null ? null : await _captured(file);
  });

  @override
  Future<Result<List<CapturedPhoto>, Failure>> pickImages() {
    // The system photo picker instead of ACTION_GET_CONTENT.
    if (ImagePickerPlatform.instance case final ImagePickerAndroid android) {
      android.useAndroidPhotoPicker = true;
    }
    return _guard(() async {
      final files = await _picker.pickMultiImage(
        maxWidth: gallery?.maxSide,
        maxHeight: gallery?.maxSide,
        imageQuality: gallery?.quality,
      );
      return [for (final file in files) await _captured(file)];
    });
  }

  @override
  Future<Result<List<CapturedPhoto>, Failure>> recoverLost() => _guard(
    () async {
      final lost = await _picker.retrieveLostData();
      if (lost.exception case final error?) throw error;
      return [
        for (final file in lost.files ?? const <XFile>[]) await _captured(file),
      ];
    },
  );

  static Future<CapturedPhoto> _captured(XFile file) async {
    final header = BytesBuilder(copy: false);
    await file.openRead(0, ImageMeta.headerLength).forEach(header.add);
    final meta = ImageMeta.read(header.takeBytes());
    return CapturedPhoto(
      path: file.path,
      mimeType: meta?.mimeType ?? file.mimeType ?? 'application/octet-stream',
      originalName: file.name,
      width: meta?.displayWidth,
      height: meta?.displayHeight,
    );
  }

  /// [action]'s value, or the camera's expected failures as codes; any
  /// other platform error is a bug and is thrown.
  static Future<Result<T, Failure>> _guard<T>(
    Future<T> Function() action,
  ) async {
    try {
      return Ok(await action());
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'camera_access_denied':
          return const Err(PhotoSource.cameraDenied);
        case 'no_available_camera':
          return const Err(PhotoSource.cameraUnavailable);
      }
      rethrow;
    }
  }
}

/// How the plugin scales and re-encodes a photo: at most [maxSide] pixels a
/// side, at JPEG [quality] (0 to 100); a null field leaves that alone.
final class PhotoSizing {
  const PhotoSizing({this.maxSide, this.quality});

  final double? maxSide;
  final int? quality;
}
