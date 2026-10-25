// From relay lib/core/ports/photo_source.dart @ 09b28810.
import 'package:apsira_core/apsira_core.dart';

/// Photos (RELAY 07 P2-06): the system camera and the Android photo picker,
/// several photos at once. Neither needs a storage permission, and a photo
/// is never resized or re-encoded unless the adapter is told to (RELAY
/// D-017): the caller moves the file into its media store as it is.
abstract interface class PhotoSource {
  /// Failure: the camera permission was denied.
  static const cameraDenied = Failure(
    'cameraPermissionDenied',
    nextStep: 'openAppSettings',
  );

  /// Failure: the phone has no camera, or no app answers the camera intent.
  static const cameraUnavailable = Failure('cameraUnavailable');

  /// Takes a photo with the system camera. `Ok(null)` when the user
  /// cancels.
  Future<Result<CapturedPhoto?, Failure>> takePhoto();

  /// Picks existing photos through the system photo picker, several at
  /// once, in the order picked. An empty list when the user cancels.
  Future<Result<List<CapturedPhoto>, Failure>> pickImages();

  /// The photos of a capture whose activity Android ended while the camera
  /// or the picker was open (low memory), so they are not lost; empty when
  /// there are none. Called once when the app starts.
  Future<Result<List<CapturedPhoto>, Failure>> recoverLost();
}

/// A photo in a temporary file, for the caller to move into the media
/// store as it is.
final class CapturedPhoto {
  const CapturedPhoto({
    required this.path,
    required this.mimeType,
    this.originalName,
    this.width,
    this.height,
  });

  final String path;

  /// From the file's first bytes; the picker's type when those are no
  /// known image.
  final String mimeType;

  /// The file's name as the camera or the picker gave it.
  final String? originalName;

  /// The upright size (EXIF orientation applied), for the attachment row;
  /// null when the header does not say.
  final int? width;
  final int? height;
}
